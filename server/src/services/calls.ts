import { randomUUID } from "node:crypto";
import type { GoogleGenAI } from "@google/genai";
import { buildCard, declineSay, sayForSensitive, type AnswerCard } from "../domain/answerCard.js";
import { CallSession, type Speaker } from "../domain/callSession.js";
import type { AskOutcome, PendingAsks } from "../domain/pendingAsks.js";
import { findField, findPlace, maskValue, type Place, type Profile } from "../domain/profile.js";
import type { QuestionAnalyzer } from "../domain/questionAnalyzer.js";
import type { Hub } from "../realtime/hub.js";
import type { AppMessage } from "../realtime/messages.js";
import { summarizeCall } from "./gemini.js";
import type { Store } from "./store.js";

export class CallNotFound extends Error {}
export class LineUnavailable extends Error {}

const longNumber = /\d(?:[\s.-]?\d){4,}/g;
const composingTimeoutMs = 90_000;

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
  ) {
    asks.onSettle((callId, card, outcome) => this.closed(callId, card, outcome));
  }

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
    switch (result.kind) {
      case "held":
        return `${call.profile.displayName} is mouthing a longer answer. Tell them politely it will take about twenty seconds, then call ask_user again with exactly the same question.`;
      case "answered":
        return result.say;
      case "declined":
        return `${declineSay(call.profile)} Ask the question again so ${call.profile.displayName} can choose the right answer.`;
      case "timedOut":
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

    const found = this.cardContext(message.cardId);
    if (!found || found.call.profile.id !== profileId) return;
    const { card, call } = found;

    switch (message.type) {
      case "composing":
        this.asks.hold(card.id, composingTimeoutMs);
        return;
      case "decline":
        call.session.consent({ question: card.question, answer: "Declined", method: message.method, at: this.now() });
        this.asks.settle(card.id, { kind: "declined", method: message.method });
        return;
      case "say": {
        const text = message.text.trim();
        if (card.sensitiveFieldKey !== undefined || text.length === 0 || text.length > 300) return;
        call.session.consent({ question: card.question, answer: text, method: message.method, at: this.now() });
        this.asks.settle(card.id, { kind: "answered", say: text, suggestionId: "custom", method: message.method });
        return;
      }
      case "answer":
        this.answer(call, card, message);
    }
  }

  openCard(cardId: string): { card: AnswerCard; profile: Profile; purpose: string } | undefined {
    const found = this.cardContext(cardId);
    return found && { card: found.card, profile: found.call.profile, purpose: found.call.place.purpose };
  }

  async finish(callId: string): Promise<void> {
    const call = this.active.get(callId);
    if (!call) return;
    if (call.session.phase !== "ended") call.session.apply({ type: "hungUp" });
    this.asks.cancelCall(callId);
    this.active.delete(callId);
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

  private answer(call: ActiveCall, card: AnswerCard, message: Extract<AppMessage, { type: "answer" }>): void {
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

  // Runs once per card, whichever tool call (if any) is still waiting on it.
  private closed(callId: string, card: AnswerCard, outcome: AskOutcome): void {
    const call = this.active.get(callId);
    if (!call) return;
    if (call.session.phase !== "ended") {
      call.session.apply({ type: "askClosed" });
      this.publishPhase(callId);
    }
    const said =
      outcome.kind === "answered" ? outcome.say : outcome.kind === "declined" ? declineSay(call.profile) : null;
    this.hub.send(`app:${call.profile.id}`, { type: "card.closed", callId, cardId: card.id, said });
    if (outcome.kind === "answered") {
      this.hub.send("line", { type: "approved", callId, method: outcome.method, name: call.profile.displayName });
    }
  }

  private cardContext(cardId: string): { card: AnswerCard; call: ActiveCall } | undefined {
    const card = this.asks.card(cardId);
    const callId = this.asks.callFor(cardId);
    const call = callId ? this.active.get(callId) : undefined;
    return card && call ? { card, call } : undefined;
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
