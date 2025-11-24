#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

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

# Función para mostrar mensajes de éxito
show_success() {
    local message="$1"
    echo -e "${GREEN}✅ ${message}${NC}"
}

# Función para mostrar mensajes de error
show_error() {
    local message="$1"
    echo -e "${RED}❌ ${message}${NC}"
}

# Función para mostrar mensajes de advertencia
show_warning() {
    local message="$1"
    echo -e "${YELLOW}⚠️  ${message}${NC}"
}

# Función para mostrar spinner de progreso
show_spinner() {
    local message="$1"
    local pid=$2
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    echo -n "$message "
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "[%c]" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b"
    done
    printf "   \b\b\b"
}

# Función para confirmar acciones destructivas
confirm_action() {
    local message="$1"
    local default="${2:-N}"
    local prompt
    
    if [[ "$default" == "Y" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi
    
    echo -e "${YELLOW}⚠️  ${message}${NC}"
    read -p "¿Continuar? $prompt " response
    
    response=${response:-$default}
    
    case "$response" in
        [Yy]|[Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

# Sistema de breadcrumbs para navegación
show_breadcrumb() {
    local path="$1"
    echo -e "${CYAN}🏠 ${path}${NC}"
    echo ""
}

# Mini-dashboard de estado para menú principal
show_mini_dashboard() {
    local nginx_status="❌"
    local tor_status="❌"
    local wp_status="❌"
    local wp_count="0/0"
    
    # Check NGINX
    if systemctl is-active --quiet nginx 2>/dev/null; then
        nginx_status="✅"
    fi
    
    # Check Tor
    if systemctl is-active --quiet tor 2>/dev/null; then
        tor_status="✅"
    fi
    
    # Check WordPress (contar contenedores corriendo)
    if command -v podman >/dev/null 2>&1; then
        local total_wp=$(sudo podman ps -a --filter "name=enola-.*-wp" --format "{{.Names}}" 2>/dev/null | wc -l)
        local running_wp=$(sudo podman ps --filter "name=enola-.*-wp" --format "{{.Names}}" 2>/dev/null | wc -l)
        wp_count="${running_wp}/${total_wp}"
        if [[ $running_wp -gt 0 ]]; then
            wp_status="✅"
        fi
    fi
    
    echo -e "${YELLOW}📊 Estado del Sistema:${NC} NGINX ${nginx_status} | Tor ${tor_status} | WordPress (${wp_count}) ${wp_status}"
    echo ""
}

get_status_json() {
    local json="{"
    json+='"nginx":{'
    
    # Estado de NGINX
    if systemctl is-active --quiet nginx; then
        json+='"status":"active",'
        json+='"port":"80"'
    else
        json+='"status":"inactive",'
        json+='"port":"80"'
    fi
    json+='},'
    
    json+='"tor":{'
    # Estado de Tor
    if systemctl is-active --quiet enola-tor; then
        json+='"status":"active",'
        json+='"services":['
        
        # Listar servicios onion
        local first=true
        if [ -d "/var/lib/tor" ]; then
            for dir in /var/lib/tor/hidden_service_*; do
                if [ -d "$dir" ] && [ -f "$dir/hostname" ]; then
                    $first || json+=','
                    first=false
                    local name=$(basename "$dir" | sed 's/hidden_service_//')
                    local onion=$(cat "$dir/hostname" 2>/dev/null || echo "unknown")
                    json+="{\"name\":\"$name\",\"onion\":\"$onion\"}"
                fi
            done
        fi
        json+=']'
    else
        json+='"status":"inactive",'
        json+='"services":[]'
    fi
    json+='},'
    
    json+='"ssh":{'
    # Estado de SSH
    if systemctl is-active --quiet ssh; then
        local ssh_port=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
        [ -z "$ssh_port" ] && ssh_port="22"
        json+='"status":"active",'
        json+='"port":"'"$ssh_port"'"'
    else
        json+='"status":"inactive",'
        json+='"port":"22"'
    fi
    json+='}'
    
    json+='}'
    
    echo "$json" | jq '.' 2>/dev/null || echo "$json"
}

copy_to_clipboard() {
    local text="$1"
    if command -v xclip &> /dev/null; then
        echo "$text" | xclip -selection clipboard
        return 0
    elif command -v xsel &> /dev/null; then
        echo "$text" | xsel --clipboard --input
        return 0
    else
        echo "Error: xclip o xsel no están instalados."
        return 1
    fi
}

# --------------------------------------------------------------------
# --------------------------------------------------------------------
# SUBMENÚ DIAGNÓSTICO
# --------------------------------------------------------------------
show_diagnostics_menu() {
    # Helper para ver logs sin paginador y con sudo si es necesario
    view_log() {
        local file="$1"
        echo -e "\n--- $file (últimas 200 líneas) ---\n"
        if [[ -r "$file" ]]; then
            tail -n 200 "$file" || true
        elif command -v sudo >/dev/null 2>&1 && sudo -n test -r "$file" 2>/dev/null; then
            sudo -n tail -n 200 "$file" || true
        else
            echo "No hay permisos para leer $file (ejecuta con sudo)"
        fi
        echo -e "\n--- fin ---\n"
    }

    while true; do
        clear
        show_breadcrumb "Menú Principal → Diagnóstico"
        
        # Leer estado del timer para mostrar indicador visual
        local timer_state="desconocido"
        if command -v systemctl >/dev/null 2>&1; then
            if systemctl is-enabled --quiet enola-smoke.timer 2>/dev/null; then
                timer_state="${GREEN}habilitado${NC}"
            else
                timer_state="${RED}deshabilitado${NC}"
            fi
        fi
        
        echo -e "${CYAN}=== DIAGNÓSTICO ===${NC}"
        echo "1) Resumen rápido [NGINX/Tor/SSH/WordPress]"
        echo "2) Detalles NGINX [Ver configuración y estado]"
        echo "3) Detalles Tor [Hidden services activos]"
        echo "4) Detalles SSH [Conexiones y configuración]"
        echo "5) Detalles WordPress [Contenedores y servicios]"
        echo "6) Estado de sincronización WordPress [NGINX ↔ Contenedores]"
        echo "7) Probar configuración NGINX [Ejecutar nginx -t]"
        echo "8) Ejecutar smoke test [Verificar todos los servicios]"
        echo "9) Estado del timer del smoke [Ver programación]"
        echo -e "10) Alternar timer del smoke [Actual: ${timer_state}]"
        echo "11) Ver log de instalación [postinst]"
        echo "12) Ver log del smoke [postinst]"
        echo "13) Ver log del smoke programado [timer]"
        echo "0) Volver al menú principal"
        echo ""
        echo "💡 Tip: Presiona el número directamente (sin Enter)"
        read -n1 -s d_choice
        echo ""

        case "$d_choice" in
            1)
                clear
                bash /opt/enola/scripts/common/status_nginx.sh
                echo "--------------------------------"
                bash /opt/enola/scripts/tor/list_services.sh
                echo "--------------------------------"
                bash /opt/enola/scripts/common/status_ssh.sh
                echo "--------------------------------"
                bash /opt/enola/scripts/common/status_wordpress.sh
                read -p "Presiona Enter para volver..."
                ;;
            2)
                clear
                bash /opt/enola/scripts/common/status_nginx.sh
                read -p "Enter para continuar..."
                ;;
            3)
                clear
                bash /opt/enola/scripts/tor/list_services.sh
                read -p "Enter para continuar..."
                ;;
            4)
                clear
                bash /opt/enola/scripts/common/status_ssh.sh
                read -p "Enter para continuar..."
                ;;
            5)
                clear
                bash /opt/enola/scripts/common/status_wordpress.sh
                read -p "Enter para continuar..."
                ;;
            6)
                clear
                if [ -f "/opt/enola/scripts/wordpress/wordpress_status.sh" ]; then
                    bash /opt/enola/scripts/wordpress/wordpress_status.sh
                else
                    echo "Error: Script wordpress_status.sh no encontrado"
                fi
                read -p "Enter para continuar..."
                ;;
            7)
                clear
                if command -v nginx >/dev/null 2>&1; then
                    sudo nginx -t 2>&1 | sed 's/^/[NGINX] /'
                else
                    echo "nginx no está instalado o no está en PATH"
                fi
                read -p "Enter para continuar..."
                ;;
            8)
                clear
                if [ -f "/opt/enola/scripts/common/smoke_test.sh" ]; then
                    sudo bash "/opt/enola/scripts/common/smoke_test.sh" || true
                else
                    echo "Error: Smoke test no encontrado en /opt/enola/scripts/common/smoke_test.sh"
                fi
                read -p "Enter para continuar..."
                ;;
            9)
                clear
                if command -v systemctl >/dev/null 2>&1; then
                    systemctl status enola-smoke.timer --no-pager 2>&1 || true
                else
                    echo "systemctl no disponible"
                fi
                read -p "Enter para continuar..."
                ;;
            10)
                clear
                if command -v systemctl >/dev/null 2>&1; then
                    if systemctl is-enabled --quiet enola-smoke.timer 2>/dev/null; then
                        sudo systemctl disable --now enola-smoke.timer && echo "Timer deshabilitado" || echo "No se pudo deshabilitar el timer"
                    else
                        sudo systemctl enable --now enola-smoke.timer && echo "Timer habilitado" || echo "No se pudo habilitar el timer"
                    fi
                else
                    echo "systemctl no disponible"
                fi
                read -p "Enter para continuar..."
                ;;
            11)
                clear
                view_log "/var/log/enola-server/postinst.log"
                read -p "Enter para continuar..."
                ;;
            12)
                clear
                view_log "/var/log/enola-server/smoke_postinst.log"
                read -p "Enter para continuar..."
                ;;
            13)
                clear
                view_log "/var/log/enola-server/smoke_timer.log"
                read -p "Enter para continuar..."
                ;;
            0) break ;;
            *) 
                show_error "Opción inválida"
                sleep 1
                ;;
        esac
    done
}

