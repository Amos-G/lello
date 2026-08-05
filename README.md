# Lello

Lello è composta da un'app Flutter e da un'API Node/Express già pubblicata
su:

```text
https://partysync.amosgranata.it
```

L'app Android usa esclusivamente questo backend. La verifica pubblica è:

```bash
curl https://partysync.amosgranata.it/health
```

## App Android

Il backend è fissato in `app/lib/api.dart`:

```dart
const backendUrl = 'https://partysync.amosgranata.it';
```

Build APK:

```bash
./build-apk.sh
```

Il manifest Android disabilita il traffico HTTP in chiaro; l'app deve usare
HTTPS/WSS. La build usa la keystore privata in `release/`; la directory è
ignorata da Git e deve essere conservata in un backup sicuro. Senza quella
stessa chiave non sarà possibile pubblicare aggiornamenti dell'app.

## API

Il backend è mantenuto nel repository per la parte server. In produzione legge
`DATABASE_URL` dall'ambiente e usa PostgreSQL tramite `pg`. Il
`docker-compose.yml` avvia solo l'API, non crea un database locale, e pubblica
la porta esclusivamente su `127.0.0.1` per il reverse proxy.

Sul server crea un `.env` da `.env.example` con tre segreti diversi. Non
conservare il `.env` di produzione nella cartella dell'app o nel repository.
Per un PostgreSQL remoto usa TLS, ad esempio `sslmode=require` oppure,
preferibilmente quando è disponibile la CA, `sslmode=verify-full`.

`TOTP_ENCRYPTION_KEY` cifra i secret 2FA nel database. Non ruotarla senza una
migrazione: perderla rende inutilizzabili i secret 2FA già configurati.

Endpoint principali:

- `GET /health`
- `POST /api/auth/login`
- `POST /api/auth/verify-2fa`
- `GET /api/auth/me`
- `POST /api/auth/2fa/setup`
- `POST /api/auth/2fa/enable`
- `POST /api/auth/2fa/disable`
- `GET|POST /api/elementi`
- `PATCH|DELETE /api/elementi/:id`
- `GET|POST /api/scenari`
- `PATCH|DELETE /api/scenari/:id`
- `POST|DELETE /api/scenari/:id/elementi/:elementoId`
- `GET wss://partysync.amosgranata.it/ws`, seguito dal messaggio
  `{"type":"auth","token":"JWT"}`

Tutte le rotte dati e 2FA richiedono `Authorization: Bearer JWT`.
Login e verifiche 2FA sono protetti da rate limit; i token applicativi durano
24 ore.
