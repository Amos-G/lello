# Lello / PartySync frontend

Questo repository contiene esclusivamente il client Flutter Android/Web di
PartySync. Il backend attivo è mantenuto separatamente in `partysync-api` e il
database PostgreSQL condiviso in `postgres-shared`.

L'app usa l'API pubblica:

```text
https://partysync.amosgranata.it
```

Il valore è definito in `app/lib/api.dart`. Tutte le risorse applicative sono
legate alla lista selezionata; il relativo ID viene conservato nel secure
storage. La lista privata sul dispositivo mantiene le chiavi storiche
`private:<account>:assignee`, `private:<account>:items` e
`private:<account>:completed`.

## Sviluppo

```bash
cd app
flutter pub get
flutter run -d chrome --web-port 5173
```

Per lo sviluppo web il backend deve autorizzare temporaneamente
`http://localhost:5173` tramite `CORS_ORIGIN`.

## Verifiche

```bash
cd app
dart format lib test
flutter analyze
flutter test
```

## Build Android

```bash
./build-apk.sh
```

La build release usa la keystore privata in `release/`, esclusa da Git. La
stessa chiave e lo stesso `applicationId` devono essere conservati per poter
pubblicare aggiornamenti dell'app esistente.
