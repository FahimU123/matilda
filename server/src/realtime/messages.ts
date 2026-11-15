import { z } from "zod";

const ConfirmMethod = z.enum(["thumbs", "nod", "lips", "tap", "voice"]);

export const AppMessage = z.discriminatedUnion("type", [
  z.object({
    type: z.literal("answer"),
    cardId: z.string(),
    suggestionId: z.string(),
    method: ConfirmMethod,
    value: z.string().optional(),
  }),
  z.object({ type: z.literal("decline"), cardId: z.string(), method: ConfirmMethod }),
  z.object({ type: z.literal("hangup"), callId: z.string() }),
]);
export type AppMessage = z.infer<typeof AppMessage>;

export const LineMessage = z.discriminatedUnion("type", [
  z.object({ type: z.literal("connected"), callId: z.string() }),
  z.object({
    type: z.literal("transcript"),
    callId: z.string(),
    speaker: z.enum(["agent", "other"]),
    text: z.string().min(1),
  }),
  z.object({ type: z.literal("ended"), callId: z.string() }),
]);
export type LineMessage = z.infer<typeof LineMessage>;
