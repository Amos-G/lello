import assert from "node:assert/strict";
import { once } from "node:events";
import test from "node:test";
import jwt from "jsonwebtoken";
import WebSocket from "ws";
import { generate, generateSecret, generateURI, verify } from "otplib";
import QRCode from "qrcode";

const jwtSecret = "test-jwt-secret-with-at-least-32-characters";
process.env.PORT = "0";
process.env.DATABASE_URL = "postgresql://unused:unused@127.0.0.1:1/unused";
process.env.JWT_SECRET = jwtSecret;
process.env.LOGIN_TICKET_SECRET = "different-login-ticket-secret-for-tests";
process.env.TOTP_ENCRYPTION_KEY = "totp-encryption-key-used-only-in-tests";
process.env.CORS_ORIGIN = "https://partysync.amosgranata.it";
process.env.TRUST_PROXY_HOPS = "0";

const { server, encryptTotpSecret, decryptTotpSecret } = await import(
  "../src/server.js"
);
if (!server.listening) await once(server, "listening");
const { port } = server.address();
const baseUrl = `http://127.0.0.1:${port}`;

test.after(async () => {
  await new Promise((resolve) => server.close(resolve));
});

test("protegge le API e applica gli header di sicurezza", async () => {
  const response = await fetch(`${baseUrl}/api/auth/me`);
  assert.equal(response.status, 401);
  assert.equal(response.headers.get("x-content-type-options"), "nosniff");
  assert.equal(response.headers.get("x-powered-by"), null);
});

test("rifiuta origini browser non autorizzate", async () => {
  const response = await fetch(`${baseUrl}/api/auth/login`, {
    method: "OPTIONS",
    headers: {
      origin: "https://attacker.invalid",
      "access-control-request-method": "POST",
    },
  });
  assert.equal(response.status, 403);
  assert.equal(response.headers.get("access-control-allow-origin"), null);
});

test("autentica WebSocket senza inserire il JWT nella URL", async () => {
  const token = jwt.sign(
    { sub: "1", username: "test", type: "access" },
    jwtSecret,
    {
      algorithm: "HS256",
      issuer: "partysync-api",
      audience: "partysync-app",
      expiresIn: "1m",
    },
  );
  const socket = new WebSocket(`ws://127.0.0.1:${port}/ws`);
  await once(socket, "open");
  socket.send(JSON.stringify({ type: "auth", token }));
  const [raw] = await once(socket, "message");
  assert.deepEqual(JSON.parse(raw.toString()), { event: "connected" });
  socket.close();
  await once(socket, "close");
});

test("genera, cifra e verifica una configurazione TOTP completa", async () => {
  const secret = generateSecret();
  const encrypted = encryptTotpSecret(secret);
  assert.match(encrypted, /^enc:v1:/);
  assert.equal(encrypted.includes(secret), false);
  assert.deepEqual(decryptTotpSecret(encrypted), { secret, legacy: false });

  const uri = generateURI({ issuer: "Lello", label: "test", secret });
  const qr = await QRCode.toDataURL(uri);
  assert.match(uri, /^otpauth:\/\/totp\//);
  assert.match(qr, /^data:image\/png;base64,/);

  const token = await generate({ secret });
  assert.equal((await verify({ secret, token })).valid, true);
  const wrongToken = token === "000000" ? "000001" : "000000";
  assert.equal((await verify({ secret, token: wrongToken })).valid, false);
});
