#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

# ============================================================================
# NUEVO MENÚ ENOLA SERVER - REDISEÑO UX/UI
# Versión: 2.0
# Objetivo: Máxima claridad e intuición para usuarios no técnicos
# ============================================================================

# Modo no interactivo: ejecutar smoke test y salir
if [[ "${1:-}" == "--smoke" || "${1:-}" == "--health" ]]; then
    SMOKE="/opt/enola/scripts/common/smoke_test.sh"
    if [[ -x "$SMOKE" ]]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo bash "$SMOKE" || true
        else
            bash "$SMOKE" || true
        fi
        exit 0
    else
        echo "Smoke test no encontrado en $SMOKE" >&2
        exit 1
    fi
fi

# --------------------------------------------------------------------
# COLORES
# --------------------------------------------------------------------
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
NC="\033[0m"

# --------------------------------------------------------------------
# CARGAR SISTEMA DE AYUDA
# --------------------------------------------------------------------
HELP_SYSTEM="/opt/enola/scripts/common/help_system.sh"
if [ -f "$HELP_SYSTEM" ]; then
    source "$HELP_SYSTEM"
fi

# --------------------------------------------------------------------
# FUNCIONES AUXILIARES
# --------------------------------------------------------------------

show_success() {
    echo -e "${GREEN}✅ ${1}${NC}"
}

show_error() {
    echo -e "${RED}❌ ${1}${NC}"
}

show_warning() {
    echo -e "${YELLOW}⚠️  ${1}${NC}"
}

show_info() {
    echo -e "${CYAN}ℹ️  ${1}${NC}"
}

# Breadcrumbs de navegación
show_breadcrumb() {
    echo -e "${CYAN}📍 ${1}${NC}"
    echo ""
}

# Instrucciones breves en cada pantalla
show_instructions() {
    echo -e "${YELLOW}💡 ${1}${NC}"
    echo ""
}

# Confirmación para acciones críticas
confirm_action() {
    local message="$1"
    local default="${2:-N}"
    local prompt
    
    if [[ "$default" == "Y" ]]; then
        prompt="[S/n]"
    else
        prompt="[s/N]"
    fi
    
    echo -e "${YELLOW}⚠️  ${message}${NC}"
    read -p "¿Continuar? $prompt " response
    response=${response:-$default}
    
    case "$response" in
        [Yy]|[Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

# Mini-dashboard de estado
show_status_dashboard() {
    local nginx_status="❌ Parado"
    local tor_status="❌ Parado"
    local wp_status="❌ Sin sitios"
    
    if systemctl is-active --quiet nginx 2>/dev/null; then
        nginx_status="✅ Activo"
    fi
    
    if systemctl is-active --quiet tor 2>/dev/null || systemctl is-active --quiet enola-tor 2>/dev/null; then
        tor_status="✅ Activo"
    fi
    
    if command -v podman >/dev/null 2>&1; then
        local running_wp=$(sudo podman ps --filter "name=enola-.*-wp" --format "{{.Names}}" 2>/dev/null | wc -l)
        if [[ $running_wp -gt 0 ]]; then
            wp_status="✅ $running_wp sitio(s) activo(s)"
        fi
    fi
    
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${CYAN}Estado del Sistema:${NC}"
    echo -e "  • Servidor Web (NGINX): ${nginx_status}"
    echo -e "  • Red Tor:              ${tor_status}"
    echo -e "  • WordPress:            ${wp_status}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Banner principal
show_banner() {
    clear
    VERSION_FILE="/opt/enola/VERSION"
    if [[ -f "$VERSION_FILE" ]]; then
        VERSION_INFO=$(cat "$VERSION_FILE")
    else
        VERSION_INFO="Desconocida"
    fi

    cat <<'EOF'
                     .__                                                   
  ____   ____   ____ |  | _____      ______ ______________  __ ___________ 
_/ __ \ /    \ /  _ \|  | \__  \    /  ___// __ \_  __ \  \/ // __ \_  __ \
\  ___/|   |  (  <_> )  |__/ __ \_  \___ \\  ___/|  | \/\   /\  ___/|  | \/
 \___  >___|  /\____/|____(____  / /____  >\___  >__|    \_/  \___  >__|   
     \/     \/                 \/       \/     \/                 \/                                                                                                           
===========================================================================                                                                     
EOF

    echo -e "                 ${CYAN}ENOLA SERVER${NC}"
    echo -e "              ${YELLOW}Versión:${NC} ${GREEN}${VERSION_INFO}${NC}"
    echo "==========================================================================="
    echo
}

# Esperar tecla
wait_key() {
    echo ""
    read -p "Pulsa Enter para continuar..."
}

# ============================================================================
# MENÚ PRINCIPAL
# ============================================================================
show_main_menu() {
    local first_run=true
    while true; do
        clear
        if $first_run; then
            show_banner
            show_status_dashboard
            first_run=false
        else
            show_banner
            show_status_dashboard
        fi

        echo -e "${BOLD}¿Qué quieres hacer?${NC}"
        echo ""
        echo "  1)  📝 Gestionar mi sitio WordPress"
        echo "  2)  🌐 Crear o gestionar un servicio web anónimo (.onion)"
        echo "  3)  🔧 Mantenimiento y estado del sistema"
        echo "  4)  🩺 Diagnóstico y ayuda"
        echo ""
        echo "  q)  Salir"
        echo ""
        show_instructions "Pulsa el número de la opción (sin Enter)"
        
        read -n1 -s choice
        echo ""
        
        case "$choice" in
            1) show_wordpress_menu ;;
            2) show_services_menu ;;
            3) show_maintenance_menu ;;
            4) show_diagnostics_menu ;;
            q|Q) break ;;
            h|H)
                if type handle_help_key >/dev/null 2>&1; then
                    handle_help_key "main_menu" "$choice"
                fi
                ;;
            *) 
                show_error "Opción no válida"
                sleep 1
                ;;
        esac
    done
    clear
    echo "¡Hasta pronto!"
    exit 0
}