# BANNER
# --------------------------------------------------------------------
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


# --------------------------------------------------------------------
# SUBMENÚ WORDPRESS
# --------------------------------------------------------------------
show_wordpress_menu() {
    while true; do
        clear
        show_breadcrumb "Menú Principal → WordPress"
        echo -e "${CYAN}=== MENÚ WORDPRESS ===${NC}"
        echo "1) Instalar WordPress [Crear nueva instancia]"
        echo "2) Editar configuración de WordPress [Modificar instancia existente]"
        echo "3) Iniciar / Parar WordPress [Gestionar contenedores]"
        echo "4) Habilitar / Deshabilitar WordPress [Autoarranque]"
        echo "0) Volver al menú principal"
        if type show_help_tip >/dev/null 2>&1; then
            echo ""
            show_help_tip
        fi
        
        read -n1 -s wp_choice
        echo ""
        
        # Verificar ayuda
        if type handle_help_key >/dev/null 2>&1; then
            if handle_help_key "wordpress_menu" "$wp_choice"; then
                continue
            fi
        fi

        case "$wp_choice" in
            1)
                clear
                if [ -f "/opt/enola/scripts/wordpress/generate_wordpress.sh" ]; then
                    show_success "Ejecutando instalación de WordPress..."
                    sudo bash "/opt/enola/scripts/wordpress/generate_wordpress.sh" || true
                else
                    show_error "Script de instalación no encontrado"
                fi
                read -p "Enter para continuar..."
                ;;
            2)
                clear
                if [ -f "/opt/enola/scripts/wordpress/edit_wordpress.sh" ]; then
                    show_success "Abriendo editor de WordPress..."
                    sudo bash "/opt/enola/scripts/wordpress/edit_wordpress.sh" || true
                else
                    show_error "Script de edición no encontrado"
                fi
                read -p "Enter para continuar..."
                ;;
            3)
                show_wordpress_start_stop_menu
                ;;
            4)
                show_wordpress_toggle_menu
                ;;
            0) break ;;
            *) 
                show_error "Opción inválida"
                read -p "Enter para continuar..."
                ;;
        esac
    done
}

