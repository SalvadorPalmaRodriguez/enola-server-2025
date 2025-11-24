#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
# remove_service_multi.sh
# Script para eliminar múltiples servicios Onion a la vez usando fzf (multi-select)

set -euo pipefail

CORE_SCRIPT="$(dirname "$0")/remove_service_core.sh"

if [[ ! -x "$CORE_SCRIPT" ]]; then
    echo "❌ Error: no se encuentra $CORE_SCRIPT"
    exit 1
fi

# Buscar todos los servicios activos (basados en archivos de configuración Tor)
services=()
shopt -s nullglob
for f in /etc/tor/enola.d/*.conf /etc/tor/enola.d/*.conf.disabled; do
    [ -f "$f" ] || continue
    local_name=$(basename "$f")
    local_name=${local_name%.conf.disabled}
    local_name=${local_name%.conf}
    services+=("$local_name")
done
shopt -u nullglob

if [[ ${#services[@]} -eq 0 ]]; then
    echo "ℹ️ No hay servicios Onion configurados."
    exit 0
fi

echo "📋 Selecciona uno o varios servicios para eliminar (TAB para marcar, ENTER para confirmar):"
SELECTED=$(printf "%s\n" "${services[@]}" | sort -u | fzf --multi --prompt="🗑️  Servicios > ") || exit 0

if [[ -z "$SELECTED" ]]; then
    exit 0
fi

echo "⚠️ Vas a eliminar los siguientes servicios:"
echo "$SELECTED" | sed 's/^/   - /'

read -p "¿Seguro? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "❌ Cancelado."
    exit 0
fi

for SERVICE in $SELECTED; do
    echo "🚮 Eliminando servicio: $SERVICE ..."
    sudo "$CORE_SCRIPT" "$SERVICE"
done

echo "✅ Todos los servicios seleccionados han sido eliminados."

# Mostrar lista actualizada
/opt/enola/scripts/tor/list_services.sh || true