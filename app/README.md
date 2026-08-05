# Lello Android

L'app usa esclusivamente:

```text
https://partysync.amosgranata.it
```

Il valore è fissato in `lib/api.dart`; non usare `--dart-define=BACKEND_URL`.

Build release:

```bash
../build-apk.sh
```

La build release non usa mai la chiave debug. Usa la keystore privata nella
directory `../release`, esclusa da Git e da conservare in un backup sicuro.

Per le prove locali:

```bash
../.toolchains/flutter/bin/flutter run -d chrome --web-port 5173
```

Il backend deve includere `http://localhost:5173` nella lista separata da
virgole di `CORS_ORIGIN` soltanto durante lo sviluppo web.
