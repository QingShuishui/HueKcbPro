# Backend

## Start

```bash
python3 app.py
```

The server listens on `http://0.0.0.0:8000` by default.

## API

### Get latest Android update metadata

```bash
curl http://127.0.0.1:8000/api/update/android
```

If no APK has been uploaded yet, the server returns `404` with:

```json
{"error":"no_release"}
```

### Upload a new APK

```bash
curl -X POST http://127.0.0.1:8000/api/admin/upload \
  -F "file=@/absolute/path/to/app-release.apk" \
  -F "version=1.0.1" \
  -F "build_number=2" \
  -F "force_update=false" \
  -F "notes=Bug fixes and refresh improvements"
```

The server stores the APK in `downloads/`, computes its SHA-256 hash, and rewrites `storage/latest-android.json`.

## Notes

- This is intentionally minimal and has no authentication.
- Deploy it only in a trusted environment or add authentication before exposing it publicly.
