import http from "node:http";
import crypto from "node:crypto";
import express from "express";
import cors from "cors";
import helmet from "helmet";
import { rateLimit } from "express-rate-limit";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { generateSecret, generateURI, verify as verifyTotp } from "otplib";
import QRCode from "qrcode";
import pg from "pg";
import { WebSocketServer } from "ws";

const { Pool } = pg;
const PORT = Number(process.env.PORT || 3000);
const JWT_SECRET = process.env.JWT_SECRET || "";
const LOGIN_TICKET_SECRET = process.env.LOGIN_TICKET_SECRET || "";
const TOTP_ENCRYPTION_KEY = process.env.TOTP_ENCRYPTION_KEY || "";
const DATABASE_URL = process.env.DATABASE_URL || "";
if (JWT_SECRET.length < 32)
  throw new Error("JWT_SECRET deve contenere almeno 32 caratteri");
if (LOGIN_TICKET_SECRET.length < 32 || LOGIN_TICKET_SECRET === JWT_SECRET) {
  throw new Error(
    "LOGIN_TICKET_SECRET deve essere distinto da JWT_SECRET e lungo almeno 32 caratteri",
  );
}
if (TOTP_ENCRYPTION_KEY.length < 32) {
  throw new Error("TOTP_ENCRYPTION_KEY deve contenere almeno 32 caratteri");
}
if (!DATABASE_URL)
  throw new Error("DATABASE_URL deve puntare al database PostgreSQL reale");

const JWT_ISSUER = "partysync-api";
const JWT_AUDIENCE = "partysync-app";
const JWT_VERIFY_OPTIONS = {
  algorithms: ["HS256"],
  issuer: JWT_ISSUER,
  audience: JWT_AUDIENCE,
};
const totpKey = crypto
  .createHash("sha256")
  .update(TOTP_ENCRYPTION_KEY)
  .digest();
const dummyPasswordHash = bcrypt.hashSync(
  crypto.randomBytes(32).toString("hex"),
  12,
);

const encryptTotpSecret = (secret) => {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", totpKey, iv);
  const encrypted = Buffer.concat([
    cipher.update(secret, "utf8"),
    cipher.final(),
  ]);
  return [
    "enc",
    "v1",
    iv.toString("base64url"),
    cipher.getAuthTag().toString("base64url"),
    encrypted.toString("base64url"),
  ].join(":");
};
const decryptTotpSecret = (stored) => {
  if (!stored?.startsWith("enc:v1:")) return { secret: stored, legacy: true };
  const [, , iv, tag, encrypted] = stored.split(":");
  const decipher = crypto.createDecipheriv(
    "aes-256-gcm",
    totpKey,
    Buffer.from(iv, "base64url"),
  );
  decipher.setAuthTag(Buffer.from(tag, "base64url"));
  const secret = Buffer.concat([
    decipher.update(Buffer.from(encrypted, "base64url")),
    decipher.final(),
  ]).toString("utf8");
  return { secret, legacy: false };
};

const encodeUserInfoPart = (value) =>
  value.replace(/%(?![0-9A-Fa-f]{2})|[/?#[\]@\\\s]/g, encodeURIComponent);
const normalizeDatabaseUrl = (value) => {
  try {
    new URL(value);
    return value;
  } catch {
    const match = value.match(/^(postgres(?:ql)?:\/\/)(.*)@(.*)$/s);
    if (!match) throw new Error("DATABASE_URL non valida");
    const [, scheme, userinfo, rest] = match;
    const separator = userinfo.indexOf(":");
    if (separator < 0) throw new Error("DATABASE_URL non valida");
    const username = encodeUserInfoPart(userinfo.slice(0, separator));
    const password = encodeUserInfoPart(userinfo.slice(separator + 1));
    const normalized = `${scheme}${username}:${password}@${rest}`;
    new URL(normalized);
    return normalized;
  }
};

const pool = new Pool({ connectionString: normalizeDatabaseUrl(DATABASE_URL) });
const app = express();
const allowedOrigins = new Set(
  (process.env.CORS_ORIGIN || "https://partysync.amosgranata.it")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
);
const isAllowedOrigin = (origin) => !origin || allowedOrigins.has(origin);

app.disable("x-powered-by");
app.set("trust proxy", Number(process.env.TRUST_PROXY_HOPS || 1));
app.use(helmet());
app.use(
  cors({
    origin(origin, callback) {
      if (isAllowedOrigin(origin)) return callback(null, true);
      const error = new Error("Origine non autorizzata");
      error.status = 403;
      callback(error);
    },
  }),
);
app.use(express.json({ limit: "64kb" }));
app.use(
  "/api",
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 300,
    standardHeaders: "draft-8",
    legacyHeaders: false,
  }),
);

const authRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: "draft-8",
  legacyHeaders: false,
  skipSuccessfulRequests: true,
  message: { error: "Troppi tentativi. Riprova più tardi" },
});

const asyncRoute = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);
const clean = (value, field, max = 255) => {
  if (typeof value !== "string" || !value.trim() || value.trim().length > max) {
    const error = new Error(`${field} non valido`);
    error.status = 400;
    throw error;
  }
  return value.trim();
};
const cleanPositiveCents = (value, field) => {
  const cents = Number(value);
  if (!Number.isInteger(cents) || cents <= 0 || cents > 100_000_000) {
    const error = new Error(`${field} non valido`);
    error.status = 400;
    throw error;
  }
  return cents;
};
const getDefaultLabel = async (client = pool) => {
  const { rows } = await client.query(
    `SELECT valore FROM impostazioni_app
     WHERE chiave='etichetta_chi_porta_default'`,
  );
  return rows[0]?.valore || "Da Assegnare";
};
const getLabelsReport = async (client = pool) => {
  const defaultLabel = await getDefaultLabel(client);
  const { rows } = await client.query(
    "SELECT DISTINCT chi_porta FROM elementi ORDER BY chi_porta",
  );
  return {
    default_label: defaultLabel,
    labels: rows.map((row) => row.chi_porta),
  };
};
const userToken = (user) =>
  jwt.sign(
    { sub: String(user.id), username: user.username, type: "access" },
    JWT_SECRET,
    {
      algorithm: "HS256",
      issuer: JWT_ISSUER,
      audience: JWT_AUDIENCE,
      expiresIn: "24h",
    },
  );
const ticketToken = (user) =>
  jwt.sign(
    { sub: String(user.id), purpose: "2fa-login" },
    LOGIN_TICKET_SECRET,
    {
      algorithm: "HS256",
      issuer: JWT_ISSUER,
      audience: JWT_AUDIENCE,
      expiresIn: "5m",
    },
  );
const auth = (req, res, next) => {
  try {
    const raw = req.headers.authorization?.match(/^Bearer (.+)$/)?.[1];
    if (!raw) throw new Error("missing");
    req.user = jwt.verify(raw, JWT_SECRET, JWT_VERIFY_OPTIONS);
    if (req.user.type !== "access") throw new Error("wrong token type");
    next();
  } catch {
    res.status(401).json({ error: "Token mancante o non valido" });
  }
};

app.get(
  "/health",
  asyncRoute(async (_req, res) => {
    await pool.query("SELECT 1");
    res.json({ status: "ok" });
  }),
);

app.post(
  "/api/auth/login",
  authRateLimit,
  asyncRoute(async (req, res) => {
    const username = clean(req.body.username, "username", 80);
    const password = String(req.body.password || "");
    if (!password || password.length > 1024) {
      return res.status(401).json({ error: "Credenziali non valide" });
    }
    const { rows } = await pool.query(
      "SELECT id, username, password_hash, totp_enabled FROM utenti WHERE username=$1",
      [username],
    );
    const user = rows[0];
    const validPassword = await bcrypt.compare(
      password,
      user?.password_hash || dummyPasswordHash,
    );
    if (!user || !validPassword) {
      return res.status(401).json({ error: "Credenziali non valide" });
    }
    if (user.totp_enabled) {
      return res.json({ requires_2fa: true, login_ticket: ticketToken(user) });
    }
    res.json({ requires_2fa: false, token: userToken(user) });
  }),
);