# SUBMENÚ INICIAR/PARAR WORDPRESS
# --------------------------------------------------------------------
show_wordpress_start_stop_menu() {
    while true; do
        clear
        show_breadcrumb "Menú Principal → WordPress → Iniciar/Parar"
        echo -e "${CYAN}=== INICIAR / PARAR WORDPRESS ===${NC}"
        echo "1) Iniciar WordPress [Start contenedores]"
        echo "2) Parar WordPress [Stop contenedores]"
        echo "3) Reiniciar WordPress [Restart contenedores]"
        echo "4) Ver estado de WordPress [Status systemd]"
        echo "0) Volver al menú anterior"
        read -p "Elige una opción: " start_stop_choice

        case "$start_stop_choice" in
            1)
                if [ -f "/opt/enola/scripts/wordpress/toggle_wordpress.sh" ]; then
                    sudo bash "/opt/enola/scripts/wordpress/toggle_wordpress.sh" start || true
                else
                    echo "Error: Script no encontrado."
                fi
                read -p "Enter para continuar..."
                ;;
            2)
                if [ -f "/opt/enola/scripts/wordpress/toggle_wordpress.sh" ]; then
                    sudo bash "/opt/enola/scripts/wordpress/toggle_wordpress.sh" stop || true
                else
                    echo "Error: Script no encontrado."
                fi
                read -p "Enter para continuar..."
                ;;
            3)
                if [ -f "/opt/enola/scripts/wordpress/toggle_wordpress.sh" ]; then
                    sudo bash "/opt/enola/scripts/wordpress/toggle_wordpress.sh" restart || true
                else
                    echo "Error: Script no encontrado."
                fi
                read -p "Enter para continuar..."
                ;;
            4)
                if [ -f "/opt/enola/scripts/wordpress/toggle_wordpress.sh" ]; then
                    sudo bash "/opt/enola/scripts/wordpress/toggle_wordpress.sh" status || true
                else
                    echo "Error: Script no encontrado."
                fi
                read -p "Enter para continuar..."
                ;;
            0) break ;;
            *) echo "Opción inválida"; read -p "Enter para continuar..." ;;
        esac
    done
}

