import "server-only";
import { serverUrl } from "./api";
import { authConfigured, readSession } from "./auth";

export async function proxyToServer(path: string, init: RequestInit = {}): Promise<Response> {
  const session = await readSession();
  if (authConfigured && !session) return Response.json({ error: "Sign in to continue" }, { status: 401 });

  const response = await fetch(`${serverUrl}${path}`, {
    ...init,
    headers: {
      "content-type": "application/json",
      ...(session ? { authorization: `Bearer ${session.idToken}` } : {}),
    },
    cache: "no-store",
  });
  return new Response(response.body, { status: response.status, headers: { "content-type": "application/json" } });
}
