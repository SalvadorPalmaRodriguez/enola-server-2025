#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
# enable_service.sh
set -euo pipefail

log(){ echo -e "[ONION-ENABLE] $(date '+%F %T') | $*"; }
die(){ echo -e "[ONION-ENABLE] $(date '+%F %T') | ERROR | $*" >&2; exit 1; }

SERVICES_DIR="/etc/tor/enola.d"

command -v fzf >/dev/null 2>&1 || die "fzf no está instalado. Instálalo con: sudo apt install fzf"

# Buscar servicios deshabilitados
services=()
shopt -s nullglob
for f in "${SERVICES_DIR}"/*.conf.disabled; do
    [ -f "$f" ] || continue
    services+=("$(basename "$f" .conf.disabled)")
done
shopt -u nullglob

[[ ${#services[@]} -gt 0 ]] || die "No se encontraron servicios deshabilitados para habilitar."

SERVICE=$(printf "%s\n" "${services[@]}" | fzf --prompt="✅ Selecciona servicio a habilitar: ") || exit 0
[[ -z "$SERVICE" ]] && exit 0

read -rp "¿Seguro que deseas habilitar '$SERVICE'? (y/N): " CONF
[[ "${CONF,,}" != "y" ]] && die "Cancelado."

"$(dirname "$0")/enable_service_core.sh" "$SERVICE"