# SUBMENÚ HABILITAR/DESHABILITAR WORDPRESS
# --------------------------------------------------------------------
show_wordpress_toggle_menu() {
    while true; do
        clear
        show_breadcrumb "Menú Principal → WordPress → Habilitar/Deshabilitar"
        echo -e "${CYAN}=== HABILITAR / DESHABILITAR WORDPRESS ===${NC}"
        echo "1) Deshabilitar WordPress [Ocultar en Tor]"
        echo "2) Habilitar WordPress [Publicar en Tor]"
        echo "0) Volver al menú anterior"
        
        read -n1 -s toggle_choice
        echo ""

        case "$toggle_choice" in
            1)
                clear
                if confirm_action "¿Deshabilitar WordPress en Tor? Esto ocultará el servicio."; then
                    if [ -f "/opt/enola/scripts/wordpress/disable_wordpress.sh" ]; then
                        echo ""
                        show_success "Deshabilitando WordPress..."
                        sudo bash "/opt/enola/scripts/wordpress/disable_wordpress.sh" || show_error "Error al deshabilitar"
                    else
                        show_error "Script de deshabilitar no encontrado"
                    fi
                else
                    show_warning "Operación cancelada"
                fi
                read -p "Enter para continuar..."
                ;;
            2)
                clear
                if [ -f "/opt/enola/scripts/wordpress/enable_wordpress.sh" ]; then
                    show_success "Habilitando WordPress..."
                    sudo bash "/opt/enola/scripts/wordpress/enable_wordpress.sh" || show_error "Error al habilitar"
                else
                    show_error "Script de habilitar no encontrado"
                fi
                read -p "Enter para continuar..."
                ;;
            0) break ;;
            *) 
                show_error "Opción inválida"
                read -p "Enter para continuar..."
                ;;
        esac
    done
}

