BEGIN;

CREATE TABLE IF NOT EXISTS utenti (
  id BIGSERIAL PRIMARY KEY,
  username VARCHAR(80) NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  totp_secret TEXT,
  totp_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT utenti_totp_coerente CHECK (NOT totp_enabled OR totp_secret IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS elementi (
  id BIGSERIAL PRIMARY KEY,
  nome VARCHAR(255) NOT NULL CHECK (btrim(nome) <> ''),
  chi_porta VARCHAR(120) NOT NULL DEFAULT 'Da Assegnare'
    CHECK (btrim(chi_porta) <> ''),
  completato BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS impostazioni_app (
  chiave VARCHAR(80) PRIMARY KEY,
  valore VARCHAR(120) NOT NULL CHECK (btrim(valore) <> '')
);

INSERT INTO impostazioni_app(chiave, valore)
VALUES ('etichetta_chi_porta_default', 'Da Assegnare')
ON CONFLICT (chiave) DO NOTHING;

CREATE TABLE IF NOT EXISTS scenari (
  id BIGSERIAL PRIMARY KEY,
  titolo VARCHAR(255) NOT NULL CHECK (btrim(titolo) <> ''),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS scenario_elementi (
  scenario_id BIGINT NOT NULL REFERENCES scenari(id) ON DELETE CASCADE,
  elemento_id BIGINT NOT NULL REFERENCES elementi(id) ON DELETE CASCADE,
  PRIMARY KEY (scenario_id, elemento_id)
);

CREATE TABLE IF NOT EXISTS spese (
  id BIGSERIAL PRIMARY KEY,
  utente_id BIGINT NOT NULL REFERENCES utenti(id) ON DELETE CASCADE,
  descrizione VARCHAR(255) NOT NULL CHECK (btrim(descrizione) <> ''),
  importo_cents INTEGER NOT NULL CHECK (importo_cents > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_elementi_chi_porta ON elementi (chi_porta);
CREATE INDEX IF NOT EXISTS idx_scenario_elementi_elemento
  ON scenario_elementi (elemento_id);
CREATE INDEX IF NOT EXISTS idx_spese_utente ON spese (utente_id);
CREATE INDEX IF NOT EXISTS idx_spese_created_at ON spese (created_at DESC, id DESC);

COMMIT;
