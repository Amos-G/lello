BEGIN;

CREATE TABLE IF NOT EXISTS spese (
  id BIGSERIAL PRIMARY KEY,
  utente_id BIGINT NOT NULL REFERENCES utenti(id) ON DELETE CASCADE,
  descrizione VARCHAR(255) NOT NULL CHECK (btrim(descrizione) <> ''),
  importo_cents INTEGER NOT NULL CHECK (importo_cents > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_spese_utente ON spese (utente_id);
CREATE INDEX IF NOT EXISTS idx_spese_created_at ON spese (created_at DESC, id DESC);

GRANT SELECT, INSERT, DELETE ON TABLE spese TO partysync_api;
GRANT USAGE, SELECT ON SEQUENCE spese_id_seq TO partysync_api;

COMMIT;
