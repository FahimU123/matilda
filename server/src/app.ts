import cors from "@fastify/cors";
import websocket from "@fastify/websocket";
import type { GoogleGenAI } from "@google/genai";
import Fastify, { type FastifyReply, type FastifyRequest } from "fastify";
import { z } from "zod";
import { Profile } from "./domain/profile.js";
import { AppMessage, LineMessage } from "./realtime/messages.js";
import type { Hub } from "./realtime/hub.js";
import { CallNotFound, LineUnavailable, type CallCoordinator } from "./services/calls.js";
import { ElevenLabsUnavailable, type ElevenLabs } from "./services/elevenlabs.js";
import { interpretLipReading } from "./services/gemini.js";
import type { Store } from "./services/store.js";

export interface AppDeps {
  store: Store;
  hub: Hub;
  calls: CallCoordinator;
  elevenlabs: ElevenLabs;
  toolSecret: string;
  appKey: string;
  webOrigin: string;
  requireFamily: (authorization: string | undefined) => Promise<boolean>;
  lipreadUrl: string;
  gemini: { ai: GoogleGenAI | undefined; models: string[] };
}

const StartCall = z.object({ profileId: z.string(), placeId: z.string() });
const AskBody = z.object({ call_id: z.string(), question: z.string().min(1) });
const ReadBody = z.object({ fps: z.number().positive(), frames: z.array(z.string()).min(4).max(400) });
const LipReading = z.object({ text: z.string() });

export async function buildApp(deps: AppDeps) {
  const app = Fastify({ logger: { level: "info" }, bodyLimit: 8 * 1024 * 1024 });
  await app.register(cors, { origin: deps.webOrigin.split(",") });
  await app.register(websocket);

  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof CallNotFound) return reply.code(404).send({ error: error.message });
    if (error instanceof LineUnavailable) return reply.code(409).send({ error: error.message });
    if (error instanceof ElevenLabsUnavailable) return reply.code(503).send({ error: error.message });
    if (error instanceof z.ZodError) return reply.code(400).send({ error: "Invalid request", issues: error.issues });
    app.log.error(error);
    return reply.code(500).send({ error: "Internal error" });
  });

  app.get("/health", async () => ({ ok: true, voice: deps.elevenlabs.configured }));

  app.get<{ Params: { id: string } }>("/api/profiles/:id", async (request, reply) => {
    const profile = await deps.store.profile(request.params.id);
    return profile ?? reply.code(404).send({ error: "Not found" });
  });

  app.put<{ Params: { id: string } }>("/api/profiles/:id", async (request, reply) => {
    if (!(await deps.requireFamily(request.headers.authorization))) return reply.code(401).send({ error: "Sign in" });
    const profile = Profile.parse({ ...(request.body as object), id: request.params.id });
    await deps.store.saveProfile(profile);
    return profile;
  });

  app.get<{ Params: { id: string } }>("/api/profiles/:id/calls", async (request, reply) => {
    if (!(await deps.requireFamily(request.headers.authorization))) return reply.code(401).send({ error: "Sign in" });
    return deps.store.calls(request.params.id, 20);
  });

  const requireAppKey = async (request: FastifyRequest<{ Querystring: { key?: string } }>, reply: FastifyReply) => {
    if (request.query.key !== deps.appKey) return reply.code(401).send({ error: "Bad key" });
  };

  const lipread = (body: unknown, timeoutMs: number) =>
    fetch(`${deps.lipreadUrl}/read`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    }).catch(() => undefined);

  app.post("/api/lipread", { bodyLimit: 4 * 1024 * 1024 }, async (request, reply) => {
    if (request.headers["x-app-key"] !== deps.appKey) return reply.code(401).send({ error: "Bad key" });
    const response = await lipread(request.body, 8_000);
    if (!response) return reply.code(503).send({ error: "The lip reader is not running" });
    const body = await response.json().catch(() => ({ error: "The lip reader sent an unreadable reply" }));
    return reply.code(response.status).send(body);
  });

  app.post<{ Params: { cardId: string } }>(
    "/api/cards/:cardId/read",
    { bodyLimit: 8 * 1024 * 1024 },
    async (request, reply) => {
      if (request.headers["x-app-key"] !== deps.appKey) return reply.code(401).send({ error: "Bad key" });
      const open = deps.calls.openCard(request.params.cardId);
      if (!open) return reply.code(404).send({ error: "That question is no longer open" });

      const response = await lipread(ReadBody.parse(request.body), 15_000);
      if (!response) return reply.code(503).send({ error: "The lip reader is not running" });
      const body: unknown = await response.json().catch(() => undefined);
      const reading = LipReading.safeParse(body);
      if (!response.ok || !reading.success) {
        const error = noFace(response.status, body)
          ? "Couldn't see your mouth. Hold the phone in front of your face and try again."
          : "Couldn't read that. Try again.";
        return reply.code(response.status >= 400 && response.status < 500 ? response.status : 502).send({ error });
      }

      const heard = reading.data.text.trim().toLowerCase();
      if (!heard) return reply.code(422).send({ error: "Couldn't read that. Try again, a little slower." });
      const sentence = await interpretLipReading(deps.gemini.ai, deps.gemini.models, {
        question: open.card.question,
        purpose: open.purpose,
        profile: open.profile,
        heard,
      });
      return { heard, sentence };
    },
  );

  app.post("/api/calls", async (request) => {
    const { profileId, placeId } = StartCall.parse(request.body);
    return deps.calls.start(profileId, placeId);
  });

  app.get<{ Params: { id: string } }>("/api/calls/:id/session", async (request) => ({
    conversationToken: await deps.elevenlabs.conversationToken(),
    dynamicVariables: deps.calls.sessionContext(request.params.id),
  }));

  app.post<{ Querystring: { key?: string } }>("/tools/ask-user", async (request, reply) => {
    if (request.query.key !== deps.toolSecret) return reply.code(401).send({ error: "Bad key" });
    const { call_id, question } = AskBody.parse(request.body);
    return { say: await deps.calls.ask(call_id, question) };
  });

  app.get<{ Params: { profileId: string }; Querystring: { key?: string } }>(
    "/ws/app/:profileId",
    { websocket: true, preValidation: requireAppKey },
    (socket, request) => {
      const { profileId } = request.params;
      deps.hub.join(`app:${profileId}`, socket);
      socket.on("message", (raw) => {
        const parsed = AppMessage.safeParse(safeJson(raw.toString()));
        if (parsed.success) deps.calls.respond(profileId, parsed.data);
      });
    },
  );

  app.get<{ Querystring: { key?: string } }>("/ws/line", { websocket: true, preValidation: requireAppKey }, (socket) => {
    deps.hub.join("line", socket);
    socket.on("message", (raw) => {
      const parsed = LineMessage.safeParse(safeJson(raw.toString()));
      if (!parsed.success) return;
      const message = parsed.data;
      try {
        if (message.type === "connected") deps.calls.connected(message.callId);
        if (message.type === "transcript") deps.calls.heard(message.callId, message.speaker, message.text);
        if (message.type === "ended") void deps.calls.finish(message.callId);
      } catch (error) {
        if (!(error instanceof CallNotFound)) throw error;
      }
    });
  });

  return app;
}

// The lip reader reports a missing face as a 422 with a message; validation errors carry a list instead.
function noFace(status: number, body: unknown): boolean {
  return status === 422 && typeof (body as { detail?: unknown } | undefined)?.detail === "string";
}

function safeJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}