# ============================================================================
# MENÚ WORDPRESS
# ============================================================================
show_wordpress_menu() {
    while true; do
        clear
        show_breadcrumb "Inicio → WordPress"
        
        echo -e "${BOLD}Gestión de tu sitio WordPress${NC}"
        echo ""
        echo "  1)  ➕ Crear un nuevo sitio WordPress"
        echo "  2)  ✏️  Editar configuración de un sitio existente"
        echo "  3)  ▶️  Iniciar, parar o reiniciar WordPress"
        echo "  4)  👁️  Publicar u ocultar WordPress en Tor"
        echo ""
        echo "  0)  ← Volver al menú principal"
        echo ""
        show_instructions "Pulsa el número de la opción"
        
        read -n1 -s wp_choice
        echo ""

        case "$wp_choice" in
            1)
                clear
                show_breadcrumb "Inicio → WordPress → Crear nuevo sitio"
                show_info "Vamos a crear un nuevo sitio WordPress..."
                if [ -f "/opt/enola/scripts/wordpress/generate_wordpress.sh" ]; then
                    sudo bash "/opt/enola/scripts/wordpress/generate_wordpress.sh" || show_error "Error al crear el sitio"
                else
                    show_error "Script de instalación no encontrado"
                fi
                wait_key
                ;;
            2)
                clear
                show_breadcrumb "Inicio → WordPress → Editar configuración"
                show_info "Editando configuración de WordPress..."
                if [ -f "/opt/enola/scripts/wordpress/edit_wordpress.sh" ]; then
                    sudo bash "/opt/enola/scripts/wordpress/edit_wordpress.sh" || show_error "Error al editar"
                else
                    show_error "Script de edición no encontrado"
                fi
                wait_key
                ;;
            3) show_wordpress_control_menu ;;
            4) show_wordpress_visibility_menu ;;
            0) break ;;
            h|H)
                if type handle_help_key >/dev/null 2>&1; then
                    handle_help_key "wordpress_menu" "$wp_choice"
                fi
                ;;
            *) 
                show_error "Opción no válida"
                sleep 1
                ;;
        esac
    done
}

