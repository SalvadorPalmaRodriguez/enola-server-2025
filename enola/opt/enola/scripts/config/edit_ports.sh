#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

# ====================================================================
# SCRIPT DE EDICIÓN DE PUERTOS PARA SERVICIOS TOR
# ====================================================================
# Este script permite reconfigurar los puertos de los servicios ocultos
# de Tor (web, ssh, wordpress, etc.) de forma interactiva.
# ====================================================================

SERVICES_DIR="/etc/tor/enola.d"
TOR_DIR="/var/lib/tor"
TEMPLATES_DIR="/usr/share/enola-server/templates"
COMMON_DIR="/opt/enola/scripts/common"
WORDPRESS_UTILS="/opt/enola/scripts/wordpress/wordpress_utils.sh"

# Importar validador de puertos (nuevo)
if [ -f "$COMMON_DIR/port_validator.sh" ]; then
    source "$COMMON_DIR/port_validator.sh"
fi

# Importar utilidades de puertos
source "$COMMON_DIR/port_utils.sh" || { echo "Error: No se pudo cargar port_utils.sh"; exit 1; }

# Importar utilidades de WordPress
source "$WORDPRESS_UTILS" || { echo "Error: No se pudo cargar wordpress_utils.sh"; exit 1; }

# Funciones de logging
log()   { echo -e "[EDIT_PORTS] $(date '+%F %T') | $*"; }
warn()  { echo -e "[EDIT_PORTS] $(date '+%F %T') | WARN | $*"; }
die()   { echo -e "[EDIT_PORTS] $(date '+%F %T') | ERROR | $*"; exit 1; }

# Verificar disponibilidad de puerto (wrapping de port_utils)

