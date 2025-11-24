#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

log() { echo -e "[WORDPRESS] $(date '+%F %T') | $*"; }
die() { echo -e "[WORDPRESS] $(date '+%F %T') | ERROR | $*" >&2; exit 1; }

# Directorios
ENV_DIR="/opt/enola/wordpress"
SERVICES_DIR="/etc/tor/enola.d"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"

# Función para seleccionar servicio WordPress
pick_service() {
    local services=()
    shopt -s nullglob
    for f in "$ENV_DIR"/*.env; do
        [ -f "$f" ] || continue
        local svc_name=$(basename "$f" .env)
        
        # VALIDACIONES: solo mostrar si está realmente habilitado
        # 1. Debe tener .conf activo (configuración Tor habilitada)
        [ ! -f "$SERVICES_DIR/${svc_name}.conf" ] && continue
        
        # 2. No debe tener solo .conf.disabled
        [ ! -f "$SERVICES_DIR/${svc_name}.conf" ] && [ -f "$SERVICES_DIR/${svc_name}.conf.disabled" ] && continue
        
        # 3. Al menos un contenedor debe estar corriendo O systemd debe estar enabled
        local wp_container="enola-${svc_name}-wp"
        local db_container="enola-${svc_name}-mysql"
        local has_running_container=false
        local has_enabled_service=false
        
        if podman ps --format '{{.Names}}' 2>/dev/null | grep -qE "^${wp_container}$|^${db_container}$"; then
            has_running_container=true
        fi
        
        if systemctl is-enabled "container-${wp_container}.service" 2>/dev/null | grep -q "enabled"; then
            has_enabled_service=true
        fi
        
        # Si no está corriendo Y no está enabled, no mostrarlo (ya está deshabilitado de facto)
        [ "$has_running_container" = false ] && [ "$has_enabled_service" = false ] && continue
        
        services+=("$svc_name")
    done
    shopt -u nullglob
    
    [ ${#services[@]} -eq 0 ] && die "No hay servicios WordPress habilitados para deshabilitar"
    
    # Usar fzf si está disponible
    if command -v fzf >/dev/null 2>&1; then
        echo "" >&2
        echo "📋 Selecciona el servicio WordPress a deshabilitar:" >&2
        local selected
        selected=$(printf "%s\n" "${services[@]}" | fzf --height=40% --reverse --prompt="Deshabilitar ❯ " --header="Usa ↑↓ para navegar, Enter para seleccionar") || exit 0
        if [ -z "$selected" ]; then
            exit 0
        fi
        echo "$selected"
    else
        # Fallback a menú numerado
        echo "Servicios WordPress habilitados:" >&2
        local i=1
        for svc in "${services[@]}"; do
            echo "$i) $svc" >&2
            ((i++))
        done
        
        local choice
        read -p "Selecciona el número del servicio a deshabilitar: " choice
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#services[@]} ]; then
            die "Selección inválida"
        fi
        
        echo "${services[$((choice-1))]}"
    fi
}

# Seleccionar servicio
SERVICE_NAME=$(pick_service)

WP_CONTAINER="enola-${SERVICE_NAME}-wp"
DB_CONTAINER="enola-${SERVICE_NAME}-mysql"

log "Deshabilitando servicio WordPress: $SERVICE_NAME"

# 1. Deshabilitar configuración de Tor (renombrar para que no sea activa)
if [ -f "$SERVICES_DIR/${SERVICE_NAME}.conf" ]; then
    log "Deshabilitando servicio Tor..."
    sudo mv "$SERVICES_DIR/${SERVICE_NAME}.conf" "$SERVICES_DIR/${SERVICE_NAME}.conf.disabled"
    sudo systemctl reload enola-tor || log "⚠️ No se pudo recargar enola-tor"
else
    log "Configuración de Tor no encontrada o ya estaba deshabilitada"
fi

# 2. Deshabilitar configuración de NGINX (eliminar symlink de sites-enabled)
if [ -L "$NGINX_ENABLED_DIR/${SERVICE_NAME}.conf" ] || [ -f "$NGINX_ENABLED_DIR/${SERVICE_NAME}.conf" ]; then
    log "Deshabilitando servicio NGINX..."
    sudo rm -f "$NGINX_ENABLED_DIR/${SERVICE_NAME}.conf"
    
    # Solo recargar si NGINX está activo
    if systemctl is-active --quiet nginx; then
        sudo systemctl reload nginx || log "⚠️ No se pudo recargar nginx"
    fi
else
    log "Configuración de NGINX no encontrada o ya estaba deshabilitada"
fi

# 3. Detener y deshabilitar servicios de systemd
log "Deteniendo servicios de systemd..."
sudo systemctl stop "container-${WP_CONTAINER}.service" 2>/dev/null || log "Servicio WordPress no estaba activo"
sudo systemctl stop "container-${DB_CONTAINER}.service" 2>/dev/null || log "Servicio MySQL no estaba activo"

log "Deshabilitando servicios de systemd..."
sudo systemctl disable "container-${WP_CONTAINER}.service" 2>/dev/null || log "Servicio WordPress no estaba habilitado"
sudo systemctl disable "container-${DB_CONTAINER}.service" 2>/dev/null || log "Servicio MySQL no estaba habilitado"

# 4. Detener contenedores (pero no eliminar)
log "Deteniendo contenedores..."
podman stop "$WP_CONTAINER" 2>/dev/null || log "Contenedor WordPress no estaba corriendo"
podman stop "$DB_CONTAINER" 2>/dev/null || log "Contenedor MySQL no estaba corriendo"

log "✅ WordPress '$SERVICE_NAME' deshabilitado correctamente."
log "El servicio NO es accesible desde Tor Browser."
log "Los contenedores, archivos y configuraciones se mantienen."
log "Para reactivar, usa la opción 'Habilitar servicio' del menú."
