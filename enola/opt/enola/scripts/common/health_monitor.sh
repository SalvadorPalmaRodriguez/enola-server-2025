#!/bin/bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HEALTH MONITOR - Enola Server
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Monitorea la salud de todos los servicios y auto-reinicia si es necesario
# Ejecutado por systemd timer cada 5 minutos
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURACIÓN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

HEALTH_LOG="/var/log/enola-server/health.log"
MAX_RESTART_ATTEMPTS=3
RESTART_COOLDOWN=300  # 5 minutos entre reintentos

# Directorio para tracking de reintentos
STATE_DIR="/var/lib/enola-server/health"
mkdir -p "$STATE_DIR"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FUNCIONES DE LOGGING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$HEALTH_LOG"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_ok() {
    log "OK" "$@"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FUNCIONES DE RESTART TRACKING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

get_restart_count() {
    local service="$1"
    local state_file="$STATE_DIR/${service}.count"
    
    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        echo "0"
    fi
}

increment_restart_count() {
    local service="$1"
    local state_file="$STATE_DIR/${service}.count"
    local count
    count=$(get_restart_count "$service")
    ((count++))
    echo "$count" > "$state_file"
}

reset_restart_count() {
    local service="$1"
    local state_file="$STATE_DIR/${service}.count"
    rm -f "$state_file"
}

get_last_restart_time() {
    local service="$1"
    local time_file="$STATE_DIR/${service}.time"
    
    if [[ -f "$time_file" ]]; then
        cat "$time_file"
    else
        echo "0"
    fi
}

set_last_restart_time() {
    local service="$1"
    local time_file="$STATE_DIR/${service}.time"
    date +%s > "$time_file"
}