# --------------------------------------------------------------------
# SUBMENÚ: Control de WordPress (Iniciar/Parar/Reiniciar)
# --------------------------------------------------------------------
show_wordpress_control_menu() {
    while true; do
        clear
        show_breadcrumb "Inicio → WordPress → Control de estado"
        
        echo -e "${BOLD}Controla el estado de tu WordPress${NC}"
        echo ""
        echo "  1)  ▶️  Iniciar WordPress"
        echo "  2)  ⏹️  Parar WordPress"
        echo "  3)  🔄 Reiniciar WordPress"
        echo "  4)  📊 Ver estado actual"
        echo ""
        echo "  0)  ← Volver"
        echo ""
        show_instructions "Pulsa el número de la opción"
        
        read -n1 -s ctrl_choice
        echo ""

        case "$ctrl_choice" in
            1)
                clear
                show_info "Iniciando WordPress..."
                if [ -f "/opt/enola/scripts/wordpress/toggle_wordpress.sh" ]; then
                    sudo bash "/opt/enola/scripts/wordpress/toggle_wordpress.sh" start || show_error "Error al iniciar"
                else
                    show_error "Script no encontrado"
                fi
                wait_key
                ;;
            2)
                clear
                show_info "Parando WordPress..."
                if [ -f "/opt/enola/scripts/wordpress/toggle_wordpress.sh" ]; then
                    sudo bash "/opt/enola/scripts/wordpress/toggle_wordpress.sh" stop || show_error "Error al parar"
                else
                    show_error "Script no encontrado"
                fi
                wait_key
                ;;
            3)
                clear
                show_info "Reiniciando WordPress..."
                if [ -f "/opt/enola/scripts/wordpress/toggle_wordpress.sh" ]; then
                    sudo bash "/opt/enola/scripts/wordpress/toggle_wordpress.sh" restart || show_error "Error al reiniciar"
                else
                    show_error "Script no encontrado"
                fi
                wait_key
                ;;
            4)
                clear
                show_info "Estado actual de WordPress:"
                echo ""
                if [ -f "/opt/enola/scripts/wordpress/toggle_wordpress.sh" ]; then
                    sudo bash "/opt/enola/scripts/wordpress/toggle_wordpress.sh" status || true
                else
                    show_error "Script no encontrado"
                fi
                wait_key
                ;;
            0) break ;;
            *) 
                show_error "Opción no válida"
                sleep 1
                ;;
        esac
    done
}

# --------------------------------------------------------------------
# SUBMENÚ: Visibilidad de WordPress en Tor
# --------------------------------------------------------------------
show_wordpress_visibility_menu() {
    while true; do
        clear
        show_breadcrumb "Inicio → WordPress → Publicar/Ocultar en Tor"
        
        echo -e "${BOLD}Controla la visibilidad de tu WordPress en la red Tor${NC}"
        echo ""
        echo "  1)  👁️  Publicar WordPress (visible en Tor)"
        echo "  2)  🙈 Ocultar WordPress (no visible en Tor)"
        echo ""
        echo "  0)  ← Volver"
        echo ""
        show_instructions "Pulsa el número de la opción"
        
        read -n1 -s vis_choice
        echo ""

        case "$vis_choice" in
            1)
                clear
                show_info "Publicando WordPress en Tor..."
                if [ -f "/opt/enola/scripts/wordpress/enable_wordpress.sh" ]; then
                    sudo bash "/opt/enola/scripts/wordpress/enable_wordpress.sh" || show_error "Error al publicar"
                else
                    show_error "Script no encontrado"
                fi
                wait_key
                ;;
            2)
                clear
                if confirm_action "¿Seguro que quieres ocultar WordPress? No será accesible desde Tor."; then
                    show_info "Ocultando WordPress..."
                    if [ -f "/opt/enola/scripts/wordpress/disable_wordpress.sh" ]; then
                        sudo bash "/opt/enola/scripts/wordpress/disable_wordpress.sh" || show_error "Error al ocultar"
                    else
                        show_error "Script no encontrado"
                    fi
                else
                    show_warning "Operación cancelada"
                fi
                wait_key
                ;;
            0) break ;;
            *) 
                show_error "Opción no válida"
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# MENÚ SERVICIOS WEB ANÓNIMOS (.onion)
# ============================================================================
show_services_menu() {
    while true; do
        clear
        show_breadcrumb "Inicio → Servicios Web Anónimos"
        
        echo -e "${BOLD}Gestión de servicios web anónimos (.onion)${NC}"
        echo ""
        echo "  1)  ➕ Crear nuevo servicio web anónimo"
        echo "  2)  ✏️  Editar puertos y configuración"
        echo "  3)  👁️  Activar o desactivar un servicio"
        echo "  4)  🗑️  Eliminar un servicio"
        echo ""
        echo "  0)  ← Volver al menú principal"
        echo ""
        show_instructions "Pulsa el número de la opción"
        
        read -n1 -s srv_choice
        echo ""

        case "$srv_choice" in
            1)
                clear
                show_breadcrumb "Inicio → Servicios → Crear nuevo servicio"
                show_info "Creando un nuevo servicio web anónimo (.onion)..."
                if [ -f "/opt/enola/scripts/tor/deploy_tor_web.sh" ]; then
                    sudo bash "/opt/enola/scripts/tor/deploy_tor_web.sh" || show_error "Error al crear el servicio"
                else
                    show_error "Script no encontrado"
                fi
                wait_key
                ;;
            2)
                clear
                show_breadcrumb "Inicio → Servicios → Editar puertos"
                show_info "Editando puertos y configuración..."
                if [ -f "/opt/enola/scripts/config/edit_ports.sh" ]; then
                    sudo bash "/opt/enola/scripts/config/edit_ports.sh" || show_error "Error al editar"
                else
                    show_error "Script no encontrado"
                fi
                wait_key
                ;;
            3) show_services_toggle_menu ;;
            4) show_services_remove_menu ;;
            0) break ;;
            *) 
                show_error "Opción no válida"
                sleep 1
                ;;
        esac
    done
}

