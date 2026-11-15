import { connection } from "next/server";
import { demoProfileId } from "@/lib/api";
import { proxyToServer } from "@/lib/proxy";

export async function GET() {
  await connection();
  return proxyToServer(`/api/profiles/${demoProfileId}/calls`);
}
