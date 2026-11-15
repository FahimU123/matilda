import { randomUUID } from "node:crypto";
import type { GoogleGenAI } from "@google/genai";
import { buildCard, declineSay, sayForSensitive } from "../domain/answerCard.js";
import { CallSession, type Speaker } from "../domain/callSession.js";
import type { PendingAsks } from "../domain/pendingAsks.js";
import { findField, findPlace, maskValue, type Place, type Profile } from "../domain/profile.js";
import type { QuestionAnalyzer } from "../domain/questionAnalyzer.js";
import type { Hub } from "../realtime/hub.js";
import type { AppMessage } from "../realtime/messages.js";
import { summarizeCall } from "./gemini.js";
import type { Store } from "./store.js";

export class CallNotFound extends Error {}
export class LineUnavailable extends Error {}

const longNumber = /\d(?:[\s.-]?\d){4,}/g;

interface ActiveCall {
  session: CallSession;
  profile: Profile;
  place: Place;
}

export class CallCoordinator {
  private readonly active = new Map<string, ActiveCall>();

  constructor(
    private readonly store: Store,
    private readonly hub: Hub,
    private readonly asks: PendingAsks,
    private readonly analyzer: QuestionAnalyzer,
    private readonly summarizer: { ai: GoogleGenAI | undefined; models: string[] },
    private readonly now: () => number = Date.now,
  ) {}

  async start(profileId: string, placeId: string): Promise<{ callId: string; ringing: boolean }> {
    const profile = await this.store.profile(profileId);
    const place = profile && findPlace(profile, placeId);
    if (!profile || !place) throw new CallNotFound(`Unknown profile or place: ${profileId}/${placeId}`);
    if (!this.hub.has("line")) throw new LineUnavailable("Nobody is on the line. Open the line page and try again.");

    const session = new CallSession(randomUUID(), profile.id, place.id, this.now());
    this.active.set(session.id, { session, profile, place });

    const ringing = this.hub.send("line", {
      type: "ring",
      callId: session.id,
      placeName: place.name,
      callerName: profile.displayName,
    }) > 0;
    this.publishPhase(session.id);
    return { callId: session.id, ringing };
  }

  sessionContext(callId: string) {
    const { profile, place } = this.require(callId);
    return {
      call_id: callId,
      user_name: profile.displayName,
      pronoun: profile.pronoun,
      condition: profile.condition,
      place_name: place.name,
      task: place.purpose,
    };
  }

  connected(callId: string): void {
    const call = this.require(callId);
    if (call.session.phase === "ringing") call.session.apply({ type: "answered" });
    this.publishPhase(callId);
  }

  heard(callId: string, speaker: Speaker, text: string): void {
    const call = this.require(callId);
    const redacted = text.replace(longNumber, (digits) => maskValue(digits.replace(/\D/g, "")));
    const line = { speaker, text: redacted, at: this.now() };
    call.session.record(line);
    this.hub.send(`app:${call.profile.id}`, { type: "transcript", callId, line });
  }

