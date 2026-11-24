#!/usr/bin/env bash
# Vercel build: installs Flutter, builds the web app into app/build/web.
# Without SUPABASE_URL and SUPABASE_ANON_KEY the app runs on built-in sample data.
set -euo pipefail
FLUTTER_VERSION="${FLUTTER_VERSION:-3.50.1}"
if [ ! -x "$HOME/flutter/bin/flutter" ]; then
  curl -sSL -o /tmp/flutter.tar.xz "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar -xJf /tmp/flutter.tar.xz -C "$HOME"
fi
export PATH="$HOME/flutter/bin:$PATH"
git config --global --add safe.directory '*'
flutter config --no-analytics --enable-web >/dev/null
cd app
flutter pub get
DEFINES=()
if [ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_ANON_KEY:-}" ]; then
  DEFINES+=(--dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY")
fi
flutter build web --release "${DEFINES[@]}"
rm -rf build/web/canvaskit   # loaded from Google's CDN at runtime
