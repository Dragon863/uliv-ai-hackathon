# Meadow House Repairs

Flutter app for reporting and tracking Meadow House repairs. Job data lives in the Python server's JSON file and is shared by connected app instances. The app needs the server URL at runtime; it does not silently save jobs on the device.

## Start the Python backend

The backend uses only Python's standard library (Python 3.10+):

```sh
python3 backend/server.py
```

It listens on port `8000` and stores data in `backend/data/jobs.json`. Override the port or data path with `PORT` and `MEADOW_DATA_FILE`. To enable a shared bearer token, configure `MEADOW_API_TOKEN` on the server and pass the same value to Flutter:

```sh
MEADOW_API_TOKEN='choose-a-private-token' python3 backend/server.py
```

Set the token when the server can be reached outside your own computer. Put the JSON file on persistent storage when hosting in a container or platform whose local disk is temporary.

The API provides `GET /api/jobs`, `PUT /api/jobs`, and `GET /health`. Browser access is enabled with CORS.

## Configure and run Flutter

Flutter stable **3.47.0** (Dart **3.13.5**). Confirm the SDK with `flutter --version`.

Pass the backend origin (scheme, host, and optional port, without `/api/jobs`) to the app:

```sh
# Chrome on the same computer
flutter run -d chrome --dart-define=MEADOW_API_URL=http://127.0.0.1:8000

# Android emulator (the emulator reaches the host computer through 10.0.2.2)
flutter run -d <android-device-id> --dart-define=MEADOW_API_URL=http://10.0.2.2:8000
```

For a physical Android device, use the computer's LAN address, such as `http://192.168.1.20:8000`, and allow port 8000 through its firewall. If token authentication is enabled, add `--dart-define=MEADOW_API_TOKEN=choose-a-private-token` to the Flutter command.

To build Android yourself:

```sh
flutter pub get
flutter build apk --release --dart-define=MEADOW_API_URL=https://your-host.example
```

Add the token define if configured. Use HTTPS when the server is reachable over the public internet. A token compiled into a client app is visible to its users, so use it only for a private demo service.

For web, build with the repository subpath before publishing to GitHub Pages:

```sh
flutter build web --release --base-href /repo-name/ --dart-define=MEADOW_API_URL=https://your-host.example
```

## Features

- Create Normal or Urgent repair reports with field-level validation.
- Start a job, append progress notes, and complete it with a required note.
- Browse append-only, timestamped history for every job.
- Store and share the ID sequence and jobs through the Python backend.
- Responsive web and Android layouts, local refresh, Material 3, and light/dark themes.