# --------------------------------------------------------------------
# SUBMENÚ: Activar/Desactivar servicios
# --------------------------------------------------------------------
show_services_toggle_menu() {
    while true; do
        clear
        show_breadcrumb "Inicio → Servicios → Activar/Desactivar"
        
        echo -e "${BOLD}Activa o desactiva tus servicios web anónimos${NC}"
        echo ""
        echo "  1)  ✅ Activar un servicio"
        echo "  2)  ✅ Activar varios servicios"
        echo "  3)  ❌ Desactivar un servicio"
        echo "  4)  ❌ Desactivar varios servicios"
        echo ""
        echo "  0)  ← Volver"
        echo ""
        show_instructions "Pulsa el número de la opción"
        
        read -n1 -s toggle_choice
        echo ""

        case "$toggle_choice" in
            1)
                clear
                show_info "Activando servicio..."
                if [ -f "/opt/enola/scripts/services/enable/enable_service.sh" ]; then
                    sudo bash "/opt/enola/scripts/services/enable/enable_service.sh" || show_error "Error"
                else
                    show_error "Script no encontrado"
                fi
                wait_key
                ;;
            2)
                clear
                show_info "Activando varios servicios..."
                if [ -f "/opt/enola/scripts/services/enable/enable_service_multi.sh" ]; then
                    sudo bash "/opt/enola/scripts/services/enable/enable_service_multi.sh" || show_error "Error"
                else
                    show_error "Script no encontrado"
                fi
                wait_key
                ;;
            3)
                clear
                show_info "Desactivando servicio..."
                if [ -f "/opt/enola/scripts/services/disable/disable_service.sh" ]; then
                    sudo bash "/opt/enola/scripts/services/disable/disable_service.sh" || show_error "Error"
                else
                    show_error "Script no encontrado"
                fi
                wait_key
                ;;
            4)
                clear
                show_info "Desactivando varios servicios..."
                if [ -f "/opt/enola/scripts/services/disable/disable_service_multi.sh" ]; then
                    sudo bash "/opt/enola/scripts/services/disable/disable_service_multi.sh" || show_error "Error"
                else
                    show_error "Script no encontrado"
                fi
                wait_key
                ;;
            0) break ;;
            *) 
                show_error "Opción no válida"
                sleep 1
                ;;
        esac
    done
}

