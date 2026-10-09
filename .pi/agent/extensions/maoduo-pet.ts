/**
 * Maoduo Pet - notifies the desktop pet when a pi run settles.
 *
 * Connects briefly to $XDG_RUNTIME_DIR/maoduo-pet.sock and writes one
 * line of JSON. Fails silently when the pet is not running.
 */
import net from "node:net";
import os from "node:os";
import path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SOCKET_PATH = path.join(
  process.env.XDG_RUNTIME_DIR || path.join("/run/user", String(os.userInfo().uid)),
  "maoduo-pet.sock"
);

function notifyPet(type: string) {
  return new Promise<void>((resolve) => {
    const socket = net.connect(SOCKET_PATH);
    const payload = JSON.stringify({ type, ts: Date.now() }) + "\n";

    const done = () => {
      socket.destroy();
      resolve();
    };

    socket.setTimeout(500, done);
    socket.once("connect", () => {
      socket.write(payload, done);
    });
    socket.once("error", done);
  });
}

export default function (pi: ExtensionAPI) {
  pi.on("agent_settled", async () => {
    await notifyPet("hiss");
  });

  pi.on("session_start", async () => {
    await notifyPet("wake");
  });
}
