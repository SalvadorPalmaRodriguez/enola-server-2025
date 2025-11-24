#!/bin/bash

# help_system.sh
# Sistema de ayuda contextual para Enola Server

HELP_DIR="/usr/share/enola-server/help"

# Colores
CYAN="\033[0;36m"
NC="\033[0m"

# Mostrar ayuda para un menú específico
show_help() {
    local menu_name="${1:-main_menu}"
    local help_file="$HELP_DIR/${menu_name}.txt"
    
    clear
    
    if [ -f "$help_file" ]; then
        cat "$help_file"
    else
        cat << EOF
╔═══════════════════════════════════════════════════════════════╗
║                    AYUDA - ENOLA SERVER                       ║
╚═══════════════════════════════════════════════════════════════╝

No hay ayuda específica disponible para este menú.

📌 AYUDA GENERAL:

• Usa números para navegar entre opciones
• Presiona '0' para volver al menú anterior
• Presiona 'h' para mostrar ayuda contextual
• Presiona 'q' para salir

Para más información, consulta:
  /usr/share/doc/enola-server/

EOF
    fi
    
    echo ""
    echo -e "${CYAN}Presiona cualquier tecla para continuar...${NC}"
    read -n1 -s
}

# Detectar si se presionó 'h' y mostrar ayuda
handle_help_key() {
    local menu_name="$1"
    local user_input="$2"
    
    if [ "$user_input" = "h" ] || [ "$user_input" = "H" ]; then
        show_help "$menu_name"
        return 0  # Ayuda mostrada
    fi
    
    return 1  # No era tecla de ayuda
}

# Añadir tip de ayuda a los menús
show_help_tip() {
    echo -e "${CYAN}💡 Tip: Presiona 'h' para ayuda | '0' para volver${NC}"
}
