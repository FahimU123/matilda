import { z } from "zod";

const Env = z.object({
  PORT: z.coerce.number().default(8787),
  PUBLIC_URL: z.string().url().default("http://localhost:8787"),
  WEB_ORIGIN: z.string().default("http://localhost:3000"),
  TOOL_SECRET: z.string().min(16).default("dev-secret-change-me"),
  APP_KEY: z.string().default("dev-app-key-change-me"),
  ASK_TIMEOUT_MS: z.coerce.number().default(25_000),
  MONGODB_URI: z.string().optional(),
  MONGODB_DB: z.string().default("matilda"),
  GEMINI_API_KEY: z.string().optional(),
  GEMINI_MODELS: z
    .string()
    .default("gemini-3.5-flash-lite,gemini-2.5-flash-lite,gemini-2.5-flash")
    .transform((value) => value.split(",").map((model) => model.trim()).filter(Boolean)),
  ELEVENLABS_API_KEY: z.string().optional(),
  ELEVENLABS_AGENT_ID: z.string().optional(),
  ELEVENLABS_VOICE_ID: z.string().default("XrExE9yKIg1WjnnlVkGX"),
  ELEVENLABS_LLM: z.string().default("gemini-3.5-flash"),
  DISCLOSE_AI: z.stringbool().default(false),
  SSOJET_ISSUER: z.string().optional(),
  SSOJET_CLIENT_ID: z.string().optional(),
  LIPREAD_URL: z.string().url().default("http://localhost:8790"),
});

export type Config = z.infer<typeof Env>;

export const config: Config = Env.parse(process.env);