app.post(
  "/api/auth/verify-2fa",
  authRateLimit,
  asyncRoute(async (req, res) => {
    let ticket;
    try {
      ticket = jwt.verify(
        String(req.body.login_ticket || ""),
        LOGIN_TICKET_SECRET,
        JWT_VERIFY_OPTIONS,
      );
      if (ticket.purpose !== "2fa-login") throw new Error("purpose");
    } catch {
      return res.status(401).json({ error: "Ticket 2FA scaduto o non valido" });
    }
    const { rows } = await pool.query(
      "SELECT id, username, totp_secret, totp_enabled FROM utenti WHERE id=$1",
      [ticket.sub],
    );
    const user = rows[0];
    const code = String(req.body.code || "");
    const storedSecret = user?.totp_secret;
    const decrypted = storedSecret ? decryptTotpSecret(storedSecret) : null;
    if (
      !user?.totp_enabled ||
      !/^\d{6}$/.test(code) ||
      !(await verifyTotp({ secret: decrypted.secret, token: code })).valid
    ) {
      return res.status(401).json({ error: "Codice OTP non valido" });
    }
    if (decrypted.legacy) {
      await pool.query("UPDATE utenti SET totp_secret=$1 WHERE id=$2", [
        encryptTotpSecret(decrypted.secret),
        user.id,
      ]);
    }
    res.json({ token: userToken(user) });
  }),
);

app.get(
  "/api/auth/me",
  auth,
  asyncRoute(async (req, res) => {
    const { rows } = await pool.query(
      "SELECT id, username, totp_enabled FROM utenti WHERE id=$1",
      [req.user.sub],
    );
    if (!rows[0]) return res.status(404).json({ error: "Utente non trovato" });
    res.json(rows[0]);
  }),
);

app.post(
  "/api/auth/2fa/setup",
  auth,
  asyncRoute(async (req, res) => {
    const secret = generateSecret();
    const { rows } = await pool.query(
      `UPDATE utenti SET totp_secret=$1
     WHERE id=$2 AND totp_enabled=FALSE
     RETURNING username`,
      [encryptTotpSecret(secret), req.user.sub],
    );
    if (!rows[0]) {
      return res
        .status(409)
        .json({ error: "Disattiva prima la configurazione 2FA esistente" });
    }
    const otpauth_uri = generateURI({
      issuer: "Lello",
      label: rows[0].username,
      secret,
    });
    res.json({
      secret,
      otpauth_uri,
      qr_data_url: await QRCode.toDataURL(otpauth_uri),
    });
  }),
);

app.post(
  "/api/auth/2fa/enable",
  authRateLimit,
  auth,
  asyncRoute(async (req, res) => {
    const { rows } = await pool.query(
      "SELECT totp_secret FROM utenti WHERE id=$1",
      [req.user.sub],
    );
    const storedSecret = rows[0]?.totp_secret;
    const code = String(req.body.code || "");
    const secret = storedSecret ? decryptTotpSecret(storedSecret).secret : null;
    if (
      !secret ||
      !/^\d{6}$/.test(code) ||
      !(await verifyTotp({ secret, token: code })).valid
    ) {
      return res.status(400).json({ error: "Codice OTP non valido" });
    }
    await pool.query("UPDATE utenti SET totp_enabled=TRUE WHERE id=$1", [
      req.user.sub,
    ]);
    res.json({ totp_enabled: true });
  }),
);

