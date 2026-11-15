import { cookies } from "next/headers";
import * as oidc from "openid-client";
import { cookieOptions, oidcConfig, sessionCookie, transactionCookie } from "@/lib/auth";

export async function GET(request: Request) {
  const jar = await cookies();
  const transaction = jar.get(transactionCookie)?.value;
  if (!transaction) return Response.redirect(new URL("/family?error=expired", request.url));
  jar.delete(transactionCookie);

  let tokens: Awaited<ReturnType<typeof oidc.authorizationCodeGrant>>;
  try {
    const { verifier, state } = JSON.parse(transaction) as { verifier: string; state: string };
    tokens = await oidc.authorizationCodeGrant(await oidcConfig(), new URL(request.url), {
      pkceCodeVerifier: verifier,
      expectedState: state,
    });
  } catch {
    return Response.redirect(new URL("/family?error=signin", request.url));
  }

  if (!tokens.id_token) return Response.redirect(new URL("/family?error=no-token", request.url));
  jar.set(sessionCookie, tokens.id_token, { ...cookieOptions, maxAge: tokens.expires_in ?? 3600 });
  return Response.redirect(new URL("/family", request.url));
}
