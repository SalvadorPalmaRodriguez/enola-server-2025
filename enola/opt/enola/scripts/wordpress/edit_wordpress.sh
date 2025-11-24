#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

# ====================================================================
# Editar configuración de una instancia WordPress (NGINX/puerto)
# Compatible con instancias creadas por generate_wordpress.sh
# ====================================================================

ENV_DIR="/opt/enola/wordpress"
TEMPLATES_DIR="/usr/share/enola-server/templates"
NGINX_TEMPLATE="$TEMPLATES_DIR/nginx.template"
NGINX_SSL_TEMPLATE="$TEMPLATES_DIR/nginx_ssl.template"
NGINX_SITES_AVAIL="/etc/nginx/sites-available"
NGINX_SITES_ENA="/etc/nginx/sites-enabled"
SSL_BASE_DIR="/etc/enola-server/ssl"
WORDPRESS_UTILS="/opt/enola/scripts/wordpress/wordpress_utils.sh"

# Importar utilidades de WordPress
source "$WORDPRESS_UTILS" || { echo "Error: No se pudo cargar wordpress_utils.sh"; exit 1; }

# Importar sistema de backups
BACKUP_MANAGER="/opt/enola/scripts/common/backup_manager.sh"
if [ -f "$BACKUP_MANAGER" ]; then
    source "$BACKUP_MANAGER"
fi

log()   { echo -e "[WORDPRESS] $(date '+%F %T') | $*"; }
die()   { echo -e "[WORDPRESS] $(date '+%F %T') | ERROR | $*" >&2; exit 1; }

