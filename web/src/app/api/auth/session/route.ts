import { connection } from "next/server";
import { authConfigured, readSession } from "@/lib/auth";

export async function GET() {
  await connection();
  const session = await readSession();
  return Response.json({ configured: authConfigured, signedIn: Boolean(session), name: session?.name ?? null });
}
