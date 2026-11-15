import cors from "@fastify/cors";
import websocket from "@fastify/websocket";
import Fastify, { type FastifyReply, type FastifyRequest } from "fastify";
import { z } from "zod";
import { Profile } from "./domain/profile.js";
import { AppMessage, LineMessage } from "./realtime/messages.js";
import type { Hub } from "./realtime/hub.js";
import { CallNotFound, LineUnavailable, type CallCoordinator } from "./services/calls.js";
import { ElevenLabsUnavailable, type ElevenLabs } from "./services/elevenlabs.js";
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
}

const StartCall = z.object({ profileId: z.string(), placeId: z.string() });
const AskBody = z.object({ call_id: z.string(), question: z.string().min(1) });

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

  app.post("/api/lipread", { bodyLimit: 4 * 1024 * 1024 }, async (request, reply) => {
    if (request.headers["x-app-key"] !== deps.appKey) return reply.code(401).send({ error: "Bad key" });
    const response = await fetch(`${deps.lipreadUrl}/read`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(request.body),
      signal: AbortSignal.timeout(8_000),
    }).catch(() => undefined);
    if (!response) return reply.code(503).send({ error: "The lip reader is not running" });
    const body = await response.json().catch(() => ({ error: "The lip reader sent an unreadable reply" }));
    return reply.code(response.status).send(body);
  });

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

function safeJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}