# --------------------------------------------------------------------
# SUBMENÚ: Eliminar servicios
# --------------------------------------------------------------------
show_services_remove_menu() {
    while true; do
        clear
        show_breadcrumb "Inicio → Servicios → Eliminar"
        
        echo -e "${BOLD}Eliminar servicios web anónimos${NC}"
        echo -e "${RED}⚠️  ¡Atención! Esta acción no se puede deshacer.${NC}"
        echo ""
        echo "  1)  🗑️  Eliminar un servicio"
        echo "  2)  🗑️  Eliminar varios servicios"
        echo ""
        echo "  0)  ← Volver"
        echo ""
        show_instructions "Pulsa el número de la opción"
        
        read -n1 -s rm_choice
        echo ""

        case "$rm_choice" in
            1)
                clear
                if confirm_action "¿Seguro que quieres eliminar un servicio? Esta acción NO se puede deshacer."; then
                    show_info "Eliminando servicio..."
                    if [ -f "/opt/enola/scripts/services/remove/remove_service.sh" ]; then
                        sudo bash "/opt/enola/scripts/services/remove/remove_service.sh" || show_error "Error"
                    else
                        show_error "Script no encontrado"
                    fi
                else
                    show_warning "Operación cancelada"
                fi
                wait_key
                ;;
            2)
                clear
                if confirm_action "¿Seguro que quieres eliminar varios servicios? Esta acción NO se puede deshacer."; then
                    show_info "Eliminando servicios..."
                    if [ -f "/opt/enola/scripts/services/remove/remove_service_multi.sh" ]; then
                        sudo bash "/opt/enola/scripts/services/remove/remove_service_multi.sh" || show_error "Error"
                    else
                        show_error "Script no encontrado"
                    fi
                else
                    show_warning "Operación cancelada"
                fi
                wait_key
                ;;
            0) break ;;
            *) 
                show_error "Opción no válida"
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# MENÚ MANTENIMIENTO
# ============================================================================
show_maintenance_menu() {
    while true; do
        clear
        show_breadcrumb "Inicio → Mantenimiento"
        
        echo -e "${BOLD}Mantenimiento y estado del sistema${NC}"
        echo ""
        echo "  1)  📊 Ver estado general del sistema"
        echo "  2)  🩺 Ejecutar comprobación de salud (smoke test)"
        echo "  3)  ⏰ Programar comprobaciones automáticas"
        echo "  4)  🔐 Configurar comprobación de SSH"
        echo ""
        echo "  0)  ← Volver al menú principal"
        echo ""
        show_instructions "Pulsa el número de la opción"
        
        read -n1 -s mnt_choice
        echo ""

        case "$mnt_choice" in
            1)
                clear
                show_breadcrumb "Inicio → Mantenimiento → Estado general"
                echo -e "${BOLD}Estado general del sistema:${NC}"
                echo ""
                bash /opt/enola/scripts/common/status_nginx.sh 2>/dev/null || true
                echo "────────────────────────────────────────"
                bash /opt/enola/scripts/tor/list_services.sh 2>/dev/null || true
                echo "────────────────────────────────────────"
                bash /opt/enola/scripts/common/status_ssh.sh 2>/dev/null || true
                echo "────────────────────────────────────────"
                bash /opt/enola/scripts/common/status_wordpress.sh 2>/dev/null || true
                wait_key
                ;;
            2)
                clear
                show_breadcrumb "Inicio → Mantenimiento → Comprobación de salud"
                echo -e "${BOLD}Ejecutando comprobación de salud (smoke test)...${NC}"
                echo ""
                if [ -f "/opt/enola/scripts/common/smoke_test.sh" ]; then
                    sudo bash "/opt/enola/scripts/common/smoke_test.sh" || true
                else
                    show_error "Script no encontrado"
                fi
                wait_key
                ;;
            3) show_maintenance_timer_menu ;;
            4)
                clear
                show_breadcrumb "Inicio → Mantenimiento → Configurar SSH"
                show_info "Configurando comprobación de SSH..."
                if [ -f "/opt/enola/scripts/config/toggle_ssh_check.sh" ]; then
                    sudo bash "/opt/enola/scripts/config/toggle_ssh_check.sh" || show_error "Error"
                else
                    show_error "Script no encontrado"
                fi
                wait_key
                ;;
            0) break ;;
            *) 
                show_error "Opción no válida"
                sleep 1
                ;;
        esac
    done
}

