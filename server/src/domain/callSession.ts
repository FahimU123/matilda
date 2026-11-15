import type { ConfirmMethod } from "./pendingAsks.js";

export type CallPhase = "ringing" | "live" | "waitingForUser" | "ended";

export type Speaker = "agent" | "other";

export interface TranscriptLine {
  speaker: Speaker;
  text: string;
  at: number;
}

export interface ConsentEntry {
  question: string;
  answer: string;
  method: ConfirmMethod;
  at: number;
}

export type CallEvent =
  | { type: "answered" }
  | { type: "askOpened" }
  | { type: "askClosed" }
  | { type: "hungUp" };

export class InvalidTransition extends Error {
  constructor(phase: CallPhase, event: CallEvent["type"]) {
    super(`Cannot apply ${event} while ${phase}`);
  }
}

export class CallSession {
  phase: CallPhase = "ringing";
  readonly transcript: TranscriptLine[] = [];
  readonly consents: ConsentEntry[] = [];
  private openAsks = 0;

  constructor(
    readonly id: string,
    readonly profileId: string,
    readonly placeId: string,
    readonly startedAt: number,
  ) {}

  apply(event: CallEvent): CallPhase {
    this.phase = next(this.phase, event, this.openAsks);
    if (event.type === "askOpened") this.openAsks += 1;
    if (event.type === "askClosed") this.openAsks = Math.max(0, this.openAsks - 1);
    if (event.type === "hungUp") this.openAsks = 0;
    return this.phase;
  }

  record(line: TranscriptLine): void {
    this.transcript.push(line);
  }

  consent(entry: ConsentEntry): void {
    this.consents.push(entry);
  }
}

function next(phase: CallPhase, event: CallEvent, openAsks: number): CallPhase {
  if (event.type === "hungUp") return "ended";
  switch (phase) {
    case "ringing":
      if (event.type === "answered") return "live";
      break;
    case "live":
      if (event.type === "askOpened") return "waitingForUser";
      if (event.type === "answered") return "live";
      break;
    case "waitingForUser":
      if (event.type === "askOpened") return "waitingForUser";
      if (event.type === "askClosed") return openAsks > 1 ? "waitingForUser" : "live";
      break;
    case "ended":
      break;
  }
  throw new InvalidTransition(phase, event.type);
}
