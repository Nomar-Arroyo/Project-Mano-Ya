#!/bin/sh
set -e

flutter build web --release --base-href=/ \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
  --dart-define=GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}" \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}" \
  --dart-define=WEB_APP_URL="${WEB_APP_URL:-}" \
  --dart-define=PAYMENTS_DEMO=true