  async ask(callId: string, question: string): Promise<string> {
    const call = this.require(callId);
    if (call.session.phase === "ringing") this.connected(callId);
    const analysis = await this.analyzer.analyze(question, call.profile, call.place.purpose);
    if (this.active.get(callId) !== call) return "The call has ended.";

    // Facts the family already saved are answered straight away; Ray only decides choices and private numbers.
    if (analysis.kind === "field") {
      const field = findField(call.profile, analysis.fieldKey);
      if (field && !field.sensitive) {
        const say = buildCard(question, analysis, call.profile).suggestions[0]!.say;
        call.session.consent({ question, answer: field.value, method: "saved", at: this.now() });
        return say;
      }
    }
    const { card, outcome, isNew } = this.asks.open(callId, buildCard(question, analysis, call.profile));

    if (isNew) {
      call.session.apply({ type: "askOpened" });
      this.publishPhase(callId);
      this.hub.send(`app:${call.profile.id}`, { type: "card.open", callId, card });
    }

    const result = await outcome;
    if (isNew && call.session.phase !== "ended") {
      call.session.apply({ type: "askClosed" });
      this.publishPhase(callId);
    }

    switch (result.kind) {
      case "answered": {
        if (isNew) {
          this.hub.send(`app:${call.profile.id}`, { type: "card.closed", callId, cardId: card.id, said: result.say });
          this.hub.send("line", { type: "approved", callId, method: result.method, name: call.profile.displayName });
        }
        return result.say;
      }
      case "declined": {
        const say = declineSay(call.profile);
        if (isNew) this.hub.send(`app:${call.profile.id}`, { type: "card.closed", callId, cardId: card.id, said: say });
        return `${say} Ask the question again so ${call.profile.displayName} can choose the right answer.`;
      }
      case "timedOut":
        if (isNew) this.hub.send(`app:${call.profile.id}`, { type: "card.closed", callId, cardId: card.id, said: null });
        return `${call.profile.displayName} needs a little more time. Politely ask the other person to hold for a moment, then ask again.`;
    }
  }

  respond(profileId: string, message: AppMessage): void {
    if (message.type === "hangup") {
      if (this.active.get(message.callId)?.profile.id !== profileId) return;
      this.hub.send("line", { type: "hangup", callId: message.callId });
      void this.finish(message.callId);
      return;
    }

    const card = this.asks.card(message.cardId);
    const callId = card && this.findCallForCard(message.cardId);
    const call = callId ? this.active.get(callId) : undefined;
    if (!card || !call || call.profile.id !== profileId) return;

    if (message.type === "decline") {
      call.session.consent({ question: card.question, answer: "Declined", method: message.method, at: this.now() });
      this.asks.settle(card.id, { kind: "declined", method: message.method });
      return;
    }

    const suggestion = card.suggestions.find((option) => option.id === message.suggestionId);
    if (!suggestion) return;
    const sensitive = card.sensitiveFieldKey !== undefined;
    if (sensitive && !message.value) return;

    const say = sensitive ? sayForSensitive(suggestion.say, message.value!) : suggestion.say;
    call.session.consent({
      question: card.question,
      answer: sensitive ? maskValue(message.value!) : suggestion.label,
      method: message.method,
      at: this.now(),
    });
    this.asks.settle(card.id, { kind: "answered", say, suggestionId: suggestion.id, method: message.method });
  }

  async finish(callId: string): Promise<void> {
    const call = this.active.get(callId);
    if (!call) return;
    this.active.delete(callId);
    this.asks.cancelCall(callId);
    if (call.session.phase !== "ended") call.session.apply({ type: "hungUp" });
    this.publishPhase(callId, call);

    const summary = await summarizeCall(this.summarizer.ai, this.summarizer.models, call.session.transcript);
    try {
      await this.store.saveCall({
        id: callId,
        profileId: call.profile.id,
        placeId: call.place.id,
        startedAt: call.session.startedAt,
        endedAt: this.now(),
        summary,
        transcript: call.session.transcript,
        consents: call.session.consents,
      });
    } catch (error) {
      console.error("saveCall failed", error);
    }
    this.hub.send(`app:${call.profile.id}`, {
      type: "call.summary",
      callId,
      summary,
      consents: call.session.consents,
    });
  }

  private findCallForCard(cardId: string): string | undefined {
    for (const [callId] of this.active) {
      if (this.asks.openFor(callId).some((card) => card.id === cardId)) return callId;
    }
    return undefined;
  }

  private publishPhase(callId: string, call = this.active.get(callId)): void {
    if (!call) return;
    this.hub.send(`app:${call.profile.id}`, {
      type: "call.state",
      callId,
      phase: call.session.phase,
      placeName: call.place.name,
    });
  }

  private require(callId: string): ActiveCall {
    const call = this.active.get(callId);
    if (!call) throw new CallNotFound(`Unknown call: ${callId}`);
    return call;
  }
}
