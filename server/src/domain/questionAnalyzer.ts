import type { QuestionAnalysis } from "./answerCard.js";
import type { Profile } from "./profile.js";

export interface QuestionAnalyzer {
  analyze(question: string, profile: Profile, purpose: string): Promise<QuestionAnalysis>;
}

const fieldHints: Array<[RegExp, string]> = [
  [/(date of birth|birthday|\bdob\b|born)/i, "dateOfBirth"],
  [/(full name|spell .*name|your name|patient'?s name)/i, "fullName"],
  [/(address|where .* live|zip)/i, "address"],
  [/(phone number|callback|call .* back)/i, "phone"],
  [/(member id|insurance id|policy number)/i, "insuranceMemberId"],
  [/(prescription number|\brx\b)/i, "rxNumber"],
  [/(social security|\bssn\b)/i, "ssn"],
  [/(card number|credit card|debit card)/i, "cardNumber"],
];

export class KeywordQuestionAnalyzer implements QuestionAnalyzer {
  async analyze(question: string, profile: Profile): Promise<QuestionAnalysis> {
    for (const [pattern, key] of fieldHints) {
      if (pattern.test(question) && profile.fields.some((field) => field.key === key)) {
        return { kind: "field", fieldKey: key };
      }
    }

    const either = question.match(/(\w+)\s+or\s+(\w+)\W*$/i);
    if (either?.[1] && either[2]) {
      return { kind: "choice", options: [capitalize(either[1]), capitalize(either[2])] };
    }

    return { kind: "open", suggestions: ["Yes", "No", "Could you repeat that?"] };
  }
}

function capitalize(text: string): string {
  return text.charAt(0).toUpperCase() + text.slice(1);
}
