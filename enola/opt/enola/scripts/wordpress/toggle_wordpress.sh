#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

# ====================================================================
# TOGGLE WordPress (multi-instancia con Podman)
# ====================================================================

ENV_DIR="/opt/enola/wordpress"
TOR_DIR="/var/lib/tor"
NGINX_SITES="/etc/nginx/sites-enabled"

log()  { echo -e "[\e[32mOK\e[0m] $*"; }
warn() { echo -e "[\e[33mWARN\e[0m] $*"; }
die()  { echo -e "[\e[31mERROR\e[0m] $*" >&2; exit 1; }

# Función para seleccionar servicios que se pueden INICIAR (detenidos y habilitados)
pick_service_to_start() {
    local services=()
    shopt -s nullglob
    for f in "$ENV_DIR"/*.env; do
        [ -f "$f" ] || continue
        local svc_name=$(basename "$f" .env)
        local wp_service="container-enola-${svc_name}-wp.service"
        
        # Debe estar habilitado (tener .conf activo)
        [ ! -f "/etc/tor/enola.d/${svc_name}.conf" ] && continue
        
        # Verificar estado REAL del contenedor (no solo systemd)
        local container_status=$(podman inspect --format '{{.State.Status}}' "enola-${svc_name}-wp" 2>/dev/null || echo "missing")
        
        # Si systemd dice "active" pero el contenedor está stopped -> resincronizar
        if systemctl is-active --quiet "$wp_service" && [[ "$container_status" != "running" ]]; then
            systemctl stop "$wp_service" "container-enola-${svc_name}-mysql.service" &>/dev/null
        fi
        
        # Debe estar detenido (verificar ambos: systemd Y contenedor)
        if systemctl is-active --quiet "$wp_service" || [[ "$container_status" == "running" ]]; then
            continue
        fi
        
        services+=("$svc_name")
    done
    shopt -u nullglob

    [ ${#services[@]} -eq 0 ] && die "No hay servicios WordPress detenidos para iniciar"
    
    # Si solo hay un servicio, seleccionarlo automáticamente
    [ ${#services[@]} -eq 1 ] && { echo "${services[0]}"; return 0; }
    
    _show_menu "Iniciar ❯ " "iniciar" "${services[@]}"
}

# Función para seleccionar servicios que se pueden DETENER (corriendo)
pick_service_to_stop() {
    local services=()
    shopt -s nullglob
    for f in "$ENV_DIR"/*.env; do
        [ -f "$f" ] || continue
        local svc_name=$(basename "$f" .env)
        local wp_service="container-enola-${svc_name}-wp.service"
        
        # Verificar estado REAL del contenedor
        local container_status=$(podman inspect --format '{{.State.Status}}' "enola-${svc_name}-wp" 2>/dev/null || echo "missing")
        
        # Si contenedor corriendo pero systemd inactivo -> resincronizar
        if ! systemctl is-active --quiet "$wp_service" && [[ "$container_status" == "running" ]]; then
            systemctl start "$wp_service" "container-enola-${svc_name}-mysql.service" &>/dev/null
        fi
        
        # Debe estar corriendo (verificar ambos: systemd O contenedor)
        if ! systemctl is-active --quiet "$wp_service" && [[ "$container_status" != "running" ]]; then
            continue
        fi
        
        services+=("$svc_name")
    done
    shopt -u nullglob

    [ ${#services[@]} -eq 0 ] && die "No hay servicios WordPress corriendo para detener"
    
    # Si solo hay un servicio, seleccionarlo automáticamente
    [ ${#services[@]} -eq 1 ] && { echo "${services[0]}"; return 0; }
    
    _show_menu "Detener ❯ " "detener" "${services[@]}"
}

# Función para seleccionar servicios que se pueden REINICIAR (habilitados)
pick_service_to_restart() {
    local services=()
    shopt -s nullglob
    for f in "$ENV_DIR"/*.env; do
        [ -f "$f" ] || continue
        local svc_name=$(basename "$f" .env)
        
        # Debe estar habilitado (tener .conf activo)
        [ ! -f "/etc/tor/enola.d/${svc_name}.conf" ] && continue
        
        services+=("$svc_name")
    done
    shopt -u nullglob

    [ ${#services[@]} -eq 0 ] && die "No hay servicios WordPress habilitados para reiniciar"
    
    # Si solo hay un servicio, seleccionarlo automáticamente
    [ ${#services[@]} -eq 1 ] && { echo "${services[0]}"; return 0; }
    
    _show_menu "Reiniciar ❯ " "reiniciar" "${services[@]}"
}

# Función para seleccionar cualquier servicio (status o toggle)
pick_service_any() {
    local services=()
    shopt -s nullglob
    for f in "$ENV_DIR"/*.env; do
        [ -f "$f" ] || continue
        services+=("$(basename "$f" .env)")
    done
    shopt -u nullglob

    [ ${#services[@]} -eq 0 ] && die "No hay servicios WordPress registrados en $ENV_DIR"
    
    # Si solo hay un servicio, seleccionarlo automáticamente
    [ ${#services[@]} -eq 1 ] && { echo "${services[0]}"; return 0; }
    
    _show_menu "WordPress ❯ " "seleccionar" "${services[@]}"
}

# Función auxiliar para mostrar el menú (fzf o numerado)
_show_menu() {
    local prompt="$1"
    local action="$2"
    shift 2
    local services=("$@")
    
    # Usar fzf si está disponible
    if command -v fzf >/dev/null 2>&1; then
        echo "" >&2
        echo "📋 Selecciona el servicio WordPress a $action:" >&2
        local selected
        selected=$(printf "%s\n" "${services[@]}" | fzf --height=40% --reverse --prompt="$prompt" --header="Usa ↑↓ para navegar, Enter para seleccionar") || exit 0
        if [ -z "$selected" ]; then
            exit 0
        fi
        echo "$selected"
    else
        # Fallback a menú numerado
        echo "Servicios WordPress disponibles:" >&2
        local i=1
        for svc in "${services[@]}"; do
            echo "$i) $svc" >&2
            ((i++))
        done
        
        local choice
        read -p "Selecciona el número del servicio a $action: " choice
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#services[@]} ]; then
            die "Selección inválida"
        fi
        
        echo "${services[$((choice-1))]}"
    fi
}

# Primer argumento: acción (start/stop/restart/status) o nombre del servicio
action="${1:-}"
service_name=""

# Detectar si el primer argumento es una acción o un nombre de servicio
if [[ "$action" =~ ^(start|stop|restart|status)$ ]]; then
    # El segundo argumento sería el nombre del servicio (opcional)
    service_name="${2:-}"
else
    # El primer argumento es el nombre del servicio (o vacío)
    service_name="$action"
    action=""
fi

# Si no hay nombre de servicio, preguntar al usuario con filtrado según acción
if [ -z "$service_name" ]; then
    case "$action" in
        start)
            service_name=$(pick_service_to_start)
            ;;
        stop)
            service_name=$(pick_service_to_stop)
            ;;
        restart)
            service_name=$(pick_service_to_restart)
            ;;
        *)
            service_name=$(pick_service_any)
            ;;
    esac
fi

# Si después de la selección sigue vacío, salir (usuario canceló)
[ -z "$service_name" ] && exit 0

wp_container="enola-${service_name}-wp"
db_container="enola-${service_name}-mysql"
wp_service="container-${wp_container}.service"
db_service="container-${db_container}.service"

# Verificar existencia del servicio systemd
if ! systemctl list-unit-files "$wp_service" --no-legend | grep -q "$wp_service"; then
    die "El servicio '$wp_service' no existe. Instala primero el servicio WordPress ($service_name)."
fi

# Ejecutar acción solicitada
case "$action" in
    start)
        log "Iniciando WordPress ($service_name)..."
        sudo systemctl start "$db_service" "$wp_service" || die "No se pudo iniciar el servicio"
        log "✅ WordPress iniciado"
        log "   • MySQL: iniciado"
        log "   • WordPress: iniciado"
        ;;
    stop)
        log "Deteniendo WordPress ($service_name)..."
        sudo systemctl stop "$db_service" "$wp_service" || die "No se pudo detener el servicio"
        log "✅ WordPress detenido"
        log "   • MySQL: detenido"
        log "   • WordPress: detenido"
        ;;
    restart)
        log "Reiniciando WordPress ($service_name)..."
        sudo systemctl restart "$db_service" "$wp_service" || die "No se pudo reiniciar el servicio"
        log "✅ WordPress reiniciado"
        log "   • MySQL: reiniciado"
        log "   • WordPress: reiniciado"
        ;;
    status)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 Estado de WordPress ($service_name)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🗄️  MySQL:"
        sudo systemctl status "$db_service" --no-pager -l || true
        echo ""
        echo "🌐 WordPress:"
        sudo systemctl status "$wp_service" --no-pager -l || true
        ;;
    *)
        # Sin acción especificada: hacer toggle automático (comportamiento legacy)
        
        # Validar que esté habilitado
        if [ ! -f "/etc/tor/enola.d/${service_name}.conf" ]; then
            die "El servicio '$service_name' no está habilitado. Usa la opción 'Habilitar servicio' primero."
        fi
        
        if systemctl is-active --quiet "$wp_service"; then
            log "Deteniendo WordPress ($service_name)..."
            sudo systemctl stop "$db_service" "$wp_service" || die "No se pudo detener el servicio"
            log "✅ WordPress detenido"
            log "   • MySQL: detenido"
            log "   • WordPress: detenido"
        else
            log "Iniciando WordPress ($service_name)..."
            sudo systemctl start "$db_service" "$wp_service" || die "No se pudo iniciar el servicio"
            log "✅ WordPress iniciado"
            log "   • MySQL: iniciado"
            log "   • WordPress: iniciado"
            
            # Mostrar URL onion y puertos NGINX si existen
            hs_file="$TOR_DIR/hidden_service_${service_name}/hostname"
            site="$NGINX_SITES/${service_name}.conf"
            onion=""; http_port=""; https_port=""
            
            [ -f "$hs_file" ] && onion=$(sudo cat "$hs_file" 2>/dev/null)
            
            if [ -r "$site" ]; then
                # Detectar si tiene SSL (dos bloques server)
                if grep -q "ssl_certificate" "$site"; then
                    http_port=$(grep -E '^\s*listen.*:' "$site" | head -1 | sed -E 's/.*:([0-9]+).*/\1/')
                    https_port=$(grep -E '^\s*listen.*ssl' "$site" | head -1 | sed -E 's/.*:([0-9]+).*/\1/')
                else
                    http_port=$(grep -E '^\s*listen' "$site" | head -1 | sed -E 's/.*:([0-9]+).*/\1/')
                fi
            fi
            
            echo
            if [ -n "$https_port" ]; then
                log "🌐 Acceso local HTTP:  http://127.0.0.1:$http_port (→ redirige a HTTPS)"
                log "🔐 Acceso local HTTPS: https://127.0.0.1:$https_port"
                [ -n "$onion" ] && log "🧅 Acceso Onion:       https://$onion"
            else
                [ -n "$http_port" ] && log "🌐 Acceso local: http://127.0.0.1:$http_port"
                [ -n "$onion" ] && log "🧅 Acceso Onion: http://$onion"
            fi
        fi
        ;;
esac
