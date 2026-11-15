import { createRemoteJWKSet, jwtVerify } from "jose";

type Keys = ReturnType<typeof createRemoteJWKSet>;

export function familyAuth(
  issuer: string | undefined,
  audience?: string,
): (authorization: string | undefined) => Promise<boolean> {
  if (!issuer) return async () => true;

  let discovery: Promise<Keys> | undefined;
  const keys = () =>
    (discovery ??= fetch(`${issuer}/.well-known/openid-configuration`)
      .then((response) => {
        if (!response.ok) throw new Error(`OIDC discovery failed: ${response.status}`);
        return response.json() as Promise<{ jwks_uri: string }>;
      })
      .then((body) => createRemoteJWKSet(new URL(body.jwks_uri)))
      .catch((error) => {
        discovery = undefined;
        throw error;
      }));

  return async (authorization) => {
    const token = authorization?.replace(/^Bearer /, "");
    if (!token) return false;
    try {
      await jwtVerify(token, await keys(), { issuer, audience });
      return true;
    } catch {
      return false;
    }
  };
}
