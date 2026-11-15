import type { WebSocket } from "ws";

type Channel = `app:${string}` | "line";

export class Hub {
  private readonly channels = new Map<Channel, Set<WebSocket>>();

  join(channel: Channel, socket: WebSocket): void {
    const sockets = this.channels.get(channel) ?? new Set();
    sockets.add(socket);
    this.channels.set(channel, sockets);
    socket.on("close", () => sockets.delete(socket));
  }

  send(channel: Channel, payload: unknown): number {
    const data = JSON.stringify(payload);
    let delivered = 0;
    for (const socket of this.channels.get(channel) ?? []) {
      if (socket.readyState === socket.OPEN) {
        socket.send(data);
        delivered += 1;
      }
    }
    return delivered;
  }

  has(channel: Channel): boolean {
    return (this.channels.get(channel)?.size ?? 0) > 0;
  }
}