pick_service() {
    local services=()
    shopt -s nullglob
    for f in "$ENV_DIR"/*.env; do
        [ -f "$f" ] || continue
        services+=("$(basename "$f" .env)")
    done
    shopt -u nullglob
    
    local count=${#services[@]}
    if [ $count -eq 0 ]; then
        die "No hay instancias WordPress registradas en $ENV_DIR"
    fi
    
    # Usar fzf si está disponible
    if command -v fzf >/dev/null 2>&1; then
        echo "" >&2
        echo "📋 Selecciona el servicio WordPress:" >&2
        local selected
        selected=$(printf "%s\n" "${services[@]}" | fzf --height=40% --reverse --prompt="WordPress ❯ " --header="Usa ↑↓ para navegar, Enter para seleccionar") || exit 0
        if [ -z "$selected" ]; then
            exit 0
        fi
        echo "$selected"
    else
        # Fallback a menú numerado
        echo "" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "📋 Servicios WordPress disponibles:" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        local i=1
        for s in "${services[@]}"; do
            echo "  $i) $s" >&2
            i=$((i+1))
        done
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "" >&2
        read -rp "Elige número: " idx
        if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt $count ]; then
            die "Selección inválida"
        fi
        echo "${services[$((idx-1))]}"
    fi
}

check_port_available() {
    local port="$1"
    if ss -tuln | grep -q ":${port}\s"; then
        return 1  # Puerto ocupado
    fi
    return 0  # Puerto disponible
}

check_nginx_port_conflict() {
    local port="$1" current_service="$2"
    shopt -s nullglob
    for conf in "$NGINX_SITES_AVAIL"/*.conf; do
        [ -f "$conf" ] || continue
        local svc_name=$(basename "$conf" .conf)
        [ "$svc_name" = "$current_service" ] && continue
        if grep -qE "listen.*:${port}(\s|;)" "$conf" 2>/dev/null; then
            echo "$svc_name"
            return 1
        fi
    done
    shopt -u nullglob
    return 0
}

check_backend_port_conflict() {
    local port="$1" current_service="$2"
    shopt -s nullglob
    for conf in "$NGINX_SITES_AVAIL"/*.conf; do
        [ -f "$conf" ] || continue
        local svc_name=$(basename "$conf" .conf)
        [ "$svc_name" = "$current_service" ] && continue
        if grep -qE "proxy_pass\s+http://127\.0\.0\.1:${port}" "$conf" 2>/dev/null; then
            echo "$svc_name"
            return 1
        fi
    done
    shopt -u nullglob
    return 0
}

read_port() {
    local prompt="$1" default="$2" port_type="$3" current_service="$4" input
    while true; do
        read -rp "$prompt [$default] (o 'q' para cancelar): " input
        
        # Permitir cancelar
        if [[ "$input" == "q" ]] || [[ "$input" == "Q" ]]; then
            echo "" >&2
            echo "$(date +"%Y-%m-%d %H:%M:%S") | Operación cancelada por el usuario" >&2
            return 1
        fi
        
        input="${input:-$default}"
        
        # Validar formato
        if ! [[ "$input" =~ ^[0-9]+$ ]] || [ "$input" -lt 1 ] || [ "$input" -gt 65535 ]; then
            echo "❌ Puerto inválido: $input (debe estar entre 1-65535)" >&2
            echo "   Intenta de nuevo..." >&2
            continue
        fi
        
        # Si es el mismo puerto, no validar
        [ "$input" = "$default" ] && echo "$input" && return 0
        
        # Validar disponibilidad para puertos NGINX
        if [[ "$port_type" == "nginx" ]]; then
            if ! check_port_available "$input"; then
                echo "❌ Puerto $input ya está ocupado por otro proceso" >&2
                echo "   Elige un puerto diferente..." >&2
                continue
            fi
            
            # Validar conflicto con otros servicios NGINX
            local conflict_svc
            if ! conflict_svc=$(check_nginx_port_conflict "$input" "$current_service"); then
                echo "❌ Puerto $input ya usado por servicio: $conflict_svc" >&2
                echo "   Elige un puerto diferente..." >&2
                continue
            fi
        fi
        
        # Validar disponibilidad para puertos backend
        if [[ "$port_type" == "backend" ]]; then
            if ! check_port_available "$input"; then
                echo "❌ Puerto $input ya está ocupado por otro proceso" >&2
                echo "   Elige un puerto diferente..." >&2
                continue
            fi
            
            # Validar conflicto con otros backends
            local conflict_svc
            if ! conflict_svc=$(check_backend_port_conflict "$input" "$current_service"); then
                echo "❌ Puerto $input ya usado como backend por: $conflict_svc" >&2
                echo "   Elige un puerto diferente..." >&2
                continue
            fi
        fi
        
        # Puerto válido
        echo "$input"
        return 0
    done
}

service_name="${1:-}"
if [ -z "$service_name" ]; then
    service_name=$(pick_service)
fi

ENV_FILE="$ENV_DIR/${service_name}.env"
[ -f "$ENV_FILE" ] || die "No existe $ENV_FILE"

CONFIG_AVAIL="$NGINX_SITES_AVAIL/${service_name}.conf"
CONFIG_ENA="$NGINX_SITES_ENA/${service_name}.conf"
LOG_DIR="/var/log/enola-server/${service_name}"
SSL_DIR="$SSL_BASE_DIR/${service_name}"

# Verificar si el servicio está activo
MYSQL_SERVICE="container-enola-${service_name}-mysql.service"
WP_SERVICE="container-enola-${service_name}-wp.service"
SERVICE_ACTIVE=false

# Verificar estado REAL: systemd O contenedor corriendo
local wp_container_status=$(podman inspect --format '{{.State.Status}}' "enola-${service_name}-wp" 2>/dev/null || echo "missing")
local db_container_status=$(podman inspect --format '{{.State.Status}}' "enola-${service_name}-mysql" 2>/dev/null || echo "missing")

if systemctl is-active --quiet "$WP_SERVICE" 2>/dev/null || systemctl is-active --quiet "$MYSQL_SERVICE" 2>/dev/null || \
   [ "$wp_container_status" = "running" ] || [ "$db_container_status" = "running" ]; then
    SERVICE_ACTIVE=true
    echo ""
    echo "⚠️  ADVERTENCIA: El servicio '$service_name' está ACTIVO"
    echo "   Cambiar puertos afectará las conexiones actuales"
    echo ""
    read -rp "¿Deseas continuar? (s/N): " confirm
    if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
        log "Operación cancelada por el usuario"
        exit 0
    fi
    echo ""
fi

# Detectar si es configuración SSL o no
HAS_SSL=false
if [ -d "$SSL_DIR" ] && [ -f "$SSL_DIR/onion.crt" ]; then
    HAS_SSL=true
fi

# Leer configuración actual
tor_conf="/etc/tor/enola.d/${service_name}.conf"

if [ "$HAS_SSL" = true ]; then
    # Configuración SSL: leer puertos HTTP y HTTPS
    current_nginx_http_port=""
    current_nginx_https_port=""
    
    if [ -r "$CONFIG_ENA" ]; then
        # Puerto HTTP (primer listen)
        current_nginx_http_port=$(grep -E '^\s*listen.*:' "$CONFIG_ENA" | head -1 | sed -E 's/.*:([0-9]+).*/\1/' || true)
        # Puerto HTTPS (listen con ssl)
        current_nginx_https_port=$(grep -E '^\s*listen.*ssl' "$CONFIG_ENA" | head -1 | sed -E 's/.*:([0-9]+).*/\1/' || true)
    fi
    [ -n "$current_nginx_http_port" ] || current_nginx_http_port=9000
    [ -n "$current_nginx_https_port" ] || current_nginx_https_port=9100
    
    # Puertos Onion
    current_onion_http_port=""
    current_onion_https_port=""
    if [ -f "$tor_conf" ]; then
        current_onion_http_port=$(sudo grep -E '^HiddenServicePort 80' "$tor_conf" | awk '{print $2}' || true)
        current_onion_https_port=$(sudo grep -E '^HiddenServicePort 443' "$tor_conf" | awk '{print $2}' || true)
    fi
    [ -n "$current_onion_http_port" ] || current_onion_http_port=80
    [ -n "$current_onion_https_port" ] || current_onion_https_port=443
    
    # Puerto Backend (WordPress container)
    current_backend_port=""
    if [ -r "$CONFIG_ENA" ]; then
        current_backend_port=$(grep -E "proxy_pass\s+http://127\.0\.0\.1:" "$CONFIG_ENA" | head -1 | sed -E 's/.*:([0-9]+).*/\1/' || true)
    fi
    [ -n "$current_backend_port" ] || current_backend_port=8080
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 Configuración actual de '$service_name' (con SSL):"
    echo ""
    echo "   FLUJO HTTP:"
    printf "   %-15s %-35s %-25s\n" "Componente" "Puerto (¿editable?)" "Destino"
    printf "   %-15s %-35s %-25s\n" "----------" "-------------------" "-------"
    printf "   %-15s %-35s %-25s\n" "Tor" "$current_onion_http_port en red .onion [editable]" "→ Nginx localhost:$current_nginx_http_port"
    printf "   %-15s %-35s %-25s\n" "Nginx" "$current_nginx_http_port en localhost [editable]" "→ WordPress localhost:$current_backend_port"
    printf "   %-15s %-35s %-25s\n" "WordPress" "$current_backend_port en localhost [FIJO]" "—"
    echo ""
    echo "   FLUJO HTTPS:"
    printf "   %-15s %-35s %-25s\n" "Componente" "Puerto (¿editable?)" "Destino"
    printf "   %-15s %-35s %-25s\n" "----------" "-------------------" "-------"
    printf "   %-15s %-35s %-25s\n" "Tor" "$current_onion_https_port en red .onion [editable]" "→ Nginx localhost:$current_nginx_https_port"
    printf "   %-15s %-35s %-25s\n" "Nginx" "$current_nginx_https_port en localhost [editable]" "→ WordPress localhost:$current_backend_port"
    printf "   %-15s %-35s %-25s\n" "WordPress" "$current_backend_port en localhost [editable]" "—"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "⚠️  Cambiar el puerto backend requiere recrear el contenedor de WordPress"
    echo "    ⏱️  Tiempo de inactividad: ~10-15 segundos"
    echo "    💾 Los datos están en volúmenes persistentes (no se pierden)"
    echo ""
    echo "💡 Escribe 'q' en cualquier momento para cancelar"
    echo ""
    
    new_onion_http_port=$(read_port "Nuevo puerto Onion HTTP" "$current_onion_http_port" "onion" "$service_name") || exit 0
    new_nginx_http_port=$(read_port "Nuevo puerto NGINX HTTP" "$current_nginx_http_port" "nginx" "$service_name") || exit 0
    new_onion_https_port=$(read_port "Nuevo puerto Onion HTTPS" "$current_onion_https_port" "onion" "$service_name") || exit 0
    new_nginx_https_port=$(read_port "Nuevo puerto NGINX HTTPS" "$current_nginx_https_port" "nginx" "$service_name") || exit 0
    new_backend_port=$(read_port "Nuevo puerto Backend (WordPress)" "$current_backend_port" "backend" "$service_name") || exit 0
else
    # Configuración sin SSL (legacy)
    current_nginx_port=""
    if [ -r "$CONFIG_ENA" ]; then
        current_nginx_port=$(grep -E '^\s*listen' "$CONFIG_ENA" | head -1 | sed -E 's/.*:([0-9]+).*/\1/' || true)
    fi
    [ -n "$current_nginx_port" ] || current_nginx_port=9000
    
    current_onion_port=""
    if [ -f "$tor_conf" ]; then
        current_onion_port=$(sudo grep -E '^HiddenServicePort' "$tor_conf" | head -1 | awk '{print $2}' || true)
    fi
    [ -n "$current_onion_port" ] || current_onion_port=80
    
    # Puerto Backend (WordPress container)
    current_backend_port=""
    if [ -r "$CONFIG_ENA" ]; then
        current_backend_port=$(grep -E "proxy_pass\s+http://127\.0\.0\.1:" "$CONFIG_ENA" | head -1 | sed -E 's/.*:([0-9]+).*/\1/' || true)
    fi
    [ -n "$current_backend_port" ] || current_backend_port=8080
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 Configuración actual de '$service_name' (sin SSL):"
    echo ""
    printf "   %-15s %-35s %-25s\n" "Componente" "Puerto (¿editable?)" "Destino"
    printf "   %-15s %-35s %-25s\n" "----------" "-------------------" "-------"
    printf "   %-15s %-35s %-25s\n" "Tor" "$current_onion_port en red .onion [editable]" "→ Nginx localhost:$current_nginx_port"
    printf "   %-15s %-35s %-25s\n" "Nginx" "$current_nginx_port en localhost [editable]" "→ WordPress localhost:$current_backend_port"
    printf "   %-15s %-35s %-25s\n" "WordPress" "$current_backend_port en localhost [editable]" "—"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "⚠️  Cambiar el puerto backend requiere recrear el contenedor de WordPress"
    echo "    ⏱️  Tiempo de inactividad: ~10-15 segundos"
    echo "    💾 Los datos están en volúmenes persistentes (no se pierden)"
    echo ""
    echo "💡 Escribe 'q' en cualquier momento para cancelar"
    echo ""
    
    new_onion_port=$(read_port "Nuevo puerto Onion" "$current_onion_port" "onion" "$service_name") || exit 0
    new_nginx_port=$(read_port "Nuevo puerto NGINX" "$current_nginx_port" "nginx" "$service_name") || exit 0
    new_backend_port=$(read_port "Nuevo puerto Backend (WordPress)" "$current_backend_port" "backend" "$service_name") || exit 0
fi

# Crear backup antes de aplicar cambios
if type backup_service >/dev/null 2>&1; then
    echo ""
    echo "📦 Creando backup de seguridad antes de aplicar cambios..."
    backup_service "$service_name" || echo "⚠️  Advertencia: No se pudo crear backup"
    echo ""
fi

mkdir -p "$(dirname "$CONFIG_AVAIL")" "$LOG_DIR"

if [ "$HAS_SSL" = true ]; then
    # Configuración con SSL
    if [ ! -f "$NGINX_SSL_TEMPLATE" ]; then
        die "No se encuentra plantilla NGINX SSL: $NGINX_SSL_TEMPLATE"
    fi
    
    # Obtener hostname onion
    hs_file="/var/lib/tor/hidden_service_${service_name}/hostname"
    if [ -f "$hs_file" ]; then
        onion_hostname=$(sudo cat "$hs_file")
    else
        onion_hostname="localhost"
    fi
    
    SSL_CERT="$SSL_DIR/onion.crt"
    SSL_KEY="$SSL_DIR/onion.key"
    
    export BACKEND_PORT="$new_backend_port" \
           NGINX_EXTERNAL="$new_nginx_http_port" \
           NGINX_EXTERNAL_SSL="$new_nginx_https_port" \
           LOG_DIR SERVICE_NAME="$service_name" \
           ONION_ADDRESS="$onion_hostname" \
           SSL_CERT SSL_KEY
    
    envsubst '${BACKEND_PORT} ${NGINX_EXTERNAL} ${NGINX_EXTERNAL_SSL} ${LOG_DIR} ${SERVICE_NAME} ${ONION_ADDRESS} ${SSL_CERT} ${SSL_KEY}' \
        < "$NGINX_SSL_TEMPLATE" > "$CONFIG_AVAIL"
    
    log "✅ NGINX actualizado con SSL:"
    log "   HTTP:  http://127.0.0.1:$new_nginx_http_port (→ redirige a HTTPS)"
    log "   HTTPS: https://127.0.0.1:$new_nginx_https_port"
    log "   Backend: http://127.0.0.1:$new_backend_port"
else
    # Configuración sin SSL (legacy)
    if [ ! -f "$NGINX_TEMPLATE" ]; then
        die "No se encuentra plantilla NGINX: $NGINX_TEMPLATE"
    fi
    
    export BACKEND_PORT="$new_backend_port" NGINX_EXTERNAL="$new_nginx_port" LOG_DIR SERVICE_NAME="$service_name"
    envsubst '${BACKEND_PORT} ${NGINX_EXTERNAL} ${LOG_DIR} ${SERVICE_NAME}' < "$NGINX_TEMPLATE" > "$CONFIG_AVAIL"
    
    log "✅ NGINX actualizado: http://127.0.0.1:$new_nginx_port"
    log "   Backend: http://127.0.0.1:$new_backend_port"
fi

ln -sf "$CONFIG_AVAIL" "$CONFIG_ENA"

# Probar y recargar NGINX
nginx -t || die "Error en la configuración de NGINX"

# Iniciar NGINX si no está activo, o recargar si ya está corriendo
if systemctl is-active --quiet nginx; then
    systemctl reload nginx || die "No se pudo recargar NGINX"
else
    systemctl start nginx || die "No se pudo iniciar NGINX"
fi

# Actualizar configuración de Tor
if [ -f "$tor_conf" ]; then
    if [ "$HAS_SSL" = true ]; then
        # Actualizar configuración SSL con ambos puertos
        sudo sed -i "s|HiddenServicePort 80 127.0.0.1:[0-9]*|HiddenServicePort $new_onion_http_port 127.0.0.1:$new_nginx_http_port|" "$tor_conf"
        sudo sed -i "s|HiddenServicePort 443 127.0.0.1:[0-9]*|HiddenServicePort $new_onion_https_port 127.0.0.1:$new_nginx_https_port|" "$tor_conf"
        
        if systemctl is-active --quiet enola-tor; then
            sudo systemctl reload enola-tor
            log "✅ Tor actualizado:"
            log "   HTTP:  Onion :$new_onion_http_port → 127.0.0.1:$new_nginx_http_port"
            log "   HTTPS: Onion :$new_onion_https_port → 127.0.0.1:$new_nginx_https_port"
        fi
    else
        # Actualizar configuración sin SSL (legacy)
        sudo sed -i "s|HiddenServicePort [0-9]* 127.0.0.1:[0-9]*|HiddenServicePort $new_onion_port 127.0.0.1:$new_nginx_port|" "$tor_conf"
        
        if systemctl is-active --quiet enola-tor; then
            sudo systemctl reload enola-tor
            log "✅ Tor actualizado: Onion :$new_onion_port → 127.0.0.1:$new_nginx_port"
        fi
    fi
fi

# Recrear contenedor si cambió el puerto backend
if [ "$new_backend_port" != "$current_backend_port" ]; then
    log "🔄 Puerto backend cambió de $current_backend_port a $new_backend_port"
    log "   Recreando contenedor de WordPress..."
    
    # Usar función del módulo compartido
    if recreate_wordpress_container "$service_name" "$new_backend_port" "$current_backend_port"; then
        log "✅ Contenedor recreado exitosamente"
        # Mostrar resumen de la recreación
        show_recreation_summary "$service_name" "$current_backend_port" "$new_backend_port"
    else
        die "Error al recrear el contenedor. Revisar logs."
    fi
else
    log "ℹ️  Puerto backend de WordPress: $current_backend_port (sin cambios)"
fi

hs_file="/var/lib/tor/hidden_service_${service_name}/hostname"
if [ -f "$hs_file" ]; then
    onion_addr=$(sudo cat "$hs_file")
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Configuración actualizada correctamente"
    
    if [ "$HAS_SSL" = true ]; then
        log "🌐 Acceso local HTTP:  http://127.0.0.1:$new_nginx_http_port (→ redirige)"
        log "🔐 Acceso local HTTPS: https://127.0.0.1:$new_nginx_https_port"
        log "🧅 Acceso Onion HTTP:  http://${onion_addr}:${new_onion_http_port}"
        log "🔐 Acceso Onion HTTPS: https://${onion_addr}:${new_onion_https_port}"
        echo ""
        echo "💡 RECOMENDADO: https://${onion_addr}"
        echo "   (Puerto 443 es estándar, no necesita especificarse)"
    else
        log "📡 Acceso local: http://127.0.0.1:$new_nginx_port"
        log "🧅 Acceso Onion: http://${onion_addr}:${new_onion_port}"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
