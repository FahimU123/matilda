import type { AnswerCard } from "./answerCard.js";

export type AskOutcome =
  | { kind: "answered"; say: string; suggestionId: string; method: ConfirmMethod }
  | { kind: "declined"; method: ConfirmMethod }
  | { kind: "timedOut" };

export type ConfirmMethod = "thumbs" | "nod" | "lips" | "tap" | "saved";

interface Pending {
  callId: string;
  card: AnswerCard;
  key: string;
  waiters: Array<(outcome: AskOutcome) => void>;
  timer: NodeJS.Timeout;
}

export class PendingAsks {
  private readonly byId = new Map<string, Pending>();

  constructor(private readonly timeoutMs: number) {}

  open(callId: string, card: AnswerCard): { card: AnswerCard; outcome: Promise<AskOutcome>; isNew: boolean } {
    const key = `${callId}:${normalize(card.question)}`;
    const existing = [...this.byId.values()].find((pending) => pending.key === key);
    if (existing) {
      return { card: existing.card, outcome: this.wait(existing), isNew: false };
    }

    const pending: Pending = {
      callId,
      card,
      key,
      waiters: [],
      timer: setTimeout(() => this.settle(card.id, { kind: "timedOut" }), this.timeoutMs),
    };
    this.byId.set(card.id, pending);
    return { card, outcome: this.wait(pending), isNew: true };
  }

  settle(cardId: string, outcome: AskOutcome): boolean {
    const pending = this.byId.get(cardId);
    if (!pending) return false;
    clearTimeout(pending.timer);
    this.byId.delete(cardId);
    for (const resolve of pending.waiters) resolve(outcome);
    return true;
  }

  card(cardId: string): AnswerCard | undefined {
    return this.byId.get(cardId)?.card;
  }

  openFor(callId: string): AnswerCard[] {
    return [...this.byId.values()].filter((pending) => pending.callId === callId).map((pending) => pending.card);
  }

  cancelCall(callId: string): void {
    for (const pending of [...this.byId.values()]) {
      if (pending.callId === callId) this.settle(pending.card.id, { kind: "timedOut" });
    }
  }

  private wait(pending: Pending): Promise<AskOutcome> {
    return new Promise((resolve) => pending.waiters.push(resolve));
  }
}

function normalize(question: string): string {
  return question.toLowerCase().replace(/[^a-z0-9 ]/g, "").replace(/\s+/g, " ").trim();
}
