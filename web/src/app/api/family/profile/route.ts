import { connection } from "next/server";
import { demoProfileId } from "@/lib/api";
import { proxyToServer } from "@/lib/proxy";

export async function GET() {
  await connection();
  return proxyToServer(`/api/profiles/${demoProfileId}`);
}

export async function PUT(request: Request) {
  return proxyToServer(`/api/profiles/${demoProfileId}`, { method: "PUT", body: await request.text() });
}
