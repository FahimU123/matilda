import { randomUUID } from "node:crypto";
import { findField, maskValue, possessive, type Profile } from "./profile.js";

export type QuestionAnalysis =
  | { kind: "field"; fieldKey: string }
  | { kind: "choice"; options: string[] }
  | { kind: "open"; suggestions: string[] };

export interface Suggestion {
  id: string;
  label: string;
  say: string;
}

export interface AnswerCard {
  id: string;
  question: string;
  suggestions: Suggestion[];
  sensitiveFieldKey?: string;
}

export const declineSay = (profile: Profile) =>
  `${profile.displayName} says that's not right. One moment please.`;

export function buildCard(question: string, analysis: QuestionAnalysis, profile: Profile): AnswerCard {
  const id = randomUUID();

  if (analysis.kind === "field") {
    const field = findField(profile, analysis.fieldKey);
    if (field) {
      const subject = `${possessive[profile.pronoun]} ${field.label.toLowerCase()}`;
      if (field.sensitive) {
        return {
          id,
          question,
          sensitiveFieldKey: field.key,
          suggestions: [
            {
              id: "0",
              label: field.value ? maskValue(field.value) : "Saved on this phone",
              say: `${subject} is {{value}}.`,
            },
          ],
        };
      }
      return {
        id,
        question,
        suggestions: [{ id: "0", label: field.value, say: `${subject} is ${field.value}.` }],
      };
    }
  }

  const options =
    analysis.kind === "choice" ? analysis.options : analysis.kind === "open" ? analysis.suggestions : [];

  return {
    id,
    question,
    suggestions: options.slice(0, 3).map((option, index) => ({
      id: String(index),
      label: option,
      say: analysis.kind === "choice" ? `${option}, please.` : option,
    })),
  };
}

export function sayForSensitive(template: string, value: string): string {
  return template.replace("{{value}}", value.split("").join(" "));
}