app.post(
  "/api/auth/2fa/disable",
  authRateLimit,
  auth,
  asyncRoute(async (req, res) => {
    const { rows } = await pool.query(
      "SELECT password_hash FROM utenti WHERE id=$1",
      [req.user.sub],
    );
    if (
      !rows[0] ||
      !(await bcrypt.compare(
        String(req.body.password || ""),
        rows[0].password_hash,
      ))
    ) {
      return res.status(401).json({ error: "Password non valida" });
    }
    await pool.query(
      "UPDATE utenti SET totp_enabled=FALSE, totp_secret=NULL WHERE id=$1",
      [req.user.sub],
    );
    res.json({ totp_enabled: false });
  }),
);

const server = http.createServer(app);
server.requestTimeout = 10_000;
server.headersTimeout = 15_000;
server.keepAliveTimeout = 5_000;
server.maxRequestsPerSocket = 500;

const wss = new WebSocketServer({
  noServer: true,
  maxPayload: 4096,
  perMessageDeflate: false,
});
const broadcast = (event, payload) => {
  const message = JSON.stringify({
    event,
    payload,
    at: new Date().toISOString(),
  });
  for (const client of wss.clients) {
    if (client.readyState === 1 && client.authenticated) client.send(message);
  }
};
server.on("upgrade", (req, socket, head) => {
  if (
    req.url !== "/ws" ||
    !isAllowedOrigin(req.headers.origin) ||
    wss.clients.size >= 100
  ) {
    return socket.destroy();
  }
  wss.handleUpgrade(req, socket, head, (ws) => wss.emit("connection", ws));
});
wss.on("connection", (ws) => {
  ws.authenticated = false;
  const timeout = setTimeout(
    () => ws.close(1008, "Authentication timeout"),
    5000,
  );
  ws.once("message", (raw, isBinary) => {
    try {
      if (isBinary) throw new Error("binary auth");
      const message = JSON.parse(raw.toString());
      const payload = jwt.verify(
        String(message.token || ""),
        JWT_SECRET,
        JWT_VERIFY_OPTIONS,
      );
      if (message.type !== "auth" || payload.type !== "access") {
        throw new Error("invalid auth");
      }
      clearTimeout(timeout);
      ws.authenticated = true;
      ws.send(JSON.stringify({ event: "connected" }));
      const expiresIn = Math.max(0, payload.exp * 1000 - Date.now());
      const expiryTimeout = setTimeout(
        () => ws.close(1008, "Token expired"),
        expiresIn,
      );
      ws.once("close", () => clearTimeout(expiryTimeout));
    } catch {
      clearTimeout(timeout);
      ws.close(1008, "Unauthorized");
    }
  });
});

app.get(
  "/api/elementi",
  auth,
  asyncRoute(async (_req, res) => {
    const { rows } = await pool.query(
      "SELECT * FROM elementi ORDER BY created_at DESC, id DESC",
    );
    res.json(rows);
  }),
);
app.post(
  "/api/elementi",
  auth,
  asyncRoute(async (req, res) => {
    const nome = clean(req.body.nome, "nome");
    const chi = req.body.chi_porta
      ? clean(req.body.chi_porta, "chi_porta", 120)
      : await getDefaultLabel();
    const { rows } = await pool.query(
      "INSERT INTO elementi(nome, chi_porta) VALUES($1,$2) RETURNING *",
      [nome, chi],
    );
    broadcast("elemento.created", rows[0]);
    res.status(201).json(rows[0]);
  }),
);
app.patch(
  "/api/elementi/:id",
  auth,
  asyncRoute(async (req, res) => {
    const fields = [];
    const values = [];
    if ("nome" in req.body) {
      values.push(clean(req.body.nome, "nome"));
      fields.push(`nome=$${values.length}`);
    }
    if ("chi_porta" in req.body) {
      values.push(clean(req.body.chi_porta, "chi_porta", 120));
      fields.push(`chi_porta=$${values.length}`);
    }
    if ("completato" in req.body) {
      if (typeof req.body.completato !== "boolean") {
        return res
          .status(400)
          .json({ error: "completato deve essere boolean" });
      }
      values.push(req.body.completato);
      fields.push(`completato=$${values.length}`);
    }
    if (!fields.length)
      return res.status(400).json({ error: "Nessun campo aggiornabile" });
    values.push(req.params.id);
    const { rows } = await pool.query(
      `UPDATE elementi SET ${fields.join(",")} WHERE id=$${values.length} RETURNING *`,
      values,
    );
    if (!rows[0])
      return res.status(404).json({ error: "Elemento non trovato" });
    broadcast("elemento.updated", rows[0]);
    res.json(rows[0]);
  }),
);
app.delete(
  "/api/elementi/:id",
  auth,
  asyncRoute(async (req, res) => {
    const { rows } = await pool.query(
      "DELETE FROM elementi WHERE id=$1 RETURNING id",
      [req.params.id],
    );
    if (!rows[0])
      return res.status(404).json({ error: "Elemento non trovato" });
    broadcast("elemento.deleted", rows[0]);
    res.status(204).end();
  }),
);