can_restart() {
    local service="$1"
    local count
    local last_time
    local current_time
    local time_diff
    
    count=$(get_restart_count "$service")
    last_time=$(get_last_restart_time "$service")
    current_time=$(date +%s)
    time_diff=$((current_time - last_time))
    
    # Si han pasado más de RESTART_COOLDOWN segundos, resetear contador
    if [[ $time_diff -gt $RESTART_COOLDOWN ]]; then
        reset_restart_count "$service"
        count=0
    fi
    
    # Permitir restart si no hemos excedido el límite
    if [[ $count -lt $MAX_RESTART_ATTEMPTS ]]; then
        return 0
    else
        return 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FUNCIONES DE VERIFICACIÓN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_nginx() {
    log_info "Verificando NGINX..."
    
    # Verificar que el servicio está activo
    if ! systemctl is-active --quiet nginx; then
        log_error "NGINX no está activo"
        
        if can_restart "nginx"; then
            log_warn "Intentando reiniciar NGINX..."
            increment_restart_count "nginx"
            set_last_restart_time "nginx"
            
            if systemctl restart nginx; then
                log_ok "NGINX reiniciado exitosamente"
                return 0
            else
                log_error "Fallo al reiniciar NGINX"
                return 1
            fi
        else
            log_error "NGINX ha excedido el límite de reinicios automáticos ($MAX_RESTART_ATTEMPTS)"
            return 1
        fi
    fi
    
    # Verificar configuración
    if ! nginx -t &>/dev/null; then
        log_error "Configuración de NGINX inválida"
        return 1
    fi
    
    log_ok "NGINX está saludable"
    reset_restart_count "nginx"
    return 0
}

check_tor() {
    log_info "Verificando Tor..."
    
    # Verificar que el servicio está activo
    if ! systemctl is-active --quiet enola-tor; then
        log_error "Tor no está activo"
        
        if can_restart "tor"; then
            log_warn "Intentando reiniciar Tor..."
            increment_restart_count "tor"
            set_last_restart_time "tor"
            
            if systemctl restart enola-tor; then
                log_ok "Tor reiniciado exitosamente"
                sleep 3  # Dar tiempo a Tor para establecer circuitos
                return 0
            else
                log_error "Fallo al reiniciar Tor"
                return 1
            fi
        else
            log_error "Tor ha excedido el límite de reinicios automáticos ($MAX_RESTART_ATTEMPTS)"
            return 1
        fi
    fi
    
    # Verificar que el puerto SOCKS está escuchando
    if ! ss -tlnp | grep -q ':9050'; then
        log_warn "Puerto SOCKS de Tor (9050) no está escuchando"
        return 1
    fi
    
    log_ok "Tor está saludable"
    reset_restart_count "tor"
    return 0
}

check_wordpress_container() {
    local container_name="$1"
    
    log_info "Verificando contenedor $container_name..."
    
    # Verificar que el contenedor existe
    if ! podman container exists "$container_name"; then
        log_warn "Contenedor $container_name no existe"
        return 1
    fi
    
    # Verificar estado del contenedor
    local status
    status=$(podman inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")
    
    if [[ "$status" != "running" ]]; then
        log_error "Contenedor $container_name no está corriendo (estado: $status)"
        
        if can_restart "$container_name"; then
            log_warn "Intentando reiniciar contenedor $container_name..."
            increment_restart_count "$container_name"
            set_last_restart_time "$container_name"
            
            if podman start "$container_name"; then
                log_ok "Contenedor $container_name reiniciado exitosamente"
                return 0
            else
                log_error "Fallo al reiniciar contenedor $container_name"
                return 1
            fi
        else
            log_error "Contenedor $container_name ha excedido el límite de reinicios automáticos"
            return 1
        fi
    fi
    
    # Verificar salud del contenedor si tiene healthcheck
    local health
    health=$(podman inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")
    
    if [[ "$health" == "unhealthy" ]]; then
        log_warn "Contenedor $container_name reporta estado unhealthy"
        return 1
    fi
    
    log_ok "Contenedor $container_name está saludable"
    reset_restart_count "$container_name"
    return 0
}

check_wordpress_services() {
    log_info "Verificando servicios WordPress..."
    
    local wp_containers
    wp_containers=$(podman ps --format '{{.Names}}' | grep '^enola-.*-wp$' || true)
    
    if [[ -z "$wp_containers" ]]; then
        log_info "No hay contenedores WordPress activos"
        return 0
    fi
    
    local all_healthy=0
    
    while IFS= read -r container; do
        if ! check_wordpress_container "$container"; then
            all_healthy=1
        fi
        
        # Verificar también el contenedor MySQL asociado
        local mysql_container
        mysql_container="${container/-wp/-mysql}"
        
        if podman container exists "$mysql_container"; then
            if ! check_wordpress_container "$mysql_container"; then
                all_healthy=1
            fi
        fi
    done <<< "$wp_containers"
    
    return $all_healthy
}

check_systemd_wordpress_services() {
    log_info "Verificando servicios systemd de WordPress..."
    
    local wp_services
    wp_services=$(systemctl list-units --type=service --state=running --no-legend | grep '^container-enola-.*-wp.service' | awk '{print $1}' || true)
    
    if [[ -z "$wp_services" ]]; then
        log_info "No hay servicios systemd de WordPress activos"
        return 0
    fi
    
    local all_healthy=0
    
    while IFS= read -r service; do
        if ! systemctl is-active --quiet "$service"; then
            log_error "Servicio $service no está activo"
            
            if can_restart "$service"; then
                log_warn "Intentando reiniciar servicio $service..."
                increment_restart_count "$service"
                set_last_restart_time "$service"
                
                if systemctl restart "$service"; then
                    log_ok "Servicio $service reiniciado exitosamente"
                else
                    log_error "Fallo al reiniciar servicio $service"
                    all_healthy=1
                fi
            else
                log_error "Servicio $service ha excedido el límite de reinicios automáticos"
                all_healthy=1
            fi
        fi
    done <<< "$wp_services"
    
    return $all_healthy
}

check_ports() {
    log_info "Verificando puertos críticos..."
    
    local critical_ports=(
        "9050:Tor SOCKS"
    )
    
    local all_ok=0
    
    for port_info in "${critical_ports[@]}"; do
        local port="${port_info%%:*}"
        local service="${port_info#*:}"
        
        if ! ss -tlnp | grep -q ":${port}\b"; then
            log_warn "Puerto $port ($service) no está escuchando"
            all_ok=1
        fi
    done
    
    if [[ $all_ok -eq 0 ]]; then
        log_ok "Todos los puertos críticos están escuchando"
    fi
    
    return $all_ok
}

check_disk_space() {
    log_info "Verificando espacio en disco..."
    
    local usage
    usage=$(df /var/lib/podman 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' || echo "0")
    
    if [[ $usage -gt 90 ]]; then
        log_error "Espacio en disco crítico: ${usage}% usado en /var/lib/podman"
        return 1
    elif [[ $usage -gt 80 ]]; then
        log_warn "Espacio en disco alto: ${usage}% usado en /var/lib/podman"
        return 1
    fi
    
    log_ok "Espacio en disco OK: ${usage}% usado"
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Iniciando verificación de salud de Enola Server"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local exit_code=0
    
    # Verificar NGINX
    if ! check_nginx; then
        exit_code=1
    fi
    
    # Verificar Tor
    if ! check_tor; then
        exit_code=1
    fi
    
    # Verificar contenedores WordPress
    if ! check_wordpress_services; then
        exit_code=1
    fi
    
    # Verificar servicios systemd de WordPress
    if ! check_systemd_wordpress_services; then
        exit_code=1
    fi
    
    # Verificar puertos
    if ! check_ports; then
        exit_code=1
    fi
    
    # Verificar espacio en disco
    if ! check_disk_space; then
        exit_code=1
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_ok "✅ Verificación de salud completada: TODOS LOS SERVICIOS OK"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_warn "⚠️  Verificación de salud completada: SE DETECTARON PROBLEMAS"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
    
    return $exit_code
}

# Ejecutar
main "$@"
