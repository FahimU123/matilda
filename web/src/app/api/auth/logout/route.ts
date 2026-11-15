import { cookies } from "next/headers";
import { sessionCookie } from "@/lib/auth";

export async function POST(request: Request) {
  (await cookies()).delete(sessionCookie);
  return Response.redirect(new URL("/family", request.url), 303);
}
