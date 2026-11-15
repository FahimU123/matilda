import { describe, expect, it, vi } from "vitest";
import { buildCard, sayForSensitive } from "../src/domain/answerCard.js";
import { CallSession, InvalidTransition } from "../src/domain/callSession.js";
import { PendingAsks } from "../src/domain/pendingAsks.js";
import { KeywordQuestionAnalyzer } from "../src/domain/questionAnalyzer.js";
import { demoProfile } from "../src/demoProfile.js";

describe("buildCard", () => {
  it("prefills a known field as a full sentence", () => {
    const card = buildCard("What's his date of birth?", { kind: "field", fieldKey: "dateOfBirth" }, demoProfile);
    expect(card.suggestions).toEqual([
      { id: "0", label: "March 4, 1952", say: "His date of birth is March 4, 1952." },
    ]);
  });

  it("never puts a sensitive value on the card", () => {
    const card = buildCard("Last four of the SSN?", { kind: "field", fieldKey: "ssn" }, demoProfile);
    expect(card.sensitiveFieldKey).toBe("ssn");
    expect(JSON.stringify(card)).not.toContain("123-45");
    expect(sayForSensitive(card.suggestions[0]!.say, "6789")).toBe("His social security number is 6 7 8 9.");
  });

  it("turns a choice into short polite answers", () => {
    const card = buildCard("Pickup or delivery?", { kind: "choice", options: ["Pickup", "Delivery"] }, demoProfile);
    expect(card.suggestions.map((s) => s.say)).toEqual(["Pickup, please.", "Delivery, please."]);
  });
});

describe("KeywordQuestionAnalyzer", () => {
  const analyzer = new KeywordQuestionAnalyzer();

  it("maps a date of birth question to the profile field", async () => {
    await expect(analyzer.analyze("Can I get the patient's DOB?", demoProfile)).resolves.toEqual({
      kind: "field",
      fieldKey: "dateOfBirth",
    });
  });

  it("splits an either-or question into options", async () => {
    await expect(analyzer.analyze("Would that be pickup or delivery?", demoProfile)).resolves.toEqual({
      kind: "choice",
      options: ["Pickup", "Delivery"],
    });
  });
});

describe("PendingAsks", () => {
  it("resolves the waiting tool call when the user confirms", async () => {
    const asks = new PendingAsks(10_000);
    const card = buildCard("DOB?", { kind: "field", fieldKey: "dateOfBirth" }, demoProfile);
    const { outcome } = asks.open("call-1", card);
    asks.settle(card.id, { kind: "answered", say: "ok", suggestionId: "0", method: "thumbs" });
    await expect(outcome).resolves.toMatchObject({ kind: "answered", method: "thumbs" });
  });

  it("reuses the open card when the agent asks the same question twice", () => {
    const asks = new PendingAsks(10_000);
    const first = asks.open("call-1", buildCard("DOB?", { kind: "open", suggestions: [] }, demoProfile));
    const again = asks.open("call-1", buildCard("dob", { kind: "open", suggestions: [] }, demoProfile));
    expect(again.isNew).toBe(false);
    expect(again.card.id).toBe(first.card.id);
  });

  it("times out instead of hanging the call", async () => {
    vi.useFakeTimers();
    const asks = new PendingAsks(1_000);
    const { outcome } = asks.open("call-1", buildCard("DOB?", { kind: "open", suggestions: [] }, demoProfile));
    vi.advanceTimersByTime(1_000);
    await expect(outcome).resolves.toEqual({ kind: "timedOut" });
    vi.useRealTimers();
  });
});

describe("CallSession", () => {
  it("waits for the user while any question is open", () => {
    const call = new CallSession("c", "p", "pl", 0);
    call.apply({ type: "answered" });
    call.apply({ type: "askOpened" });
    call.apply({ type: "askOpened" });
    expect(call.apply({ type: "askClosed" })).toBe("waitingForUser");
    expect(call.apply({ type: "askClosed" })).toBe("live");
  });

  it("rejects questions before the other side picks up", () => {
    const call = new CallSession("c", "p", "pl", 0);
    expect(() => call.apply({ type: "askOpened" })).toThrow(InvalidTransition);
  });
});