# --------------------------------------------------------------------
# SUBMENÚ: Programar comprobaciones automáticas
# --------------------------------------------------------------------
show_maintenance_timer_menu() {
    while true; do
        clear
        show_breadcrumb "Inicio → Mantenimiento → Comprobaciones automáticas"
        
        # Estado actual del timer
        local timer_state="${RED}Desactivado${NC}"
        if command -v systemctl >/dev/null 2>&1; then
            if systemctl is-enabled --quiet enola-smoke.timer 2>/dev/null; then
                timer_state="${GREEN}Activado${NC}"
            fi
        fi
        
        echo -e "${BOLD}Comprobaciones automáticas de salud${NC}"
        echo ""
        echo -e "  Estado actual: ${timer_state}"
        echo ""
        echo "  1)  ✅ Activar comprobaciones automáticas"
        echo "  2)  ❌ Desactivar comprobaciones automáticas"
        echo "  3)  📊 Ver estado del programador"
        echo ""
        echo "  0)  ← Volver"
        echo ""
        show_instructions "Pulsa el número de la opción"
        
        read -n1 -s timer_choice
        echo ""

        case "$timer_choice" in
            1)
                clear
                show_info "Activando comprobaciones automáticas..."
                if [ -f "/opt/enola/scripts/config/toggle_smoke_test.sh" ]; then
                    sudo bash "/opt/enola/scripts/config/toggle_smoke_test.sh" enable || show_error "Error"
                else
                    sudo systemctl enable --now enola-smoke.timer 2>/dev/null && show_success "Activado" || show_error "Error"
                fi
                wait_key
                ;;
            2)
                clear
                show_info "Desactivando comprobaciones automáticas..."
                if [ -f "/opt/enola/scripts/config/toggle_smoke_test.sh" ]; then
                    sudo bash "/opt/enola/scripts/config/toggle_smoke_test.sh" disable || show_error "Error"
                else
                    sudo systemctl disable --now enola-smoke.timer 2>/dev/null && show_success "Desactivado" || show_error "Error"
                fi
                wait_key
                ;;
            3)
                clear
                show_info "Estado del programador:"
                echo ""
                systemctl status enola-smoke.timer --no-pager 2>&1 || echo "Timer no disponible"
                wait_key
                ;;
            0) break ;;
            *) 
                show_error "Opción no válida"
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# MENÚ DIAGNÓSTICO
# ============================================================================
show_diagnostics_menu() {
    # Helper para ver logs
    view_log() {
        local file="$1"
        echo -e "\n${CYAN}── $file (últimas 100 líneas) ──${NC}\n"
        if [[ -r "$file" ]]; then
            tail -n 100 "$file" || true
        elif command -v sudo >/dev/null 2>&1 && sudo -n test -r "$file" 2>/dev/null; then
            sudo -n tail -n 100 "$file" || true
        else
            echo "No hay permisos para leer $file"
        fi
        echo -e "\n${CYAN}── fin ──${NC}\n"
    }

    while true; do
        clear
        show_breadcrumb "Inicio → Diagnóstico"
        
        echo -e "${BOLD}Diagnóstico y ayuda${NC}"
        echo ""
        echo "  1)  📊 Resumen rápido de todos los servicios"
        echo "  2)  🌐 Ver detalles de NGINX"
        echo "  3)  🧅 Ver detalles de Tor"
        echo "  4)  🔐 Ver detalles de SSH"
        echo "  5)  📝 Ver detalles de WordPress"
        echo "  6)  🔄 Ver sincronización WordPress/NGINX"
        echo "  7)  ✅ Probar configuración de NGINX"
        echo "  8)  📄 Ver logs del sistema"
        echo ""
        echo "  0)  ← Volver al menú principal"
        echo ""
        show_instructions "Pulsa el número de la opción"
        
        read -n1 -s diag_choice
        echo ""

        case "$diag_choice" in
            1)
                clear
                show_breadcrumb "Inicio → Diagnóstico → Resumen"
                echo -e "${BOLD}Resumen de todos los servicios:${NC}"
                echo ""
                bash /opt/enola/scripts/common/status_nginx.sh 2>/dev/null || true
                echo "────────────────────────────────────────"
                bash /opt/enola/scripts/tor/list_services.sh 2>/dev/null || true
                echo "────────────────────────────────────────"
                bash /opt/enola/scripts/common/status_ssh.sh 2>/dev/null || true
                echo "────────────────────────────────────────"
                bash /opt/enola/scripts/common/status_wordpress.sh 2>/dev/null || true
                wait_key
                ;;
            2)
                clear
                show_breadcrumb "Inicio → Diagnóstico → NGINX"
                bash /opt/enola/scripts/common/status_nginx.sh 2>/dev/null || true
                wait_key
                ;;
            3)
                clear
                show_breadcrumb "Inicio → Diagnóstico → Tor"
                bash /opt/enola/scripts/tor/list_services.sh 2>/dev/null || true
                wait_key
                ;;
            4)
                clear
                show_breadcrumb "Inicio → Diagnóstico → SSH"
                bash /opt/enola/scripts/common/status_ssh.sh 2>/dev/null || true
                wait_key
                ;;
            5)
                clear
                show_breadcrumb "Inicio → Diagnóstico → WordPress"
                bash /opt/enola/scripts/common/status_wordpress.sh 2>/dev/null || true
                wait_key
                ;;
            6)
                clear
                show_breadcrumb "Inicio → Diagnóstico → Sincronización"
                if [ -f "/opt/enola/scripts/wordpress/wordpress_status.sh" ]; then
                    bash /opt/enola/scripts/wordpress/wordpress_status.sh 2>/dev/null || true
                else
                    show_error "Script no encontrado"
                fi
                wait_key
                ;;
            7)
                clear
                show_breadcrumb "Inicio → Diagnóstico → Probar NGINX"
                echo -e "${BOLD}Probando configuración de NGINX...${NC}"
                echo ""
                if command -v nginx >/dev/null 2>&1; then
                    sudo nginx -t 2>&1
                else
                    show_error "NGINX no está instalado"
                fi
                wait_key
                ;;
            8) show_logs_menu ;;
            0) break ;;
            h|H)
                if type handle_help_key >/dev/null 2>&1; then
                    handle_help_key "diagnostics_menu" "$diag_choice"
                fi
                ;;
            *) 
                show_error "Opción no válida"
                sleep 1
                ;;
        esac
    done
}

