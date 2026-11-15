import { afterEach, describe, expect, it, vi } from "vitest";
import type { WebSocket } from "ws";
import { buildApp } from "../src/app.js";
import { demoProfile } from "../src/demoProfile.js";
import { PendingAsks } from "../src/domain/pendingAsks.js";
import { KeywordQuestionAnalyzer } from "../src/domain/questionAnalyzer.js";
import { Hub } from "../src/realtime/hub.js";
import { CallCoordinator } from "../src/services/calls.js";
import { ElevenLabs } from "../src/services/elevenlabs.js";
import { MemoryStore } from "../src/services/store.js";

async function setup() {
  const hub = new Hub();
  const store = new MemoryStore([demoProfile]);
  const asks = new PendingAsks(5_000);
  const calls = new CallCoordinator(store, hub, asks, new KeywordQuestionAnalyzer(), { ai: undefined, models: [] });
  const app = await buildApp({
    store,
    hub,
    calls,
    elevenlabs: new ElevenLabs(undefined, undefined),
    toolSecret: "tool-secret-for-tests",
    appKey: "app-key",
    webOrigin: "http://localhost:3000",
    requireFamily: async () => false,
    lipreadUrl: "http://lipread.test",
    gemini: { ai: undefined, models: [] },
  });
  return { app, calls, asks, hub };
}

async function openCard() {
  const ctx = await setup();
  ctx.hub.join("line", { OPEN: 1, readyState: 1, send() {}, on() {} } as unknown as WebSocket);
  const { callId } = await ctx.calls.start("ray", "pharmacy");
  void ctx.calls.ask(callId, "Anything else we should know?");
  await new Promise((resolve) => setTimeout(resolve, 0));
  return { ...ctx, cardId: ctx.asks.openFor(callId)[0]!.id };
}

const frames = { fps: 25, frames: ["a", "b", "c", "d"] };

describe("POST /api/cards/:cardId/read", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("turns the lip reading into a sentence for the open card", async () => {
    const { app, cardId } = await openCard();
    const lipreader = vi.fn().mockResolvedValue(Response.json({ text: "I NEED IT BY FRIDAY", command: null }));
    vi.stubGlobal("fetch", lipreader);

    const response = await app.inject({
      method: "POST",
      url: `/api/cards/${cardId}/read`,
      headers: { "x-app-key": "app-key" },
      payload: frames,
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ heard: "i need it by friday", sentence: "I need it by friday." });
    expect(lipreader.mock.calls[0]?.[0]).toBe("http://lipread.test/read");
  });

  it("explains when the lip reader could not find a face", async () => {
    const { app, cardId } = await openCard();
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(Response.json({ detail: "No face was found in any frame" }, { status: 422 })));

    const response = await app.inject({
      method: "POST",
      url: `/api/cards/${cardId}/read`,
      headers: { "x-app-key": "app-key" },
      payload: frames,
    });
    expect(response.statusCode).toBe(422);
    expect(response.json().error).toMatch(/^Couldn't see your mouth/);
  });

  it("rejects unknown cards and bad keys", async () => {
    const { app } = await setup();
    const unknown = await app.inject({
      method: "POST",
      url: "/api/cards/missing/read",
      headers: { "x-app-key": "app-key" },
      payload: frames,
    });
    expect(unknown.statusCode).toBe(404);

    const badKey = await app.inject({ method: "POST", url: "/api/cards/missing/read", payload: frames });
    expect(badKey.statusCode).toBe(401);
  });
});
