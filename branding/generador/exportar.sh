#!/usr/bin/env bash
# Regenera TODO el logo: SVG (branding/logo), PNG (branding/logo/png) y los
# archivos que usa la web (public/). Correr desde la raíz del repo, en Git Bash:
#   bash branding/generador/exportar.sh
# Necesita Python con fonttools y Microsoft Edge (lo usa para pasar SVG a PNG).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
L="$ROOT/branding/logo"
P="$ROOT/public"
EDGE="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"

python "$ROOT/branding/generador/final_logo.py" "$L"
python "$ROOT/branding/generador/assets_web.py" "$P/brand"
mkdir -p "$L/png"

# render <svg> <png de salida> <ancho> <alto> <transparente: 1/0>
render() {
  local dir; dir="$(cd "$(dirname "$2")" && pwd -W)"
  cp "$1" "$dir/_tmp.svg"
  printf '<!doctype html><style>html,body{margin:0;background:transparent}img{display:block;width:%spx;height:%spx}</style><img src="_tmp.svg">' "$3" "$4" > "$dir/_tmp.html"
  local bg=""; [ "$5" = 1 ] && bg="--default-background-color=00000000"
  timeout 60 "$EDGE" --headless=new --disable-gpu --hide-scrollbars $bg --window-size="$3,$4" \
    --screenshot="$dir/$(basename "$2")" "file:///$dir/_tmp.html" >/dev/null 2>&1 || echo "Falló: $2"
  rm -f "$dir/_tmp.svg" "$dir/_tmp.html"
}
size() { grep -o 'viewBox="0 0 [0-9.]* [0-9.]*"' "$1" | head -1 | tr -d '"' | awk '{printf "%d %d\n", $3, $4}'; }

# Todas las versiones, al triple de tamaño
for f in "$L"/asiste-*.svg; do
  case "$(basename "$f")" in asiste-app-icon*) continue ;; esac
  read -r W H < <(size "$f")
  render "$f" "$L/png/$(basename "${f%.svg}").png" $((W * 3)) $((H * 3)) 1
done
for s in 1024 512 192 180; do render "$L/asiste-app-icon.svg" "$L/png/app-icon-$s.png" $s $s 1; done
render "$L/asiste-app-icon-claro.svg" "$L/png/app-icon-claro-1024.png" 1024 1024 1
for s in 1024 512 192 180; do render "$L/asiste-app-icon-cuadrado.svg" "$L/png/app-icon-cuadrado-$s.png" $s $s 0; done
# Edge no saca capturas tan chicas: se renderiza grande y se achica con Pillow
# (pip install pillow). De paso arma el .ico con 16, 32 y 48.
render "$L/favicon.svg" "$L/png/favicon-512.png" 512 512 1
python - "$L/png" <<'PY'
import sys
from PIL import Image
d = sys.argv[1]
big = Image.open(f'{d}/favicon-512.png').convert('RGBA')
for s in (16, 32, 48):
    big.resize((s, s), Image.LANCZOS).save(f'{d}/favicon-{s}.png')
big.save(f'{d}/favicon.ico', sizes=[(16, 16), (32, 32), (48, 48)])
PY

# Lo que usa la web
cp "$L/favicon.svg" "$P/favicon.svg"
cp "$L/png/favicon-32.png" "$P/favicon-32.png"
cp "$L/png/favicon.ico" "$P/favicon.ico"
cp "$L/png/app-icon-cuadrado-180.png" "$P/apple-touch-icon.png"   # iPhone redondea solo
cp "$L/png/app-icon-192.png" "$P/icon-192.png"
cp "$L/png/app-icon-512.png" "$P/icon-512.png"
cp "$L/png/app-icon-cuadrado-512.png" "$P/icon-512-maskable.png"
render "$P/brand/og-asiste.svg" "$P/brand/og-asiste.png" 1200 630 0
rm -f "$P/brand/og-asiste.svg"
read -r W H < <(size "$L/asiste-horizontal-violeta.svg")
render "$L/asiste-horizontal-violeta.svg" "$P/brand/asiste-logo.png" $((W * 120 / H)) 120 1   # logo de los mails

echo "Listo."
