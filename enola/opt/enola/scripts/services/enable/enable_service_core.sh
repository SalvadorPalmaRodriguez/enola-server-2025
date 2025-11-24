#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
# enable_service_core.sh
set -euo pipefail

log(){ echo -e "[ONION-ENABLE-CORE] $(date '+%F %T') | $*"; }
die(){ echo -e "[ONION-ENABLE-CORE] $(date '+%F %T') | ERROR | $*" >&2; exit 1; }

SERVICE="${1:-}"
[[ -z "$SERVICE" ]] && die "Uso: $0 <nombre_servicio>"

SERVICES_DIR="/etc/tor/enola.d"
TOR_LIB="/var/lib/tor"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

conf_disabled="${SERVICES_DIR}/${SERVICE}.conf.disabled"
conf="${SERVICES_DIR}/${SERVICE}.conf"
hs_disabled="${TOR_LIB}/hidden_service_${SERVICE}.disabled"
hs="${TOR_LIB}/hidden_service_${SERVICE}"
nginx_available="${NGINX_AVAILABLE}/${SERVICE}.conf"
nginx_enabled="${NGINX_ENABLED}/${SERVICE}.conf"

# 1. Restaurar configuración Tor
if [[ -f "$conf_disabled" ]]; then
    log "Restaurando $conf_disabled → $conf"
    sudo mv -f "$conf_disabled" "$conf"
    sudo chmod 640 "$conf"
    sudo chown root:debian-tor "$conf"
else
    log "Advertencia: no existe $conf_disabled"
fi

# 2. Restaurar hidden service
if [[ -d "$hs_disabled" ]]; then
    log "Restaurando directorio Tor $hs_disabled → $hs"
    sudo mv -f "$hs_disabled" "$hs"
    sudo chown -R debian-tor:debian-tor "$hs"
    sudo chmod -R 700 "$hs"
else
    log "No existe directorio oculto: $hs_disabled"
fi

# 3. Habilitar configuración de NGINX
if [[ -f "$nginx_available" ]]; then
    log "Habilitando NGINX: creando symlink $nginx_enabled"
    sudo ln -sf "$nginx_available" "$nginx_enabled"
    
    # Iniciar NGINX si no está activo, o recargar si ya está corriendo
    if systemctl is-active --quiet nginx; then
        sudo systemctl reload nginx || log "⚠️ No se pudo recargar nginx"
    else
        sudo systemctl start nginx || log "⚠️ No se pudo iniciar nginx"
    fi
else
    log "No existe configuración de NGINX en sites-available: $nginx_available"
fi

# 4. Recargar Tor
log "Recargando Tor..."
if ! sudo systemctl reload enola-tor >/dev/null 2>&1; then
    log "Reload falló, intentando restart..."
    sudo systemctl restart enola-tor || die "No se pudo recargar/reiniciar enola-tor"
fi

log "✅ Servicio '$SERVICE' habilitado correctamente."
log "✅ Tor recargado correctamente."
exit 0
