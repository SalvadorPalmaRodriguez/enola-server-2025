#!/bin/bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Script para mostrar estado de servicios WordPress

WORDPRESS_UTILS="/opt/enola/scripts/wordpress/wordpress_utils.sh"

# Importar utilidades
source "$WORDPRESS_UTILS" || { echo "Error: No se pudo cargar wordpress_utils.sh"; exit 1; }

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para obtener puerto NGINX de un servicio
get_nginx_backend_port() {
    local service_name="$1"
    local nginx_conf="/etc/nginx/sites-available/${service_name}.conf"
    
    if [ ! -f "$nginx_conf" ]; then
        echo ""
        return 1
    fi
    
    sudo grep "proxy_pass" "$nginx_conf" 2>/dev/null | grep -oP 'http://127\.0\.0\.1:\K\d+' | head -1
}

# Función para verificar si contenedor está corriendo
is_container_running() {
    local container_name="$1"
    sudo podman ps --filter "name=${container_name}" --format "{{.Status}}" 2>/dev/null | grep -q "Up"
}

# Función para verificar respuesta HTTP
check_http_response() {
    local port="$1"
    local response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 http://127.0.0.1:${port} 2>/dev/null)
    echo "$response"
}

# Función principal de reporte
show_wordpress_status() {
    local detailed="${1:-false}"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║         ESTADO DE SERVICIOS WORDPRESS                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Buscar servicios WordPress
    local services=()
    shopt -s nullglob
    for f in /opt/enola/wordpress/*.env; do
        [ -f "$f" ] || continue
        services+=("$(basename "$f" .env)")
    done
    shopt -u nullglob
    
    if [ ${#services[@]} -eq 0 ]; then
        echo "⚠️  No hay servicios WordPress configurados"
        echo ""
        return 0
    fi
    
    echo "📊 SERVICIOS DETECTADOS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local all_synced=true
    local results=()
    
    for service in "${services[@]}"; do
        local nginx_port=$(get_nginx_backend_port "$service")
        local container_port=$(get_wordpress_backend_port "$service")
        local container_name="enola-${service}-wp"
        local status_icon="❓"
        local status_text="DESCONOCIDO"
        local http_code=""
        
        # Verificar sincronización
        if [ -n "$nginx_port" ] && [ -n "$container_port" ]; then
            if [ "$nginx_port" = "$container_port" ]; then
                # Verificar si contenedor está corriendo
                if is_container_running "$container_name"; then
                    http_code=$(check_http_response "$container_port")
                    if [ "$http_code" = "302" ] || [ "$http_code" = "200" ]; then
                        status_icon="✅"
                        status_text="OK"
                    else
                        status_icon="⚠️ "
                        status_text="RESPONDE PERO HTTP $http_code"
                        all_synced=false
                    fi
                else
                    status_icon="❌"
                    status_text="CONTENEDOR DETENIDO"
                    all_synced=false
                fi
            else
                status_icon="❌"
                status_text="DESINCRONIZADO"
                all_synced=false
            fi
        elif [ -z "$container_port" ]; then
            status_icon="❌"
            status_text="CONTENEDOR NO EXISTE"
            all_synced=false
        else
            status_icon="⚠️ "
            status_text="CONFIG NGINX FALTANTE"
            all_synced=false
        fi
        
        # Guardar resultado
        results+=("$service|$nginx_port|$container_port|$status_icon|$status_text|$http_code")
    done
    
    # Mostrar tabla
    printf "┌─────────────┬──────────────┬────────────────┬─────────────────────────┐\n"
    printf "│ %-11s │ %-12s │ %-14s │ %-23s │\n" "Servicio" "NGINX Puerto" "Contenedor" "Estado"
    printf "├─────────────┼──────────────┼────────────────┼─────────────────────────┤\n"
    
    for result in "${results[@]}"; do
        IFS='|' read -r service nginx_port container_port status_icon status_text http_code <<< "$result"
        
        # Formatear puertos
        nginx_display="${nginx_port:-N/A}"
        container_display="${container_port:-N/A}"
        
        printf "│ %-11s │ %-12s │ %-14s │ %s %-20s │\n" \
            "$service" "$nginx_display" "$container_display" "$status_icon" "$status_text"
    done
    
    printf "└─────────────┴──────────────┴────────────────┴─────────────────────────┘\n"
    
    echo ""
    echo "🔍 RESUMEN"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if $all_synced; then
        echo -e "${GREEN}✅ Todos los servicios WordPress están sincronizados y funcionando${NC}"
    else
        echo -e "${YELLOW}⚠️  Algunos servicios tienen problemas de sincronización${NC}"
        echo ""
        echo "💡 Soluciones:"
        echo "   • Para servicios desincronizados: Editar puertos desde el menú"
        echo "   • Para contenedores detenidos: Iniciar desde menú WordPress"
        echo "   • Para contenedores inexistentes: Regenerar servicio"
    fi
    
    # Mostrar detalles adicionales si se solicita
    if [ "$detailed" = "true" ]; then
        echo ""
        echo "📋 DETALLES ADICIONALES"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        for service in "${services[@]}"; do
            local container_name="enola-${service}-wp"
            local db_container="enola-${service}-mysql"
            
            echo ""
            echo "📦 Servicio: $service"
            echo "   Contenedor WP:    $container_name"
            echo "   Contenedor DB:    $db_container"
            
            # Estado real del contenedor vs systemd
            local real_status=$(podman inspect --format '{{.State.Status}}' "$container_name" 2>/dev/null || echo "missing")
            local systemd_active=false
            systemctl is-active --quiet "container-${container_name}.service" 2>/dev/null && systemd_active=true
            
            # Mostrar estado con detección de desincronización
            if [ "$systemd_active" = true ] && [ "$real_status" != "running" ]; then
                echo -e "   Systemd WP:       ${YELLOW}⚠️  Active (desincronizado: contenedor $real_status)${NC}"
            elif [ "$systemd_active" = true ]; then
                echo -e "   Systemd WP:       ${GREEN}✅ Active${NC}"
            else
                echo -e "   Systemd WP:       ${RED}❌ Inactive${NC}"
            fi
            
            # Volúmenes
            local volumes=$(sudo podman inspect "$container_name" --format '{{range .Mounts}}{{.Name}} {{end}}' 2>/dev/null)
            if [ -n "$volumes" ]; then
                echo "   Volúmenes:        $volumes"
            fi
        done
    fi
    
    echo ""
}

# Script principal
case "${1:-}" in
    --detailed|-d)
        show_wordpress_status "true"
        ;;
    --help|-h)
        echo "Uso: $0 [opciones]"
        echo ""
        echo "Opciones:"
        echo "  (ninguna)      Mostrar estado básico"
        echo "  --detailed, -d Mostrar información detallada"
        echo "  --help, -h     Mostrar esta ayuda"
        echo ""
        ;;
    *)
        show_wordpress_status "false"
        ;;
esac