# --------------------------------------------------------------------
# SUBMENÚ ELIMINAR SERVICIO
# --------------------------------------------------------------------
show_remove_service_menu() {
    while true; do
        clear
        show_breadcrumb "Menú Principal → Servicios → Eliminar Servicio"
        echo -e "${CYAN}=== ELIMINAR SERVICIO ===${NC}"
        echo "1) Eliminar un servicio [Eliminar hidden service individual]"
        echo "2) Eliminar varios servicios [Selección múltiple]"
        echo "0) Volver al menú anterior"
        
        read -n1 -s remove_choice
        echo ""

        case "$remove_choice" in
            1)
                clear
                if confirm_action "¿Eliminar servicio? Esta acción NO se puede deshacer."; then
                    if [ -f "/opt/enola/scripts/services/remove/remove_service.sh" ]; then
                        show_success "Ejecutando eliminación de servicio..."
                        sudo bash "/opt/enola/scripts/services/remove/remove_service.sh" || show_error "Error al eliminar"
                    else
                        show_error "Script remove_service.sh no encontrado"
                    fi
                else
                    show_warning "Operación cancelada"
                fi
                read -p "Enter para continuar..."
                ;;
            2)
                clear
                if confirm_action "¿Eliminar múltiples servicios? Esta acción NO se puede deshacer."; then
                    if [ -f "/opt/enola/scripts/services/remove/remove_service_multi.sh" ]; then
                        show_success "Ejecutando eliminación múltiple..."
                        sudo bash "/opt/enola/scripts/services/remove/remove_service_multi.sh" || show_error "Error al eliminar"
                    else
                        show_error "Script remove_service_multi.sh no encontrado"
                    fi
                else
                    show_warning "Operación cancelada"
                fi
                read -p "Enter para continuar..."
                ;;
            0) break ;;
            *) 
                show_error "Opción inválida"
                read -p "Enter para continuar..."
                ;;
        esac
    done
}

# --------------------------------------------------------------------
# SUBMENÚ HABILITAR/DESHABILITAR SERVICIO
# --------------------------------------------------------------------
show_toggle_service_menu() {
    while true; do
        clear
        show_breadcrumb "Menú Principal → Servicios → Habilitar/Deshabilitar"
        echo -e "${CYAN}=== HABILITAR / DESHABILITAR SERVICIO ===${NC}"
        echo "1) Habilitar un servicio [Activar hidden service]"
        echo "2) Habilitar varios servicios [Activación múltiple]"
        echo "3) Deshabilitar un servicio [Desactivar hidden service]"
        echo "4) Deshabilitar varios servicios [Desactivación múltiple]"
        echo "0) Volver al menú anterior"
        read -p "Elige una opción: " toggle_choice

        case "$toggle_choice" in
            1)
                if [ -f "/opt/enola/scripts/services/enable/enable_service.sh" ]; then
                    sudo bash "/opt/enola/scripts/services/enable/enable_service.sh" || true
                else
                    echo "Error: Script enable_service.sh no encontrado."
                fi
                read -p "Enter para continuar..."
                ;;
            2)
                if [ -f "/opt/enola/scripts/services/enable/enable_service_multi.sh" ]; then
                    sudo bash "/opt/enola/scripts/services/enable/enable_service_multi.sh" || true
                else
                    echo "Error: Script enable_service_multi.sh no encontrado."
                fi
                read -p "Enter para continuar..."
                ;;
            3)
                if [ -f "/opt/enola/scripts/services/disable/disable_service.sh" ]; then
                    sudo bash "/opt/enola/scripts/services/disable/disable_service.sh" || true
                else
                    echo "Error: Script disable_service.sh no encontrado."
                fi
                read -p "Enter para continuar..."
                ;;
            4)
                if [ -f "/opt/enola/scripts/services/disable/disable_service_multi.sh" ]; then
                    sudo bash "/opt/enola/scripts/services/disable/disable_service_multi.sh" || true
                else
                    echo "Error: Script disable_service_multi.sh no encontrado."
                fi
                read -p "Enter para continuar..."
                ;;
            0) break ;;
            *) echo "Opción inválida"; read -p "Enter para continuar..." ;;
        esac
    done
}

