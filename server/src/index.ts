import { GoogleGenAI } from "@google/genai";
import { buildApp } from "./app.js";
import { config } from "./config.js";
import { demoProfile } from "./demoProfile.js";
import { PendingAsks } from "./domain/pendingAsks.js";
import { KeywordQuestionAnalyzer } from "./domain/questionAnalyzer.js";
import { Hub } from "./realtime/hub.js";
import { CallCoordinator } from "./services/calls.js";
import { ElevenLabs } from "./services/elevenlabs.js";
import { familyAuth } from "./services/familyAuth.js";
import { GeminiQuestionAnalyzer } from "./services/gemini.js";
import { MemoryStore, MongoStore, type Store } from "./services/store.js";

const store: Store = config.MONGODB_URI
  ? await MongoStore.connect(config.MONGODB_URI, config.MONGODB_DB, [demoProfile])
  : new MemoryStore([demoProfile]);

const ai = config.GEMINI_API_KEY ? new GoogleGenAI({ apiKey: config.GEMINI_API_KEY }) : undefined;
const keywords = new KeywordQuestionAnalyzer();
const analyzer = config.GEMINI_API_KEY
  ? new GeminiQuestionAnalyzer(config.GEMINI_API_KEY, config.GEMINI_MODELS, keywords)
  : keywords;

const hub = new Hub();
const calls = new CallCoordinator(store, hub, new PendingAsks(config.ASK_TIMEOUT_MS), analyzer, {
  ai,
  models: config.GEMINI_MODELS,
});

const app = await buildApp({
  store,
  hub,
  calls,
  elevenlabs: new ElevenLabs(config.ELEVENLABS_API_KEY, config.ELEVENLABS_AGENT_ID),
  toolSecret: config.TOOL_SECRET,
  appKey: config.APP_KEY,
  webOrigin: config.WEB_ORIGIN,
  requireFamily: familyAuth(config.SSOJET_ISSUER, config.SSOJET_CLIENT_ID),
  lipreadUrl: config.LIPREAD_URL,
  gemini: { ai, models: config.GEMINI_MODELS },
});

await app.listen({ port: config.PORT, host: "0.0.0.0" });
app.log.info(
  `store=${config.MONGODB_URI ? "mongo" : "memory"} analyzer=${ai ? `gemini (${config.GEMINI_MODELS.join(" > ")}) > keywords` : "keywords only"}`,
);