# --------------------------------------------------------------------
# SUBMENÚ: Ver logs
# --------------------------------------------------------------------
show_logs_menu() {
    view_log() {
        local file="$1"
        echo -e "\n${CYAN}── $file (últimas 100 líneas) ──${NC}\n"
        if [[ -r "$file" ]]; then
            tail -n 100 "$file" || true
        elif command -v sudo >/dev/null 2>&1; then
            sudo tail -n 100 "$file" 2>/dev/null || echo "No se puede leer el archivo"
        else
            echo "No hay permisos para leer $file"
        fi
        echo -e "\n${CYAN}── fin ──${NC}\n"
    }

    while true; do
        clear
        show_breadcrumb "Inicio → Diagnóstico → Logs"
        
        echo -e "${BOLD}Logs del sistema${NC}"
        echo ""
        echo "  1)  📄 Log de instalación (postinst)"
        echo "  2)  📄 Log del smoke test (instalación)"
        echo "  3)  📄 Log del smoke test (programado)"
        echo ""
        echo "  0)  ← Volver"
        echo ""
        show_instructions "Pulsa el número de la opción"
        
        read -n1 -s log_choice
        echo ""

        case "$log_choice" in
            1)
                clear
                view_log "/var/log/enola-server/postinst.log"
                wait_key
                ;;
            2)
                clear
                view_log "/var/log/enola-server/smoke_postinst.log"
                wait_key
                ;;
            3)
                clear
                view_log "/var/log/enola-server/smoke_timer.log"
                wait_key
                ;;
            0) break ;;
            *) 
                show_error "Opción no válida"
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# INICIO DEL PROGRAMA
# ============================================================================
show_main_menu
