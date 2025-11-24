#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
# disable_service_core.sh
set -euo pipefail

log(){ echo -e "[ONION-DISABLE-CORE] $(date '+%F %T') | $*"; }
die(){ echo -e "[ONION-DISABLE-CORE] $(date '+%F %T') | ERROR | $*" >&2; exit 1; }

SERVICE="${1:-}"
[[ -z "$SERVICE" ]] && die "Uso: $0 <nombre_servicio>"

SERVICES_DIR="/etc/tor/enola.d"
TOR_LIB="/var/lib/tor"
NGINX_ENABLED="/etc/nginx/sites-enabled"

conf="${SERVICES_DIR}/${SERVICE}.conf"
conf_disabled="${conf}.disabled"
hs="${TOR_LIB}/hidden_service_${SERVICE}"
hs_disabled="${hs}.disabled"
nginx_enabled="${NGINX_ENABLED}/${SERVICE}.conf"

# 1. Deshabilitar configuración de Tor
if [[ -f "$conf" ]]; then
    log "Moviendo $conf → $conf_disabled"
    sudo mv -f "$conf" "$conf_disabled"
    sudo chmod 640 "$conf_disabled"
    sudo chown root:debian-tor "$conf_disabled"
else
    log "Advertencia: no existe $conf"
fi

# 2. Deshabilitar directorio hidden service de Tor
if [[ -d "$hs" ]]; then
    log "Moviendo $hs → $hs_disabled"
    sudo mv -f "$hs" "$hs_disabled"
    sudo chown -R root:root "$hs_disabled"
    sudo chmod -R 700 "$hs_disabled"
else
    log "No existe directorio de servicio oculto: $hs"
fi

# 3. Deshabilitar configuración de NGINX
if [[ -L "$nginx_enabled" || -f "$nginx_enabled" ]]; then
    log "Deshabilitando NGINX: eliminando $nginx_enabled"
    sudo rm -f "$nginx_enabled"
    
    # Solo recargar si NGINX está activo
    if systemctl is-active --quiet nginx; then
        sudo systemctl reload nginx || log "⚠️ No se pudo recargar nginx"
    fi
else
    log "NGINX ya estaba deshabilitado o no existe: $nginx_enabled"
fi

# 4. Recargar Tor
log "Recargando Tor..."
if ! sudo systemctl reload enola-tor >/dev/null 2>&1; then
    log "Reload falló, intentando restart..."
    sudo systemctl restart enola-tor || die "No se pudo recargar/reiniciar enola-tor"
fi

log "✅ Servicio '$SERVICE' deshabilitado correctamente."
exit 0 
