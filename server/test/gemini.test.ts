import { describe, expect, it, vi } from "vitest";
import { KeywordQuestionAnalyzer } from "../src/domain/questionAnalyzer.js";
import { demoProfile } from "../src/demoProfile.js";
import { GeminiQuestionAnalyzer } from "../src/services/gemini.js";

describe("GeminiQuestionAnalyzer", () => {
  it("falls back to the next model, then to keywords", async () => {
    const analyzer = new GeminiQuestionAnalyzer("test-key", ["primary", "backup"], new KeywordQuestionAnalyzer());
    const generate = vi.fn().mockRejectedValue(new Error("model unavailable"));
    (analyzer as unknown as { ai: { models: { generateContent: typeof generate } } }).ai = { models: { generateContent: generate } };

    await expect(analyzer.analyze("What's his date of birth?", demoProfile, "Refill")).resolves.toEqual({
      kind: "field",
      fieldKey: "dateOfBirth",
    });
    expect(generate.mock.calls.map(([request]) => request.model)).toEqual(["primary", "backup"]);
  });

  it("uses the backup model when the primary fails", async () => {
    const analyzer = new GeminiQuestionAnalyzer("test-key", ["primary", "backup"], new KeywordQuestionAnalyzer());
    const generate = vi
      .fn()
      .mockRejectedValueOnce(new Error("rate limited"))
      .mockResolvedValueOnce({ text: JSON.stringify({ kind: "choice", fieldKey: null, options: ["Pickup", "Delivery"] }) });
    (analyzer as unknown as { ai: { models: { generateContent: typeof generate } } }).ai = { models: { generateContent: generate } };

    await expect(analyzer.analyze("Pickup or delivery?", demoProfile, "Refill")).resolves.toEqual({
      kind: "choice",
      options: ["Pickup", "Delivery"],
    });
  });
});
