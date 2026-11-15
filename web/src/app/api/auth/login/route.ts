import { connection } from "next/server";
import { cookies } from "next/headers";
import * as oidc from "openid-client";
import { cookieOptions, oidcConfig, transactionCookie } from "@/lib/auth";

export async function GET(request: Request) {
  await connection();
  const config = await oidcConfig();
  const verifier = oidc.randomPKCECodeVerifier();
  const state = oidc.randomState();
  const redirectUri = new URL("/api/auth/callback", request.url).toString();

  (await cookies()).set(transactionCookie, JSON.stringify({ verifier, state }), { ...cookieOptions, maxAge: 600 });

  const url = oidc.buildAuthorizationUrl(config, {
    redirect_uri: redirectUri,
    scope: "openid profile email",
    code_challenge: await oidc.calculatePKCECodeChallenge(verifier),
    code_challenge_method: "S256",
    state,
  });
  return Response.redirect(url.href);
}