check_nginx_port_conflict() {
    local port="$1" current_service="$2"
    shopt -s nullglob
    for conf in "$SERVICES_DIR"/*.conf; do
        [ -f "$conf" ] || continue
        local svc_name=$(basename "$conf" .conf)
        [ "$svc_name" = "$current_service" ] && continue
        
        # Verificar si otro servicio Tor usa este puerto como destino NGINX
        if grep -qE "127\.0\.0\.1:${port}(\s|$)" "$conf" 2>/dev/null; then
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
    
    # Verificar en configuraciones NGINX
    for nginx_conf in /etc/nginx/sites-available/*.conf; do
        [ -f "$nginx_conf" ] || continue
        local svc_name=$(basename "$nginx_conf" .conf)
        [ "$svc_name" = "$current_service" ] && continue
        
        # Verificar si otro servicio NGINX usa este puerto como backend
        if grep -qE "proxy_pass\s+http://127\.0\.0\.1:${port}" "$nginx_conf" 2>/dev/null; then
            echo "$svc_name"
            return 1
        fi
    done
    shopt -u nullglob
    return 0
}

read_port_with_validation() {
    local prompt="$1" default="$2" port_type="$3" current_service="$4"
    local input
    
    while true; do
        read -p "$prompt [$default] (o 'q' para cancelar): " input
        
        # Permitir cancelar
        if [[ "$input" == "q" ]] || [[ "$input" == "Q" ]]; then
            echo "" >&2
            echo "Operación cancelada por el usuario." >&2
            return 1
        fi
        
        input="${input:-$default}"
        
        # Validar formato
        if ! validate_port "$input"; then
            echo "❌ Puerto inválido: $input (debe estar entre 1-65535)" >&2
            echo "   Intenta de nuevo..." >&2
            continue
        fi
        
        # Si es el mismo puerto, no validar disponibilidad
        [ "$input" = "$default" ] && echo "$input" && return 0
        
        # Para puertos de NGINX, validar disponibilidad y conflictos
        if [[ "$port_type" == "nginx" ]]; then
            if ! check_port_available "$input"; then
                local process=$(get_port_process "$input" 2>/dev/null || echo "desconocido")
                echo "❌ Puerto $input ya está ocupado por: $process" >&2
                
                # Sugerir alternativa si está disponible la función
                if type suggest_alternative_port >/dev/null 2>&1; then
                    local alternative=$(suggest_alternative_port "$input" 2>/dev/null || echo "")
                    if [ -n "$alternative" ]; then
                        echo "💡 Puerto alternativo sugerido: $alternative" >&2
                    fi
                fi
                
                echo "   Elige un puerto diferente..." >&2
                continue
            fi
            
            # Verificar conflicto con otros servicios Tor
            local conflict_svc
            if ! conflict_svc=$(check_nginx_port_conflict "$input" "$current_service"); then
                echo "❌ Puerto $input ya usado por servicio Tor: $conflict_svc" >&2
                echo "   Elige un puerto diferente..." >&2
                continue
            fi
        fi
        
        # Para puertos de backend, validar disponibilidad y conflictos
        if [[ "$port_type" == "backend" ]]; then
            if ! check_port_available "$input"; then
                local process=$(get_port_process "$input" 2>/dev/null || echo "desconocido")
                echo "❌ Puerto $input ya está ocupado por: $process" >&2
                
                # Sugerir alternativa
                if type suggest_alternative_port >/dev/null 2>&1; then
                    local alternative=$(suggest_alternative_port "$input" 2>/dev/null || echo "")
                    if [ -n "$alternative" ]; then
                        echo "💡 Puerto alternativo sugerido: $alternative" >&2
                    fi
                fi
                
                echo "   Elige un puerto diferente..." >&2
                continue
            fi
            
            # Verificar conflicto con otros backends NGINX
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

# Verificar que se ejecuta como root
if [ "$(id -u)" -ne 0 ]; then
    die "Este script debe ejecutarse como root (sudo)"
fi

# ===========================
# 1. Listar servicios disponibles
# ===========================
list_services() {
    local services=()
    local preselected="$1"
    
    shopt -s nullglob
    for conf in "$SERVICES_DIR"/*.conf; do
        [ -f "$conf" ] || continue
        local service_name=$(basename "$conf" .conf)
        services+=("$service_name")
    done
    shopt -u nullglob
    
    if [ ${#services[@]} -eq 0 ]; then
        echo "" >&2
        echo "❌ No hay servicios Tor configurados" >&2
        exit 0
    fi
    
    # Si se pasó un servicio como argumento, validarlo y usarlo
    if [ -n "$preselected" ]; then
        for svc in "${services[@]}"; do
            if [ "$svc" = "$preselected" ]; then
                echo "$preselected"
                return 0
            fi
        done
        echo "" >&2
        echo "❌ Servicio '$preselected' no encontrado" >&2
        exit 1
    fi
    
    # Si solo hay un servicio, seleccionarlo automáticamente
    if [ ${#services[@]} -eq 1 ]; then
        echo "${services[0]}"
        return 0
    fi
    
    # Intentar usar fzf si está disponible y estamos en terminal interactivo
    if command -v fzf >/dev/null 2>&1 && [ -t 0 ]; then
        echo "" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "  Usa ↑↓ para navegar, Enter para seleccionar" >&2
        echo "  TAB para seleccionar múltiples (si aplica)" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "" >&2
        
        local selected
        selected=$(printf '%s\n' "${services[@]}" | fzf --prompt="Selecciona servicio Tor: " --height=40% --border --header="SERVICIOS TOR DISPONIBLES") || exit 0
        
        if [ -z "$selected" ]; then
            exit 0
        fi
        
        echo "$selected"
        return 0
    fi
    
    # Fallback: menú numerado tradicional
    local i=1
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "    SERVICIOS TOR DISPONIBLES" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    
    for service_name in "${services[@]}"; do
        # Leer configuración actual
        local conf="$SERVICES_DIR/${service_name}.conf"
        local onion_port=$(grep "HiddenServicePort" "$conf" | head -1 | awk '{print $2}')
        local nginx_dest=$(grep "HiddenServicePort" "$conf" | head -1 | awk '{print $3}')
        local nginx_port="${nginx_dest#*:}"
        
        echo "  $i) $service_name" >&2
        echo "     Onion: $onion_port → NGINX: $nginx_port" >&2
        echo "" >&2
        i=$((i+1))
    done
    
    echo "  0) Salir" >&2
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    
    # Selección
    local choice
    while true; do
        read -p "Elige el servicio a editar (número): " choice </dev/tty
        
        if [[ "$choice" == "0" ]]; then
            echo "Operación cancelada." >&2
            exit 0
        fi
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#services[@]} ]; then
            echo "❌ Opción inválida. Intenta de nuevo." >&2
            continue
        fi
        
        echo "${services[$((choice-1))]}"
        return 0
    done
}

# Seleccionar servicio (puede venir como argumento $1)
SELECTED_SERVICE=$(list_services "${1:-}")

# ===========================
# 2. Mostrar configuración actual
# ===========================
CONF_FILE="$SERVICES_DIR/${SELECTED_SERVICE}.conf"

if [ ! -f "$CONF_FILE" ]; then
    die "No se encontró el archivo de configuración: $CONF_FILE"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    CONFIGURACIÓN ACTUAL: $SELECTED_SERVICE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Leer puertos actuales
CURRENT_LINES=$(grep "HiddenServicePort" "$CONF_FILE")
NUM_PORTS=$(echo "$CURRENT_LINES" | wc -l)

# Buscar configuración NGINX para este servicio
NGINX_CONF="/etc/nginx/sites-available/${SELECTED_SERVICE}.conf"
if [ ! -f "$NGINX_CONF" ]; then
    # Puede ser el servicio "web" que usa default
    if [ "$SELECTED_SERVICE" = "web" ]; then
        NGINX_CONF="/etc/nginx/sites-available/default"
    fi
fi

if [ "$NUM_PORTS" -eq 1 ]; then
    # Servicio con un solo puerto (web, ssh, servicios personalizados)
    ONION_PORT=$(echo "$CURRENT_LINES" | awk '{print $2}')
    NGINX_DEST=$(echo "$CURRENT_LINES" | awk '{print $3}')
    NGINX_PORT="${NGINX_DEST#*:}"
    
    # Leer puerto backend de NGINX
    BACKEND_PORT=""
    if [ -f "$NGINX_CONF" ]; then
        BACKEND_PORT=$(grep -E "proxy_pass\s+http://127\.0\.0\.1:" "$NGINX_CONF" | head -1 | sed -E 's/.*:([0-9]+).*/\1/' || true)
    fi
    [ -n "$BACKEND_PORT" ] || BACKEND_PORT=8080
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "   %-15s %-35s %-25s\n" "Componente" "Puerto (¿editable?)" "Destino"
    printf "   %-15s %-35s %-25s\n" "----------" "-------------------" "-------"
    printf "   %-15s %-35s %-25s\n" "Tor" "$ONION_PORT en red .onion [editable]" "→ Nginx localhost:$NGINX_PORT"
    printf "   %-15s %-35s %-25s\n" "Nginx" "$NGINX_PORT en localhost [editable]" "→ Tu app localhost:$BACKEND_PORT"
    printf "   %-15s %-35s %-25s\n" "Tu app" "$BACKEND_PORT en localhost [editable]" "—"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Pedir nuevos puertos
    echo "Introduce los nuevos puertos (Enter para mantener)"
    echo "💡 Escribe 'q' en cualquier momento para cancelar"
    echo ""
    
    NEW_ONION=$(read_port_with_validation "Puerto Onion (red Tor)" "$ONION_PORT" "onion" "$SELECTED_SERVICE") || exit 0
    NEW_NGINX=$(read_port_with_validation "Puerto NGINX (donde escucha NGINX)" "$NGINX_PORT" "nginx" "$SELECTED_SERVICE") || exit 0
    NEW_BACKEND=$(read_port_with_validation "Puerto Backend (donde escucha tu app)" "$BACKEND_PORT" "backend" "$SELECTED_SERVICE") || exit 0
    
    # Confirmar
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  CAMBIOS A APLICAR:"
    echo "  🔸 Tor: $NEW_ONION → NGINX: 127.0.0.1:$NEW_NGINX"
    echo "  🔸 NGINX: $NEW_NGINX → Backend: 127.0.0.1:$NEW_BACKEND"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    read -p "¿Aplicar cambios? (s/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
        echo "Operación cancelada."
        exit 0
    fi
    
    # Aplicar cambios en Tor
    HS_DIR="$TOR_DIR/hidden_service_${SELECTED_SERVICE}"
    
    cat > "$CONF_FILE" <<EOF
HiddenServiceDir $HS_DIR
HiddenServiceVersion 3
HiddenServicePort $NEW_ONION 127.0.0.1:$NEW_NGINX
EOF
    
    chmod 640 "$CONF_FILE"
    chown root:debian-tor "$CONF_FILE"
    log "✅ Configuración Tor actualizada: $CONF_FILE"
    
    # Actualizar configuración NGINX si cambió el puerto NGINX o Backend
    if [ "$NEW_NGINX" != "$NGINX_PORT" ] || [ "$NEW_BACKEND" != "$BACKEND_PORT" ]; then
        if [ -f "$NGINX_CONF" ]; then
            log "Actualizando configuración NGINX: $NGINX_CONF"
            
            # Actualizar puerto listen
            sed -i "s/listen 127\.0\.0\.1:[0-9]\+;/listen 127.0.0.1:$NEW_NGINX;/" "$NGINX_CONF"
            sed -i "s/listen \[::1\]:[0-9]\+;/listen [::1]:$NEW_NGINX;/" "$NGINX_CONF"
            
            # Actualizar puerto proxy_pass
            sed -i "s|proxy_pass http://127\.0\.0\.1:[0-9]\+;|proxy_pass http://127.0.0.1:$NEW_BACKEND;|" "$NGINX_CONF"
            
            log "✅ Configuración NGINX actualizada"
            
            # Si cambió el puerto backend, verificar si es un servicio WordPress
            if [ "$NEW_BACKEND" != "$BACKEND_PORT" ]; then
                if is_wordpress_service "$SELECTED_SERVICE"; then
                    log "⚠️  Detectado servicio WordPress: es necesario recrear el contenedor"
                    log "   El contenedor de Podman escucha en el puerto antiguo: $BACKEND_PORT"
                    log "   NGINX ahora apunta al nuevo puerto: $NEW_BACKEND"
                    echo ""
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "⚠️  ATENCIÓN: Recreación de contenedor requerida"
                    echo ""
                    echo "   El servicio '$SELECTED_SERVICE' es un servicio WordPress"
                    echo "   que usa contenedores de Podman."
                    echo ""
                    echo "   Para aplicar el cambio de puerto backend, se debe:"
                    echo "   1. Detener los contenedores actuales"
                    echo "   2. Recrearlos con el nuevo mapeo de puerto"
                    echo ""
                    echo "   ⏱️  Tiempo de inactividad: ~10-15 segundos"
                    echo "   💾 Los datos están en volúmenes persistentes (no se pierden)"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo ""
                    read -p "¿Recrear contenedores ahora? (s/N): " RECREATE_CONFIRM
                    
                    if [[ "$RECREATE_CONFIRM" =~ ^[sS]$ ]]; then
                        log "🔄 Recreando contenedores de WordPress..."
                        
                        # Usar función del módulo compartido
                        if recreate_wordpress_container "$SELECTED_SERVICE" "$NEW_BACKEND" "$BACKEND_PORT"; then
                            log "✅ Contenedores recreados exitosamente"
                            # Mostrar resumen de la recreación
                            show_recreation_summary "$SELECTED_SERVICE" "$BACKEND_PORT" "$NEW_BACKEND"
                        else
                            warn "⚠️  Error al recrear contenedores. Revisar logs."
                        fi
                    else
                        warn "⚠️  Contenedores NO recreados. El servicio podría no funcionar correctamente."
                        warn "   Ejecutar manualmente desde el menú de WordPress si es necesario."
                    fi
                fi
            fi
            
            # Recargar NGINX
            if nginx -t 2>/dev/null; then
                systemctl reload nginx || warn "Error al recargar nginx"
                log "✅ NGINX recargado"
            else
                warn "Configuración NGINX inválida, revierte los cambios manualmente"
            fi
        else
            warn "No se encontró configuración NGINX en $NGINX_CONF"
        fi
    fi
    
elif [ "$NUM_PORTS" -eq 2 ]; then
    # Servicio con SSL (HTTP + HTTPS)
    HTTP_LINE=$(echo "$CURRENT_LINES" | grep "HiddenServicePort 80" || echo "$CURRENT_LINES" | head -1)
    HTTPS_LINE=$(echo "$CURRENT_LINES" | grep "HiddenServicePort 443" || echo "$CURRENT_LINES" | tail -1)
    
    HTTP_ONION=$(echo "$HTTP_LINE" | awk '{print $2}')
    HTTP_NGINX_DEST=$(echo "$HTTP_LINE" | awk '{print $3}')
    HTTP_NGINX_PORT="${HTTP_NGINX_DEST#*:}"
    
    HTTPS_ONION=$(echo "$HTTPS_LINE" | awk '{print $2}')
    HTTPS_NGINX_DEST=$(echo "$HTTPS_LINE" | awk '{print $3}')
    HTTPS_NGINX_PORT="${HTTPS_NGINX_DEST#*:}"
    
    # Leer puerto backend de NGINX (es el mismo para HTTP y HTTPS)
    BACKEND_PORT=""
    if [ -f "$NGINX_CONF" ]; then
        BACKEND_PORT=$(grep -E "proxy_pass\s+http://127\.0\.0\.1:" "$NGINX_CONF" | head -1 | sed -E 's/.*:([0-9]+).*/\1/' || true)
    fi
    [ -n "$BACKEND_PORT" ] || BACKEND_PORT=8080
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   FLUJO HTTP:"
    printf "   %-15s %-35s %-25s\n" "Componente" "Puerto (¿editable?)" "Destino"
    printf "   %-15s %-35s %-25s\n" "----------" "-------------------" "-------"
    printf "   %-15s %-35s %-25s\n" "Tor" "$HTTP_ONION en red .onion [editable]" "→ Nginx localhost:$HTTP_NGINX_PORT"
    printf "   %-15s %-35s %-25s\n" "Nginx" "$HTTP_NGINX_PORT en localhost [editable]" "→ Tu app localhost:$BACKEND_PORT"
    printf "   %-15s %-35s %-25s\n" "Tu app" "$BACKEND_PORT en localhost [editable]" "—"
    echo ""
    echo "   FLUJO HTTPS:"
    printf "   %-15s %-35s %-25s\n" "Componente" "Puerto (¿editable?)" "Destino"
    printf "   %-15s %-35s %-25s\n" "----------" "-------------------" "-------"
    printf "   %-15s %-35s %-25s\n" "Tor" "$HTTPS_ONION en red .onion [editable]" "→ Nginx localhost:$HTTPS_NGINX_PORT"
    printf "   %-15s %-35s %-25s\n" "Nginx" "$HTTPS_NGINX_PORT en localhost [editable]" "→ Tu app localhost:$BACKEND_PORT"
    printf "   %-15s %-35s %-25s\n" "Tu app" "$BACKEND_PORT en localhost [editable]" "—"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Pedir nuevos puertos
    echo "Introduce los nuevos puertos (Enter para mantener)"
    echo "💡 Escribe 'q' en cualquier momento para cancelar"
    echo ""
    
    NEW_HTTP_ONION=$(read_port_with_validation "Puerto HTTP Onion" "$HTTP_ONION" "onion" "$SELECTED_SERVICE") || exit 0
    NEW_HTTP_NGINX=$(read_port_with_validation "Puerto HTTP NGINX" "$HTTP_NGINX_PORT" "nginx" "$SELECTED_SERVICE") || exit 0
    NEW_HTTPS_ONION=$(read_port_with_validation "Puerto HTTPS Onion" "$HTTPS_ONION" "onion" "$SELECTED_SERVICE") || exit 0
    NEW_HTTPS_NGINX=$(read_port_with_validation "Puerto HTTPS NGINX" "$HTTPS_NGINX_PORT" "nginx" "$SELECTED_SERVICE") || exit 0
    NEW_BACKEND=$(read_port_with_validation "Puerto Backend (aplicación)" "$BACKEND_PORT" "backend" "$SELECTED_SERVICE") || exit 0
    
    # Confirmar
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  CAMBIOS A APLICAR:"
    echo "  🔸 Tor HTTP:  $NEW_HTTP_ONION → NGINX: 127.0.0.1:$NEW_HTTP_NGINX"
    echo "  🔸 Tor HTTPS: $NEW_HTTPS_ONION → NGINX: 127.0.0.1:$NEW_HTTPS_NGINX"
    echo "  🔸 NGINX → Backend: 127.0.0.1:$NEW_BACKEND"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    read -p "¿Aplicar cambios? (s/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
        echo "Operación cancelada."
        exit 0
    fi
    
    # Aplicar cambios en Tor
    HS_DIR="$TOR_DIR/hidden_service_${SELECTED_SERVICE}"
    
    cat > "$CONF_FILE" <<EOF
HiddenServiceDir $HS_DIR
HiddenServiceVersion 3
HiddenServicePort $NEW_HTTP_ONION 127.0.0.1:$NEW_HTTP_NGINX
HiddenServicePort $NEW_HTTPS_ONION 127.0.0.1:$NEW_HTTPS_NGINX
EOF
    
    chmod 640 "$CONF_FILE"
    chown root:debian-tor "$CONF_FILE"
    log "✅ Configuración Tor actualizada: $CONF_FILE"
    
    # Actualizar configuración NGINX si cambió algún puerto
    NEEDS_NGINX_UPDATE=false
    [ "$NEW_HTTP_NGINX" != "$HTTP_NGINX_PORT" ] && NEEDS_NGINX_UPDATE=true
    [ "$NEW_HTTPS_NGINX" != "$HTTPS_NGINX_PORT" ] && NEEDS_NGINX_UPDATE=true
    [ "$NEW_BACKEND" != "$BACKEND_PORT" ] && NEEDS_NGINX_UPDATE=true
    
    if [ "$NEEDS_NGINX_UPDATE" = true ]; then
        if [ -f "$NGINX_CONF" ]; then
            log "Actualizando configuración NGINX: $NGINX_CONF"
            
            # Actualizar puertos listen (HTTP en primer lugar, HTTPS con ssl)
            # Buscar primera línea listen sin ssl (HTTP)
            sed -i "0,/listen 127\.0\.0\.1:[0-9]\+;/{s/listen 127\.0\.0\.1:[0-9]\+;/listen 127.0.0.1:$NEW_HTTP_NGINX;/}" "$NGINX_CONF"
            sed -i "0,/listen \[::1\]:[0-9]\+;/{s/listen \[::1\]:[0-9]\+;/listen [::1]:$NEW_HTTP_NGINX;/}" "$NGINX_CONF"
            
            # Buscar línea listen con ssl (HTTPS)
            sed -i "s/listen 127\.0\.0\.1:[0-9]\+ ssl/listen 127.0.0.1:$NEW_HTTPS_NGINX ssl/" "$NGINX_CONF"
            sed -i "s/listen \[::1\]:[0-9]\+ ssl/listen [::1]:$NEW_HTTPS_NGINX ssl/" "$NGINX_CONF"
            
            # Actualizar puerto proxy_pass
            sed -i "s|proxy_pass http://127\.0\.0\.1:[0-9]\+;|proxy_pass http://127.0.0.1:$NEW_BACKEND;|" "$NGINX_CONF"
            
            log "✅ Configuración NGINX actualizada"
            
            # Si cambió el puerto backend, verificar si es un servicio WordPress
            if [ "$NEW_BACKEND" != "$BACKEND_PORT" ]; then
                if is_wordpress_service "$SELECTED_SERVICE"; then
                    log "⚠️  Detectado servicio WordPress: es necesario recrear el contenedor"
                    log "   El contenedor de Podman escucha en el puerto antiguo: $BACKEND_PORT"
                    log "   NGINX ahora apunta al nuevo puerto: $NEW_BACKEND"
                    echo ""
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "⚠️  ATENCIÓN: Recreación de contenedor requerida"
                    echo ""
                    echo "   El servicio '$SELECTED_SERVICE' es un servicio WordPress"
                    echo "   que usa contenedores de Podman."
                    echo ""
                    echo "   Para aplicar el cambio de puerto backend, se debe:"
                    echo "   1. Detener los contenedores actuales"
                    echo "   2. Recrearlos con el nuevo mapeo de puerto"
                    echo ""
                    echo "   ⏱️  Tiempo de inactividad: ~10-15 segundos"
                    echo "   💾 Los datos están en volúmenes persistentes (no se pierden)"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo ""
                    read -p "¿Recrear contenedores ahora? (s/N): " RECREATE_CONFIRM
                    
                    if [[ "$RECREATE_CONFIRM" =~ ^[sS]$ ]]; then
                        log "🔄 Recreando contenedores de WordPress..."
                        
                        # Usar función del módulo compartido
                        if recreate_wordpress_container "$SELECTED_SERVICE" "$NEW_BACKEND" "$BACKEND_PORT"; then
                            log "✅ Contenedores recreados exitosamente"
                            # Mostrar resumen de la recreación
                            show_recreation_summary "$SELECTED_SERVICE" "$BACKEND_PORT" "$NEW_BACKEND"
                        else
                            warn "⚠️  Error al recrear contenedores. Revisar logs."
                        fi
                    else
                        warn "⚠️  Contenedores NO recreados. El servicio podría no funcionar correctamente."
                        warn "   Ejecutar manualmente desde el menú de WordPress si es necesario."
                    fi
                fi
            fi
            
            # Recargar NGINX
            if nginx -t 2>/dev/null; then
                systemctl reload nginx || warn "Error al recargar nginx"
                log "✅ NGINX recargado"
            else
                warn "Configuración NGINX inválida, revierte los cambios manualmente"
            fi
        else
            warn "No se encontró configuración NGINX en $NGINX_CONF"
        fi
    fi
    
else
    die "Configuración no reconocida para el servicio $SELECTED_SERVICE (encontrados $NUM_PORTS puertos)"
fi

# ===========================
# 3. Reiniciar enola-tor
# ===========================
log "Reiniciando enola-tor.service..."
systemctl restart enola-tor || die "Error al reiniciar enola-tor"

sleep 2

if ! systemctl is-active --quiet enola-tor; then
    journalctl -u enola-tor -n 20 --no-pager
    die "enola-tor no pudo iniciar. Revisa los logs arriba."
fi

log "✅ enola-tor reiniciado correctamente"

# ===========================
# 4. Mostrar dirección onion
# ===========================
HOSTNAME_FILE="$TOR_DIR/hidden_service_${SELECTED_SERVICE}/hostname"

log "Esperando generación de hostname..."
for i in {1..30}; do
    if [ -f "$HOSTNAME_FILE" ]; then
        break
    fi
    sleep 1
done

if [ ! -f "$HOSTNAME_FILE" ]; then
    warn "El hostname aún no se ha generado. Puede tomar unos minutos."
    echo ""
    echo "Verifica más tarde con: sudo cat $HOSTNAME_FILE"
    exit 0
fi

ONION_ADDR=$(cat "$HOSTNAME_FILE")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    ✅ CONFIGURACIÓN COMPLETADA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$NUM_PORTS" -eq 1 ]; then
    if [ "$NEW_ONION" = "80" ]; then
        echo "  🌐 http://$ONION_ADDR"
    elif [ "$NEW_ONION" = "443" ]; then
        echo "  🔐 https://$ONION_ADDR"
    else
        echo "  🌐 http://$ONION_ADDR:$NEW_ONION"
    fi
else
    echo "  🌐 HTTP:  http://$ONION_ADDR"
    echo "  🔐 HTTPS: https://$ONION_ADDR"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log "🎉 Cambios aplicados exitosamente"
