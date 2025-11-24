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
NGINX_AVAILABLE_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"

# Función para seleccionar servicio WordPress deshabilitado
pick_service() {
    local services=()
    shopt -s nullglob
    for f in "$ENV_DIR"/*.env; do
        [ -f "$f" ] || continue
        local svc_name=$(basename "$f" .env)
        
        # VALIDACIONES: solo mostrar si está realmente deshabilitado
        # 1. Debe tener .conf.disabled (configuración Tor deshabilitada)
        [ ! -f "$SERVICES_DIR/${svc_name}.conf.disabled" ] && continue
        
        # 2. No debe tener .conf activo
        [ -f "$SERVICES_DIR/${svc_name}.conf" ] && continue
        
        # 3. Contenedores deben estar detenidos
        local wp_container="enola-${svc_name}-wp"
        local db_container="enola-${svc_name}-mysql"
        if podman ps --format '{{.Names}}' 2>/dev/null | grep -qE "^${wp_container}$|^${db_container}$"; then
            continue  # Algún contenedor está corriendo, no es válido
        fi
        
        # 4. Servicios systemd deben estar disabled
        if systemctl is-enabled "container-${wp_container}.service" 2>/dev/null | grep -q "enabled"; then
            continue
        fi
        
        services+=("$svc_name")
    done
    shopt -u nullglob
    
    [ ${#services[@]} -eq 0 ] && die "No hay servicios WordPress deshabilitados para habilitar"
    
    # Usar fzf si está disponible
    if command -v fzf >/dev/null 2>&1; then
        echo "" >&2
        echo "📋 Selecciona el servicio WordPress a habilitar:" >&2
        local selected
        selected=$(printf "%s\n" "${services[@]}" | fzf --height=40% --reverse --prompt="Habilitar ❯ " --header="Usa ↑↓ para navegar, Enter para seleccionar") || exit 0
        if [ -z "$selected" ]; then
            exit 0
        fi
        echo "$selected"
    else
        # Fallback a menú numerado
        echo "Servicios WordPress deshabilitados:" >&2
        local i=1
        for svc in "${services[@]}"; do
            echo "$i) $svc" >&2
            ((i++))
        done
        
        local choice
        read -p "Selecciona el número del servicio a habilitar: " choice
        
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

log "Habilitando servicio WordPress: $SERVICE_NAME"

# 1. Habilitar configuración de Tor
if [ -f "$SERVICES_DIR/${SERVICE_NAME}.conf.disabled" ]; then
    log "Habilitando servicio Tor..."
    sudo mv "$SERVICES_DIR/${SERVICE_NAME}.conf.disabled" "$SERVICES_DIR/${SERVICE_NAME}.conf"
    sudo systemctl reload enola-tor || log "⚠️ No se pudo recargar enola-tor"
else
    die "Configuración de Tor no encontrada"
fi

# 2. Habilitar configuración de NGINX
if [ -f "$NGINX_AVAILABLE_DIR/${SERVICE_NAME}.conf" ]; then
    log "Habilitando servicio NGINX..."
    sudo ln -sf "$NGINX_AVAILABLE_DIR/${SERVICE_NAME}.conf" "$NGINX_ENABLED_DIR/${SERVICE_NAME}.conf"
    
    # Iniciar NGINX si no está activo, o recargar si ya está corriendo
    if systemctl is-active --quiet nginx; then
        sudo systemctl reload nginx || log "⚠️ No se pudo recargar nginx"
    else
        sudo systemctl start nginx || log "⚠️ No se pudo iniciar nginx"
    fi
else
    die "Configuración de NGINX no encontrada"
fi

# 3. Habilitar servicios de systemd
log "Habilitando servicios de systemd..."
sudo systemctl enable "container-${WP_CONTAINER}.service" 2>/dev/null || log "Servicio WordPress ya estaba habilitado"
sudo systemctl enable "container-${DB_CONTAINER}.service" 2>/dev/null || log "Servicio MySQL ya estaba habilitado"

# 4. Iniciar contenedores
log "Iniciando contenedores..."
sudo systemctl start "container-${DB_CONTAINER}.service" || log "⚠️ No se pudo iniciar MySQL"
sleep 2
sudo systemctl start "container-${WP_CONTAINER}.service" || log "⚠️ No se pudo iniciar WordPress"

log "✅ WordPress '$SERVICE_NAME' habilitado correctamente."
log "El servicio YA es accesible desde Tor Browser."
