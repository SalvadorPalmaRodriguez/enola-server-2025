#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
# enable_service_multi.sh
set -euo pipefail

CORE_SCRIPT="$(dirname "$0")/enable_service_core.sh"
[[ -x "$CORE_SCRIPT" ]] || { echo "❌ Falta $CORE_SCRIPT"; exit 1; }

SERVICES_DIR="/etc/tor/enola.d"

# Buscar servicios deshabilitados
services=()
shopt -s nullglob
for f in "${SERVICES_DIR}"/*.conf.disabled; do
    [ -f "$f" ] || continue
    services+=("$(basename "$f" .conf.disabled)")
done
shopt -u nullglob

[[ ${#services[@]} -gt 0 ]] || { echo "No hay servicios deshabilitados."; exit 0; }

echo "Selecciona uno o varios servicios para habilitar:"
SELECTED=$(printf "%s\n" "${services[@]}" | fzf --multi --prompt="✅ Habilitar > ") || exit 0
[[ -z "$SELECTED" ]] && exit 0

echo "Vas a habilitar:"
echo "$SELECTED" | sed 's/^/  - /'
read -rp "¿Confirmar? (y/N): " CONF
[[ "${CONF,,}" != "y" ]] && { echo "Cancelado."; exit 0; }

for svc in $SELECTED; do
    sudo "$CORE_SCRIPT" "$svc"
done

echo "✅ Todos los servicios seleccionados fueron habilitados."
echo "Recargando Tor..."
if ! sudo systemctl reload enola-tor >/dev/null 2>&1; then
    echo "Reload falló, intentando restart..."
    sudo systemctl restart enola-tor || { echo "❌ No se pudo recargar/reiniciar enola-tor"; exit 1; }
fi
echo "✅ Tor recargado correctamente."