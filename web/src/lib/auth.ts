import "server-only";
import { decodeJwt } from "jose";
import { cookies } from "next/headers";
import * as oidc from "openid-client";

export const sessionCookie = "matilda_session";
export const transactionCookie = "matilda_auth_tx";

const issuer = process.env.SSOJET_ISSUER;
const clientId = process.env.SSOJET_CLIENT_ID;
const clientSecret = process.env.SSOJET_CLIENT_SECRET;

export const authConfigured = Boolean(issuer && clientId && clientSecret);

let discovered: Promise<oidc.Configuration> | undefined;

export function oidcConfig(): Promise<oidc.Configuration> {
  if (!issuer || !clientId || !clientSecret) throw new Error("SSOJet is not configured");
  discovered ??= oidc.discovery(new URL(issuer), clientId, clientSecret).catch((error) => {
    discovered = undefined;
    throw error;
  });
  return discovered;
}

export const cookieOptions = {
  httpOnly: true,
  sameSite: "lax" as const,
  secure: process.env.NODE_ENV === "production",
  path: "/",
};

export interface FamilySession {
  idToken: string;
  name: string;
}

export async function readSession(): Promise<FamilySession | undefined> {
  const idToken = (await cookies()).get(sessionCookie)?.value;
  if (!idToken) return undefined;
  const claims = decodeJwt(idToken);
  if (claims.exp && claims.exp * 1000 < Date.now()) return undefined;
  const name = String(claims.name ?? claims.email ?? "Family member");
  return { idToken, name };
}
