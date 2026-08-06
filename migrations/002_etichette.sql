BEGIN;

CREATE TABLE IF NOT EXISTS impostazioni_app (
  chiave VARCHAR(80) PRIMARY KEY,
  valore VARCHAR(120) NOT NULL CHECK (btrim(valore) <> '')
);

INSERT INTO impostazioni_app(chiave, valore)
VALUES ('etichetta_chi_porta_default', 'Da Assegnare')
ON CONFLICT (chiave) DO NOTHING;

GRANT SELECT, INSERT, UPDATE ON TABLE impostazioni_app TO partysync_api;

COMMIT;
