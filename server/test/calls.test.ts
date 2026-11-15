import { beforeEach, describe, expect, it } from "vitest";
import type { WebSocket } from "ws";
import { PendingAsks } from "../src/domain/pendingAsks.js";
import { KeywordQuestionAnalyzer } from "../src/domain/questionAnalyzer.js";
import { demoProfile } from "../src/demoProfile.js";
import { Hub } from "../src/realtime/hub.js";
import { CallCoordinator, LineUnavailable } from "../src/services/calls.js";
import { MemoryStore } from "../src/services/store.js";

class FakeSocket {
  readonly OPEN = 1;
  readyState = 1;
  readonly sent: any[] = [];
  send(data: string) {
    this.sent.push(JSON.parse(data));
  }
  on() {}
}

function setup({ withLine = true } = {}) {
  const hub = new Hub();
  const app = new FakeSocket();
  const line = new FakeSocket();
  hub.join("app:ray", app as unknown as WebSocket);
  if (withLine) hub.join("line", line as unknown as WebSocket);
  const store = new MemoryStore([demoProfile]);
  const calls = new CallCoordinator(store, hub, new PendingAsks(5_000), new KeywordQuestionAnalyzer(), {
    ai: undefined,
    models: [],
  });
  return { calls, app, line, store };
}

const nextCard = async (app: FakeSocket) => {
  for (let i = 0; i < 20; i++) {
    const card = app.sent.find((m) => m.type === "card.open");
    if (card) return card.card;
    await new Promise((resolve) => setTimeout(resolve, 0));
  }
  throw new Error("no card");
};

describe("CallCoordinator", () => {
  let ctx: ReturnType<typeof setup>;
  beforeEach(() => {
    ctx = setup();
  });

  it("rings the line and answers a question with what the user confirmed", async () => {
    const { callId, ringing } = await ctx.calls.start("ray", "pharmacy");
    expect(ringing).toBe(true);
    expect(ctx.line.sent[0]).toMatchObject({ type: "ring", placeName: "Nest Street Pharmacy" });

    ctx.calls.connected(callId);
    const spoken = ctx.calls.ask(callId, "What is his date of birth?");
    const card = await nextCard(ctx.app);
    ctx.calls.respond("ray", { type: "answer", cardId: card.id, suggestionId: "0", method: "thumbs" });

    await expect(spoken).resolves.toBe("His date of birth is March 4, 1952.");
  });

  it("speaks a sensitive value only from the phone and logs it masked", async () => {
    const { callId } = await ctx.calls.start("ray", "pharmacy");
    const spoken = ctx.calls.ask(callId, "Can you verify the social security number?");
    const card = await nextCard(ctx.app);
    expect(card.sensitiveFieldKey).toBe("ssn");

    ctx.calls.respond("ray", { type: "answer", cardId: card.id, suggestionId: "0", method: "nod", value: "6789" });
    await expect(spoken).resolves.toBe("His social security number is 6 7 8 9.");

    await ctx.calls.finish(callId);
    const [record] = await ctx.store.calls("ray", 1);
    expect(record?.consents[0]?.answer).toBe("•••• 6789");
  });

  it("tells the agent when the user rejects the suggestion", async () => {
    const { callId } = await ctx.calls.start("ray", "pharmacy");
    const spoken = ctx.calls.ask(callId, "Is the prescription ending in 4471?");
    const card = await nextCard(ctx.app);
    ctx.calls.respond("ray", { type: "decline", cardId: card.id, method: "nod" });
    await expect(spoken).resolves.toMatch(/^Ray says that's not right/);
  });

  it("ignores answers from a different profile", async () => {
    const { callId } = await ctx.calls.start("ray", "pharmacy");
    void ctx.calls.ask(callId, "Date of birth?");
    const card = await nextCard(ctx.app);
    ctx.calls.respond("someone-else", { type: "answer", cardId: card.id, suggestionId: "0", method: "tap" });
    expect(ctx.app.sent.some((m) => m.type === "card.closed")).toBe(false);
    await ctx.calls.finish(callId);
  });

  it("masks long numbers in the transcript before storing or sending them", async () => {
    const { callId } = await ctx.calls.start("ray", "pharmacy");
    ctx.calls.heard(callId, "agent", "His number is 123-45-6789, and 1 2 3 4 5 6 7 8 9.");
    const said = "His number is •••• 6789, and •••• 6789.";
    expect(ctx.app.sent.find((m) => m.type === "transcript")?.line.text).toBe(said);

    await ctx.calls.finish(callId);
    const [record] = await ctx.store.calls("ray", 1);
    expect(record?.transcript[0]?.text).toBe(said);
  });

  it("refuses to start a call when nobody is on the line", async () => {
    const { calls } = setup({ withLine: false });
    await expect(calls.start("ray", "pharmacy")).rejects.toBeInstanceOf(LineUnavailable);
  });

  it("ignores hangups from a different profile", async () => {
    const { callId } = await ctx.calls.start("ray", "pharmacy");
    ctx.calls.respond("someone-else", { type: "hangup", callId });
    expect(ctx.line.sent.some((m) => m.type === "hangup")).toBe(false);
    expect(() => ctx.calls.sessionContext(callId)).not.toThrow();
  });

  it("still sends the summary when saving the call fails", async () => {
    const { callId } = await ctx.calls.start("ray", "pharmacy");
    ctx.store.saveCall = async () => {
      throw new Error("db down");
    };
    await ctx.calls.finish(callId);
    expect(ctx.app.sent.some((m) => m.type === "call.summary")).toBe(true);
  });
});