app.get(
  "/api/etichette",
  auth,
  asyncRoute(async (_req, res) => {
    res.json(await getLabelsReport());
  }),
);

app.patch(
  "/api/etichette/default",
  auth,
  asyncRoute(async (req, res) => {
    const newLabel = clean(req.body.label, "label", 120);
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      const oldLabel = await getDefaultLabel(client);
      if (oldLabel !== newLabel) {
        await client.query(
          "UPDATE elementi SET chi_porta=$1 WHERE chi_porta=$2",
          [newLabel, oldLabel],
        );
        await client.query(
          `INSERT INTO impostazioni_app(chiave, valore)
           VALUES ('etichetta_chi_porta_default', $1)
           ON CONFLICT (chiave) DO UPDATE SET valore=EXCLUDED.valore`,
          [newLabel],
        );
      }
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
    const report = await getLabelsReport();
    broadcast("etichette.updated", report);
    res.json(report);
  }),
);

app.delete(
  "/api/etichette",
  auth,
  asyncRoute(async (req, res) => {
    const label = clean(req.body.label, "label", 120);
    const client = await pool.connect();
    let reassignedCount = 0;
    try {
      await client.query("BEGIN");
      const defaultLabel = await getDefaultLabel(client);
      if (label === defaultLabel) {
        const error = new Error(
          "L'etichetta predefinita può essere rinominata ma non rimossa",
        );
        error.status = 400;
        throw error;
      }
      const result = await client.query(
        "UPDATE elementi SET chi_porta=$1 WHERE chi_porta=$2",
        [defaultLabel, label],
      );
      reassignedCount = result.rowCount;
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
    const report = {
      ...(await getLabelsReport()),
      reassigned_count: reassignedCount,
    };
    broadcast("etichette.updated", report);
    res.json(report);
  }),
);

const buildExpenseSummary = (users, expenses) => {
  if (!users.length) {
    return { participants: [], settlements: [], total_cents: 0 };
  }
  const paidByUser = new Map(users.map((user) => [String(user.id), 0]));
  let totalCents = 0;
  for (const expense of expenses) {
    const userId = String(expense.utente_id);
    const amount = Number(expense.importo_cents);
    paidByUser.set(userId, (paidByUser.get(userId) || 0) + amount);
    totalCents += amount;
  }
  const baseShare = Math.floor(totalCents / users.length);
  const remainder = totalCents % users.length;
  const participants = users.map((user, index) => {
    const paid = paidByUser.get(String(user.id)) || 0;
    const quota = baseShare + (index < remainder ? 1 : 0);
    return {
      user_id: user.id,
      username: user.username,
      paid_cents: paid,
      share_cents: quota,
      balance_cents: paid - quota,
    };
  });
  const creditors = participants
    .filter((user) => user.balance_cents > 0)
    .map((user) => ({ ...user, remaining_cents: user.balance_cents }))
    .sort(
      (a, b) =>
        b.remaining_cents - a.remaining_cents ||
        a.username.localeCompare(b.username),
    );
  const debtors = participants
    .filter((user) => user.balance_cents < 0)
    .map((user) => ({ ...user, remaining_cents: -user.balance_cents }))
    .sort(
      (a, b) =>
        b.remaining_cents - a.remaining_cents ||
        a.username.localeCompare(b.username),
    );
  const settlements = [];
  let creditorIndex = 0;
  for (const debtor of debtors) {
    while (debtor.remaining_cents > 0 && creditorIndex < creditors.length) {
      const creditor = creditors[creditorIndex];
      const amount = Math.min(debtor.remaining_cents, creditor.remaining_cents);
      settlements.push({
        from_user_id: debtor.user_id,
        from_username: debtor.username,
        to_user_id: creditor.user_id,
        to_username: creditor.username,
        amount_cents: amount,
      });
      debtor.remaining_cents -= amount;
      creditor.remaining_cents -= amount;
      if (creditor.remaining_cents === 0) creditorIndex += 1;
    }
  }
  return { participants, settlements, total_cents: totalCents };
};

app.get(
  "/api/spese",
  auth,
  asyncRoute(async (_req, res) => {
    const [usersResult, expensesResult] = await Promise.all([
      pool.query("SELECT id, username FROM utenti ORDER BY id"),
      pool.query(`
        SELECT spese.*, utenti.username
        FROM spese
        JOIN utenti ON utenti.id=spese.utente_id
        ORDER BY spese.created_at DESC, spese.id DESC`),
    ]);
    res.json({
      spese: expensesResult.rows,
      ...buildExpenseSummary(usersResult.rows, expensesResult.rows),
    });
  }),
);

app.post(
  "/api/spese",
  auth,
  asyncRoute(async (req, res) => {
    const descrizione = clean(req.body.descrizione, "descrizione");
    const importoCents = cleanPositiveCents(
      req.body.importo_cents,
      "importo_cents",
    );
    const { rows } = await pool.query(
      `INSERT INTO spese(utente_id, descrizione, importo_cents)
       VALUES($1,$2,$3)
       RETURNING *`,
      [req.user.sub, descrizione, importoCents],
    );
    broadcast("spesa.created", rows[0]);
    res.status(201).json(rows[0]);
  }),
);

app.delete(
  "/api/spese/:id",
  auth,
  asyncRoute(async (req, res) => {
    const { rows } = await pool.query(
      "DELETE FROM spese WHERE id=$1 RETURNING id",
      [req.params.id],
    );
    if (!rows[0]) return res.status(404).json({ error: "Spesa non trovata" });
    broadcast("spesa.deleted", rows[0]);
    res.status(204).end();
  }),
);

app.get(
  "/api/scenari",
  auth,
  asyncRoute(async (_req, res) => {
    const { rows } = await pool.query(`
    SELECT s.*, COALESCE(json_agg(e ORDER BY e.created_at DESC)
      FILTER (WHERE e.id IS NOT NULL), '[]') AS elementi
    FROM scenari s
    LEFT JOIN scenario_elementi se ON se.scenario_id=s.id
    LEFT JOIN elementi e ON e.id=se.elemento_id
    GROUP BY s.id ORDER BY s.created_at DESC`);
    res.json(rows);
  }),
);
app.post(
  "/api/scenari",
  auth,
  asyncRoute(async (req, res) => {
    const { rows } = await pool.query(
      "INSERT INTO scenari(titolo) VALUES($1) RETURNING *",
      [clean(req.body.titolo, "titolo")],
    );
    rows[0].elementi = [];
    broadcast("scenario.created", rows[0]);
    res.status(201).json(rows[0]);
  }),
);
app.patch(
  "/api/scenari/:id",
  auth,
  asyncRoute(async (req, res) => {
    const { rows } = await pool.query(
      "UPDATE scenari SET titolo=$1 WHERE id=$2 RETURNING *",
      [clean(req.body.titolo, "titolo"), req.params.id],
    );
    if (!rows[0])
      return res.status(404).json({ error: "Scenario non trovato" });
    broadcast("scenario.updated", rows[0]);
    res.json(rows[0]);
  }),
);
app.delete(
  "/api/scenari/:id",
  auth,
  asyncRoute(async (req, res) => {
    const { rows } = await pool.query(
      "DELETE FROM scenari WHERE id=$1 RETURNING id",
      [req.params.id],
    );
    if (!rows[0])
      return res.status(404).json({ error: "Scenario non trovato" });
    broadcast("scenario.deleted", rows[0]);
    res.status(204).end();
  }),
);
app.post(
  "/api/scenari/:id/elementi/:elementoId",
  auth,
  asyncRoute(async (req, res) => {
    try {
      await pool.query(
        "INSERT INTO scenario_elementi(scenario_id, elemento_id) VALUES($1,$2)",
        [req.params.id, req.params.elementoId],
      );
    } catch (error) {
      if (error.code === "23505")
        return res.status(409).json({ error: "Associazione già presente" });
      if (error.code === "23503")
        return res
          .status(404)
          .json({ error: "Scenario o elemento non trovato" });
      throw error;
    }
    const payload = {
      scenario_id: Number(req.params.id),
      elemento_id: Number(req.params.elementoId),
    };
    broadcast("scenario.elemento_added", payload);
    res.status(201).json(payload);
  }),
);
app.post(
  "/api/scenari/:id/elementi",
  auth,
  asyncRoute(async (req, res) => {
    const nome = clean(req.body.nome, "nome");
    const client = await pool.connect();
    let item;
    try {
      await client.query("BEGIN");
      const chi = req.body.chi_porta
        ? clean(req.body.chi_porta, "chi_porta", 120)
        : await getDefaultLabel(client);
      const { rows } = await client.query(
        "INSERT INTO elementi(nome, chi_porta) VALUES($1,$2) RETURNING *",
        [nome, chi],
      );
      item = rows[0];
      await client.query(
        "INSERT INTO scenario_elementi(scenario_id, elemento_id) VALUES($1,$2)",
        [req.params.id, item.id],
      );
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      if (error.code === "23503") {
        return res.status(404).json({ error: "Scenario non trovato" });
      }
      throw error;
    } finally {
      client.release();
    }
    broadcast("elemento.created", item);
    broadcast("scenario.elemento_added", {
      scenario_id: String(req.params.id),
      elemento_id: String(item.id),
    });
    res.status(201).json(item);
  }),
);
app.delete(
  "/api/scenari/:id/elementi/:elementoId",
  auth,
  asyncRoute(async (req, res) => {
    const result = await pool.query(
      "DELETE FROM scenario_elementi WHERE scenario_id=$1 AND elemento_id=$2",
      [req.params.id, req.params.elementoId],
    );
    if (!result.rowCount)
      return res.status(404).json({ error: "Associazione non trovata" });
    const payload = {
      scenario_id: Number(req.params.id),
      elemento_id: Number(req.params.elementoId),
    };
    broadcast("scenario.elemento_removed", payload);
    res.status(204).end();
  }),
);

app.use((error, _req, res, _next) => {
  if (!error.status || error.status >= 500) console.error(error);
  res.status(error.status || 500).json({
    error: error.status ? error.message : "Errore interno del server",
  });
});

async function bootstrapAdmin() {
  const username = process.env.ADMIN_USERNAME;
  const password = process.env.ADMIN_PASSWORD;
  if (!username || !password) return;
  if (password.length < 12) {
    throw new Error("ADMIN_PASSWORD deve contenere almeno 12 caratteri");
  }
  const hash = await bcrypt.hash(password, 12);
  await pool.query(
    `INSERT INTO utenti(username,password_hash) VALUES($1,$2)
     ON CONFLICT (username) DO NOTHING`,
    [username, hash],
  );
}

await bootstrapAdmin();
server.listen(PORT, "0.0.0.0", () =>
  console.log(`Lello API attiva sulla porta ${PORT}`),
);

export { app, server, encryptTotpSecret, decryptTotpSecret };
