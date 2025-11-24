#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
# disable_service.sh
set -euo pipefail

log(){ echo -e "[ONION-DISABLE] $(date '+%F %T') | $*"; }
die(){ echo -e "[ONION-DISABLE] $(date '+%F %T') | ERROR | $*" >&2; exit 1; }

SERVICES_DIR="/etc/tor/enola.d"

command -v fzf >/dev/null 2>&1 || die "fzf no está instalado. Instálalo con: sudo apt install fzf"

# Buscar servicios habilitados (excluir .disabled)
services=()
shopt -s nullglob
for f in "${SERVICES_DIR}"/*.conf; do
    [ -f "$f" ] || continue
    [[ "$f" == *.disabled ]] && continue
    services+=("$(basename "$f" .conf)")
done
shopt -u nullglob

[[ ${#services[@]} -gt 0 ]] || die "No se encontraron servicios habilitados para deshabilitar."

SERVICE=$(printf "%s\n" "${services[@]}" | fzf --prompt="🛑 Selecciona servicio a deshabilitar: ") || exit 0
[[ -z "$SERVICE" ]] && exit 0

read -rp "¿Seguro que deseas deshabilitar '$SERVICE'? (y/N): " CONF
[[ "${CONF,,}" != "y" ]] && die "Cancelado."

"$(dirname "$0")/disable_service_core.sh" "$SERVICE"

    