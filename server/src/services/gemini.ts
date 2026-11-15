import { GoogleGenAI } from "@google/genai";
import { z } from "zod";
import type { QuestionAnalysis } from "../domain/answerCard.js";
import type { TranscriptLine } from "../domain/callSession.js";
import type { Profile } from "../domain/profile.js";
import type { QuestionAnalyzer } from "../domain/questionAnalyzer.js";

const Analysis = z.object({
  kind: z.enum(["field", "choice", "open"]),
  fieldKey: z.string().nullable(),
  options: z.array(z.string()).max(3),
});

export class GeminiQuestionAnalyzer implements QuestionAnalyzer {
  private readonly ai: GoogleGenAI;

  constructor(
    apiKey: string,
    private readonly models: string[],
    private readonly fallback: QuestionAnalyzer,
    private readonly timeoutMs = 2_500,
  ) {
    this.ai = new GoogleGenAI({ apiKey });
  }

  async analyze(question: string, profile: Profile, purpose: string): Promise<QuestionAnalysis> {
    const fields = profile.fields.map((field) => `${field.key}: ${field.label}`).join("\n");
    const prompt = [
      `You help ${profile.displayName}, who cannot speak clearly, answer questions on a phone call.`,
      `Call purpose: ${purpose}.`,
      `Known profile fields (values hidden):\n${fields}`,
      `The other person asked: "${question}"`,
      `If a profile field answers it, return kind "field" with that fieldKey.`,
      `If it offers explicit alternatives, return kind "choice" with up to 3 short options.`,
      `Otherwise return kind "open" with up to 3 short replies to speak on ${profile.displayName}'s behalf, most likely first.`,
    ].join("\n\n");

    const deadline = Date.now() + this.timeoutMs;
    for (const model of this.models) {
      const remaining = deadline - Date.now();
      if (remaining <= 200) break;
      try {
        const response = await this.ai.models.generateContent({
          model,
          contents: prompt,
          config: {
            responseMimeType: "application/json",
            responseJsonSchema: z.toJSONSchema(Analysis),
            abortSignal: AbortSignal.timeout(remaining),
          },
        });
        const parsed = Analysis.parse(JSON.parse(response.text ?? "{}"));
        if (parsed.kind === "field" && parsed.fieldKey && profile.fields.some((f) => f.key === parsed.fieldKey)) {
          return { kind: "field", fieldKey: parsed.fieldKey };
        }
        if (parsed.kind === "choice" && parsed.options.length > 1) return { kind: "choice", options: parsed.options };
        if (parsed.options.length > 0) return { kind: "open", suggestions: parsed.options };
        break;
      } catch {
        // Try the next model; a slow or unavailable model must never stall the call.
      }
    }
    return this.fallback.analyze(question, profile, purpose);
  }
}

export async function summarizeCall(
  ai: GoogleGenAI | undefined,
  models: string[],
  transcript: TranscriptLine[],
): Promise<string> {
  if (!ai || transcript.length === 0) return "";
  const text = transcript.map((line) => `${line.speaker === "agent" ? "Assistant" : "Other person"}: ${line.text}`).join("\n");
  for (const model of models) {
    try {
      const response = await ai.models.generateContent({
        model,
        contents: `Summarize the outcome of this phone call in one short sentence a 72 year old can read at a glance. No preamble.\n\n${text}`,
        config: { abortSignal: AbortSignal.timeout(6_000) },
      });
      const summary = response.text?.trim();
      if (summary) return summary;
    } catch {
      // Fall through to the next model.
    }
  }
  return "";
}

export async function interpretLipReading(
  ai: GoogleGenAI | undefined,
  models: string[],
  { question, purpose, profile, heard }: { question: string; purpose: string; profile: Profile; heard: string },
  timeoutMs = 4_000,
): Promise<string> {
  const fallback = sentenceCase(heard);
  if (!ai) return fallback;
  const details = profile.fields
    .filter((field) => !field.sensitive)
    .map((field) => `${field.label}: ${field.value}`)
    .join("\n");
  const prompt = [
    `${profile.displayName} cannot speak clearly and mouthed an answer on a phone call. A lip reading model transcribed it, with mistakes.`,
    `Call purpose: ${purpose}.`,
    `Saved details about ${profile.displayName}:\n${details}`,
    `The other person asked: "${question}"`,
    `Lip reading transcript: "${heard}"`,
    `Write the most likely sentence ${profile.displayName} meant, in the first person, answering the question.`,
    `Keep the meaning, never add facts that are not in the transcript, use at most 25 words. Reply with the sentence only, plain text.`,
  ].join("\n\n");

  const deadline = Date.now() + timeoutMs;
  for (const model of models) {
    const remaining = deadline - Date.now();
    if (remaining <= 200) break;
    try {
      const response = await ai.models.generateContent({
        model,
        contents: prompt,
        config: { abortSignal: AbortSignal.timeout(remaining) },
      });
      const sentence = response.text?.trim().replace(/^"|"$/g, "");
      if (sentence) return sentence;
    } catch {
      // Fall through to the next model.
    }
  }
  return fallback;
}

export function sentenceCase(text: string): string {
  const words = text.trim().replace(/\s+/g, " ").toLowerCase().replace(/\bi\b/g, "I");
  if (!words) return "";
  const sentence = words[0]!.toUpperCase() + words.slice(1);
  return /[.!?]$/.test(sentence) ? sentence : `${sentence}.`;
}
