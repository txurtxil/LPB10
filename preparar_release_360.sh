#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10

mkdir -p ~/Documents/lmb10_scripts
mv -f backup_total.sh diag_cert.sh diag_cert_ident.sh diag_import.sh \
      diag_scripts_cert.sh diag_uso_cert.sh limpiar_historial.sh \
      preparar_filtrado.sh ctx_pack360.sh ctx_pack360b.sh \
      pack_360a.sh pack_360a_files.sh verificar_360.sh probar_360.sh \
      ~/Documents/lmb10_scripts/ 2>/dev/null || true
echo "Scripts movidos fuera del repo"

git add -A
echo; echo "=== Lo que va al commit ==="
git status --short

echo; echo "=== Certs todavia trackeados? (debe salir vacio) ==="
git diff --cached --name-only | grep -iE "certs/app" | sed 's/^/  a borrar: /'
git ls-files | grep -iE "certs/app" || echo "  ninguno queda"
