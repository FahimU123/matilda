import type { AnswerCard } from "./answerCard.js";

export type AskOutcome =
  | { kind: "answered"; say: string; suggestionId: string; method: ConfirmMethod }
  | { kind: "declined"; method: ConfirmMethod }
  | { kind: "timedOut" };

export type AskResult = AskOutcome | { kind: "held" };

export type ConfirmMethod = "thumbs" | "nod" | "lips" | "tap" | "saved";

type SettleListener = (callId: string, card: AnswerCard, outcome: AskOutcome) => void;

interface Pending {
  callId: string;
  card: AnswerCard;
  key: string;
  waiters: Array<(result: AskResult) => void>;
  timer: NodeJS.Timeout;
  held: boolean;
}

const unclaimedMs = 30_000;

export class PendingAsks {
  private readonly byId = new Map<string, Pending>();
  private readonly listeners: SettleListener[] = [];
  private readonly unclaimed = new Map<string, { card: AnswerCard; outcome: AskOutcome }>();

  constructor(private readonly timeoutMs: number) {}

  onSettle(listener: SettleListener): void {
    this.listeners.push(listener);
  }

  open(callId: string, card: AnswerCard): { card: AnswerCard; outcome: Promise<AskResult>; isNew: boolean } {
    const key = `${callId}:${normalize(card.question)}`;
    const answered = this.unclaimed.get(key);
    if (answered) {
      this.unclaimed.delete(key);
      return { card: answered.card, outcome: Promise.resolve(answered.outcome), isNew: false };
    }
    const existing = [...this.byId.values()].find((pending) => pending.key === key);
    if (existing) {
      return { card: existing.card, outcome: this.wait(existing), isNew: false };
    }

    const pending: Pending = { callId, card, key, waiters: [], timer: this.expire(card.id, this.timeoutMs), held: false };
    this.byId.set(card.id, pending);
    return { card, outcome: this.wait(pending), isNew: true };
  }

  // Releases the waiting tool calls but keeps the card open so a repeat of the question attaches to it.
  hold(cardId: string, timeoutMs: number): boolean {
    const pending = this.byId.get(cardId);
    if (!pending) return false;
    clearTimeout(pending.timer);
    pending.timer = this.expire(cardId, timeoutMs);
    pending.held = true;
    for (const resolve of pending.waiters.splice(0)) resolve({ kind: "held" });
    return true;
  }

  settle(cardId: string, outcome: AskOutcome): boolean {
    const pending = this.byId.get(cardId);
    if (!pending) return false;
    clearTimeout(pending.timer);
    this.byId.delete(cardId);
    for (const resolve of pending.waiters) resolve(outcome);
    // Answered before the agent repeated a held question: keep it for that repeat.
    if (pending.held && pending.waiters.length === 0 && outcome.kind !== "timedOut") {
      const entry = { card: pending.card, outcome };
      this.unclaimed.set(pending.key, entry);
      setTimeout(() => {
        if (this.unclaimed.get(pending.key) === entry) this.unclaimed.delete(pending.key);
      }, unclaimedMs).unref();
    }
    for (const listener of this.listeners) listener(pending.callId, pending.card, outcome);
    return true;
  }

  card(cardId: string): AnswerCard | undefined {
    return this.byId.get(cardId)?.card;
  }

  callFor(cardId: string): string | undefined {
    return this.byId.get(cardId)?.callId;
  }

  openFor(callId: string): AnswerCard[] {
    return [...this.byId.values()].filter((pending) => pending.callId === callId).map((pending) => pending.card);
  }

  cancelCall(callId: string): void {
    for (const key of this.unclaimed.keys()) {
      if (key.startsWith(`${callId}:`)) this.unclaimed.delete(key);
    }
    for (const pending of [...this.byId.values()]) {
      if (pending.callId === callId) this.settle(pending.card.id, { kind: "timedOut" });
    }
  }

  private expire(cardId: string, ms: number): NodeJS.Timeout {
    return setTimeout(() => this.settle(cardId, { kind: "timedOut" }), ms);
  }

  private wait(pending: Pending): Promise<AskResult> {
    return new Promise((resolve) => pending.waiters.push(resolve));
  }
}

function normalize(question: string): string {
  return question.toLowerCase().replace(/[^a-z0-9 ]/g, "").replace(/\s+/g, " ").trim();
}