# --------------------------------------------------------------------
# MENÚ DE CONFIGURACIÓN DEL SISTEMA
# --------------------------------------------------------------------
show_system_config_menu() {
    while true; do
        clear
        show_breadcrumb "Menú Principal → Configuración del Sistema"
        echo -e "${CYAN}=== CONFIGURACIÓN DEL SISTEMA ===${NC}"
        echo ""
        echo "1) Habilitar/Deshabilitar Smoke Test periódico [Timer systemd]"
        echo "2) Habilitar/Deshabilitar check de SSH en Smoke Test [Opcional]"
        echo "3) Ejecutar Smoke Test manual [Verificación inmediata]"
        echo "0) Volver al menú principal"
        echo ""
        echo "💡 Tip: Presiona el número directamente (sin Enter)"
        read -n1 -s choice
        echo ""
        
        case "$choice" in
            1)
                clear
                if [ -f "/opt/enola/scripts/config/toggle_smoke_test.sh" ]; then
                    sudo bash "/opt/enola/scripts/config/toggle_smoke_test.sh" || true
                else
                    echo "Error: Script toggle_smoke_test.sh no encontrado."
                fi
                read -p "Enter para continuar..."
                ;;
            2)
                clear
                if [ -f "/opt/enola/scripts/config/toggle_ssh_check.sh" ]; then
                    sudo bash "/opt/enola/scripts/config/toggle_ssh_check.sh" || true
                else
                    echo "Error: Script toggle_ssh_check.sh no encontrado."
                fi
                read -p "Enter para continuar..."
                ;;
            3)
                clear
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "  EJECUTANDO SMOKE TEST MANUAL"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                if [ -f "/opt/enola/scripts/common/smoke_test.sh" ]; then
                    sudo bash "/opt/enola/scripts/common/smoke_test.sh" || true
                else
                    echo "Error: Script smoke_test.sh no encontrado."
                fi
                echo ""
                read -p "Enter para continuar..."
                ;;
            0) break ;;
            *) 
                show_error "Opción inválida"
                sleep 1
                ;;
        esac
    done
}

# --------------------------------------------------------------------
# MENÚ PRINCIPAL
# --------------------------------------------------------------------
show_main_menu() {
    local first_run=true
    while true; do
        clear
        if $first_run; then
            show_banner
            show_mini_dashboard
            first_run=false
        fi

        echo -e "${CYAN}=== MENÚ ENOLA SERVER ===${NC}"
        echo "1) WordPress [Gestionar instancias y contenedores]"
        echo "2) Servicios [Hidden services de Tor]"
        echo "3) Configuración del sistema [Smoke test y ajustes]"
        echo "4) Diagnóstico [Logs y estado de servicios]"
        echo "q) Salir"
        echo ""
        echo -e "${YELLOW}Tip: Presiona el número directamente (sin Enter)${NC}"
        if type show_help_tip >/dev/null 2>&1; then
            show_help_tip
        fi
        echo ""

        read -n1 -s choice
        echo ""
        
        # Verificar si es ayuda
        if type handle_help_key >/dev/null 2>&1; then
            if handle_help_key "main_menu" "$choice"; then
                continue
            fi
        fi

        case "$choice" in
            1) show_wordpress_menu ;;
            2) show_services_menu ;;
            3) show_system_config_menu ;;
            4) show_diagnostics_menu ;;
            q|Q) break ;;
            *) 
                show_error "Opción inválida"
                sleep 1
                ;;
        esac
    done
    clear
}

# SUBMENÚ SERVICIOS
# --------------------------------------------------------------------
show_services_menu() {
    while true; do
        clear
        show_breadcrumb "Menú Principal → Servicios"
        echo -e "${CYAN}=== SERVICIOS ===${NC}"
        echo "1) Añadir servicio web [Crear hidden service de Tor]"
        echo "2) Eliminar servicio [Borrar hidden service]"
        echo "3) Habilitar/Deshabilitar servicio [Activar/desactivar]"
        echo "4) Editar puertos [Cambiar onion/NGINX/backend]"
        echo "0) Volver al menú principal"
        
        read -n1 -s services_choice
        echo ""

        case "$services_choice" in
            1)
                clear
                if [ -f "/opt/enola/scripts/tor/deploy_tor_web.sh" ]; then
                    show_success "Iniciando despliegue de servicio web..."
                    sudo bash "/opt/enola/scripts/tor/deploy_tor_web.sh" || show_error "Error en despliegue"
                else
                    show_error "Script deploy_tor_web.sh no encontrado"
                fi
                read -p "Enter para continuar..."
                ;;
            2) show_remove_service_menu ;;
            3) show_toggle_service_menu ;;
            4)
                clear
                if [ -f "/opt/enola/scripts/config/edit_ports.sh" ]; then
                    show_success "Abriendo editor de puertos..."
                    sudo bash "/opt/enola/scripts/config/edit_ports.sh" || show_error "Error al editar puertos"
                else
                    show_error "Script de edición no encontrado"
                fi
                read -p "Enter para continuar..."
                ;;
            0) break ;;
            *) 
                show_error "Opción inválida"
                read -p "Enter para continuar..."
                ;;
        esac
    done
}

show_main_menu
echo "Saliendo... ¡Hasta luego!"
exit 0
