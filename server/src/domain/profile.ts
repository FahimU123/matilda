import { z } from "zod";

export const Pronoun = z.enum(["he", "she", "they"]);
export type Pronoun = z.infer<typeof Pronoun>;

export const ProfileField = z.object({
  key: z.string().min(1),
  label: z.string().min(1),
  value: z.string(),
  sensitive: z.boolean().default(false),
});
export type ProfileField = z.infer<typeof ProfileField>;

export const Place = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  kind: z.enum(["pharmacy", "doctor", "insurance", "caseManager", "bank", "utility", "other"]),
  phone: z.string(),
  purpose: z.string(),
  fieldKeys: z.array(z.string()),
});
export type Place = z.infer<typeof Place>;

export const Profile = z.object({
  id: z.string().min(1),
  displayName: z.string().min(1),
  pronoun: Pronoun,
  condition: z.string(),
  fields: z.array(ProfileField),
  places: z.array(Place),
});
export type Profile = z.infer<typeof Profile>;

export const possessive: Record<Pronoun, string> = { he: "His", she: "Her", they: "Their" };

export function findField(profile: Profile, key: string): ProfileField | undefined {
  return profile.fields.find((field) => field.key === key);
}

export function findPlace(profile: Profile, id: string): Place | undefined {
  return profile.places.find((place) => place.id === id);
}

export function maskValue(hint: string): string {
  return `•••• ${hint.replace(/\s/g, "").slice(-4)}`;
}
