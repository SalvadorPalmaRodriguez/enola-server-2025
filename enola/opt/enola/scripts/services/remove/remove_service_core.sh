#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
# remove_service_core.sh
set -euo pipefail

# ============================
# Núcleo de borrado de servicios Onion / WordPress
# ============================

log() { echo -e "[ONION-REMOVE-CORE] $(date '+%F %T') | $*"; }
die() { echo -e "[ONION-REMOVE-CORE] $(date '+%F %T') | ERROR | $*" >&2; exit 1; }

SERVICE="${1:-}"

[[ -z "$SERVICE" ]] && die "Debes pasar el nombre del servicio. Uso: $0 <nombre_servicio>"

# Directorios
SERVICES_DIR="/etc/tor/enola.d"
HIDDEN_DIR="/var/lib/tor/hidden_service_${SERVICE}"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
NGINX_AVAILABLE_DIR="/etc/nginx/sites-available"
WP_ENV_DIR="/opt/enola/wordpress"

# ----------------------------
# 1. Eliminar configuración de Tor
# ----------------------------
if [[ -f "$SERVICES_DIR/${SERVICE}.conf" || -f "$SERVICES_DIR/${SERVICE}.conf.disabled" || -f "$SERVICES_DIR/disabled/${SERVICE}.conf" ]]; then
    log "Eliminando configuración de Tor: $SERVICES_DIR/${SERVICE}.conf"
    sudo rm -f "$SERVICES_DIR/${SERVICE}.conf" "$SERVICES_DIR/${SERVICE}.conf.disabled" "$SERVICES_DIR/disabled/${SERVICE}.conf" 2>/dev/null || true
    sudo rm -rf "$HIDDEN_DIR"
    # Recargar enola-tor (no el tor del sistema)
    if ! sudo systemctl reload enola-tor >/dev/null 2>&1; then
        log "Reload falló, intentando restart enola-tor..."
        sudo systemctl restart enola-tor || log "⚠️ No se pudo recargar/reiniciar enola-tor"
    fi
fi

# ----------------------------
# 2. Eliminar configuración de Nginx
# ----------------------------
removed_nginx=false
if [[ -L "$NGINX_ENABLED_DIR/${SERVICE}.conf" || -f "$NGINX_ENABLED_DIR/${SERVICE}.conf" ]]; then
    log "Eliminando sites-enabled: $NGINX_ENABLED_DIR/${SERVICE}.conf"
    sudo rm -f "$NGINX_ENABLED_DIR/${SERVICE}.conf"
    removed_nginx=true
fi
if [[ -f "$NGINX_AVAILABLE_DIR/${SERVICE}.conf" ]]; then
    log "Eliminando sites-available: $NGINX_AVAILABLE_DIR/${SERVICE}.conf"
    sudo rm -f "$NGINX_AVAILABLE_DIR/${SERVICE}.conf"
    removed_nginx=true
fi

if [[ "$removed_nginx" = true ]]; then
    # Solo recargar si NGINX está activo
    if systemctl is-active --quiet nginx; then
        sudo systemctl reload nginx || log "⚠️ No se pudo recargar Nginx"
    fi
fi

# ----------------------------
# 3. Eliminar contenedores y red (si es WordPress)
# ----------------------------
if [[ -f "$WP_ENV_DIR/${SERVICE}.env" ]]; then
    log "Detectado servicio WordPress, eliminando contenedores..."
    
    WP_CONTAINER="enola-${SERVICE}-wp"
    DB_CONTAINER="enola-${SERVICE}-mysql"
    
    # Detener y deshabilitar servicios de systemd
    log "Deteniendo y deshabilitando servicios de systemd..."
    sudo systemctl stop "container-${WP_CONTAINER}.service" 2>/dev/null || true
    sudo systemctl stop "container-${DB_CONTAINER}.service" 2>/dev/null || true
    sudo systemctl disable "container-${WP_CONTAINER}.service" 2>/dev/null || true
    sudo systemctl disable "container-${DB_CONTAINER}.service" 2>/dev/null || true
    
    # Eliminar archivos de servicios de systemd
    sudo rm -f "/etc/systemd/system/container-${WP_CONTAINER}.service"
    sudo rm -f "/etc/systemd/system/container-${DB_CONTAINER}.service"
    sudo systemctl daemon-reload
    
    # Eliminar contenedores (forzar stop antes de rm)
    log "Eliminando contenedores..."
    sudo podman stop "$WP_CONTAINER" 2>/dev/null || true
    sudo podman stop "$DB_CONTAINER" 2>/dev/null || true
    sudo podman rm -f "$WP_CONTAINER" 2>/dev/null || true
    sudo podman rm -f "$DB_CONTAINER" 2>/dev/null || true
    
    # Eliminar red de Podman
    sudo podman network rm "enola_net_${SERVICE}" 2>/dev/null || true
    
    # Eliminar datos de WordPress
    sudo rm -rf "/var/lib/enola-wordpress/${SERVICE}" 2>/dev/null || true
    
    # Eliminar certificados SSL
    sudo rm -rf "/etc/enola-server/ssl/${SERVICE}" 2>/dev/null || true
    
    # Eliminar logs
    sudo rm -rf "/var/log/enola-server/${SERVICE}" 2>/dev/null || true
    
    log "Eliminando archivo env: $WP_ENV_DIR/${SERVICE}.env"
    sudo rm -f "$WP_ENV_DIR/${SERVICE}.env"
fi
sudo systemctl reset-failed
# ----------------------------
# 4. Resultado final
# ----------------------------
log "✅ Servicio '$SERVICE' eliminado correctamente."
