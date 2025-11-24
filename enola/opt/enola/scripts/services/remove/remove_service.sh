#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
# remove_service.sh
set -euo pipefail

# ============================
# Eliminar un servicio Onion + WordPress
# ============================

log() { echo -e "[ONION-REMOVE] $(date '+%F %T') | $*"; }
die() { echo -e "[ONION-REMOVE] $(date '+%F %T') | ERROR | $*" >&2; exit 1; }

SERVICES_DIR="/etc/tor/enola.d"
WP_ENV_DIR="/opt/enola/wordpress"

# ----------------------------
# 1. Verificar dependencia fzf
# ----------------------------
if ! command -v fzf >/dev/null 2>&1; then
    die "fzf no está instalado. Instálalo con: sudo apt install fzf"
fi

# ----------------------------
# 2. Detectar servicios existentes
# ----------------------------
services=()

# Buscar por conf de Tor
for conf in "$SERVICES_DIR"/*.conf; do
    [[ -f "$conf" ]] || continue
    name=$(basename "$conf" .conf)
    services+=("$name")
done

# Buscar por env de WP (por si hay alguno sin conf de Tor)
for env in "$WP_ENV_DIR"/*.env; do
    [[ -f "$env" ]] || continue
    name=$(basename "$env" .env)
    [[ " ${services[*]} " == *" $name "* ]] || services+=("$name")
done

[[ ${#services[@]} -eq 0 ]] && die "No se encontraron servicios para eliminar."

# ----------------------------
# 3. Menú interactivo con fzf
# ----------------------------
SERVICE=$(printf "%s\n" "${services[@]}" | fzf --prompt="👉 Selecciona servicio a eliminar: ") || exit 0

[[ -z "$SERVICE" ]] && exit 0

# ----------------------------
# 4. Confirmación
# ----------------------------
read -rp "⚠️ ¿Seguro que deseas eliminar el servicio '$SERVICE'? (y/N): " confirm
[[ "${confirm,,}" != "y" ]] && die "Operación cancelada."

# ----------------------------
# 5. Ejecutar script de borrado real
# ----------------------------
"$(dirname "$0")/remove_service_core.sh" "$SERVICE"


# 8. Listar servicios restantes
/opt/enola/scripts/tor/list_services.sh
# --------------------------------------------------------------------