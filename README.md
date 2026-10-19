# Meadow House Repairs
## Overview

Visit [https://repairs.danieldb.uk](https://repairs.danieldb.uk) to see the live app!

Flutter app for reporting and tracking repairs at Meadow House. The app reads and writes jobs through the Python API; it does not keep an offline copy on the device. The API used by the current app source is `https://hack.danieldb.uk` (configured in `lib/ui/app.dart`). It is hosted in a docker container on a Proxmox VM so that it can easily be deployed anywhere and backed up with snapshots

## Run the app

Flutter stable **3.47.7** (Dart **3.13.5**). Check your installation with `flutter --version`.

```sh
flutter pub get
flutter run -d chrome
```

For Android, use Android Studio or list connected targets with `flutter devices`, then run:

```sh
flutter run -d <android-device-id>
```

The current API URL is compiled into the app source. If you deploy the API at a different address, update the `apiUrl` constant in `lib/ui/app.dart` before running or building. The optional `MEADOW_API_TOKEN` is read as a Dart compile-time define; pass `--dart-define=MEADOW_API_TOKEN=...` to `flutter run` or `flutter build` when the server requires a bearer token. A token embedded in a client app can be extracted, so use it only for a private demo.

## Backend

The Python 3.10+ API uses only the standard library. It provides `GET /api/jobs`, `PUT /api/jobs`, and `GET /health`; browser requests are enabled with CORS.

To run directly, from the repository root:

```sh
python3 backend/server.py
```

The direct server listens on port `8001` by default and stores jobs at `backend/data/jobs.json`. Set `PORT` or `MEADOW_DATA_FILE` to override these values. For example:

```sh
PORT=8000 MEADOW_DATA_FILE=backend/data/jobs.json python3 backend/server.py
```

To run the containerized backend:

```sh
docker compose -f backend/compose.yml up -d --build
```

Compose publishes port `8000` by default (`MEADOW_PORT` changes the host port) and stores data in the persistent `meadow-data` Docker volume. To require a bearer token, set `MEADOW_API_TOKEN` in the environment before starting the service; provide the same token to the Flutter app with the compile-time define above. Without a token, the API does not authenticate writes. Keep the server and its data volume backed up.

## Build

```sh
flutter build web
flutter build apk --release
```

The web build can be served from the site root. For GitHub Pages or another subpath, set the matching base href, for example `--base-href /repo-name/`. Use HTTPS for a publicly reachable API.

## Features

- Create Normal or Urgent repair reports with required-field validation.
- Start work, append progress notes, and complete a job with a required completion note.
- View each job's timestamped, append-only history.
- Share jobs and the ID sequence through the Python API.
- Responsive web and Android layouts, refresh action, Material 3, and light and dark themes.
