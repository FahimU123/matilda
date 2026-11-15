export const serverUrl = process.env.NEXT_PUBLIC_SERVER_URL ?? "http://localhost:8787";

export const socketUrl = (path: string) => `${serverUrl.replace(/^http/, "ws")}${path}`;

export const appKey = process.env.NEXT_PUBLIC_APP_KEY ?? "dev-app-key-change-me";

export const assistantName = "Matilda";

export const demoProfileId = process.env.NEXT_PUBLIC_PROFILE_ID ?? "ray";

export type Pronoun = "he" | "she" | "they";

export interface ProfileField {
  key: string;
  label: string;
  value: string;
  sensitive: boolean;
}

export type PlaceKind = "pharmacy" | "doctor" | "insurance" | "caseManager" | "bank" | "utility" | "other";

export interface Place {
  id: string;
  name: string;
  kind: PlaceKind;
  phone: string;
  purpose: string;
  fieldKeys: string[];
}

export interface Profile {
  id: string;
  displayName: string;
  pronoun: Pronoun;
  condition: string;
  fields: ProfileField[];
  places: Place[];
}

export interface ConsentEntry {
  question: string;
  answer: string;
  method: "thumbs" | "nod" | "lips" | "tap" | "voice";
  at: number;
}

export interface CallRecord {
  id: string;
  placeId: string;
  startedAt: number;
  endedAt: number;
  summary: string;
  consents: ConsentEntry[];
}

export const methodLabel: Record<ConsentEntry["method"], string> = {
  thumbs: "Thumbs up or down",
  nod: "Head nod",
  lips: "Mouthed",
  tap: "Tapped",
  voice: "Said yes",
};
