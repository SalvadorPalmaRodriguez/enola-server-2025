#!/bin/bash

# port_validator.sh
# Funciones para validar disponibilidad de puertos y sugerir alternativas

# Colores
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
NC="\033[0m"

# Verificar si un puerto está disponible
# Retorna 0 si está disponible, 1 si está ocupado
check_port_available() {
    local port=$1
    
    # Verificar con ss (más rápido y moderno)
    if command -v ss >/dev/null 2>&1; then
        if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
            return 1  # Ocupado
        fi
    else
        # Fallback a netstat si ss no está disponible
        if command -v netstat >/dev/null 2>&1; then
            if netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
                return 1  # Ocupado
            fi
        fi
    fi
    
    return 0  # Disponible
}

# Obtener el proceso que está usando un puerto
get_port_process() {
    local port=$1
    
    if command -v ss >/dev/null 2>&1; then
        ss -tlnp 2>/dev/null | grep ":${port} " | awk '{print $NF}' | head -1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tlnp 2>/dev/null | grep ":${port} " | awk '{print $NF}' | head -1
    else
        echo "desconocido"
    fi
}

# Validar que el puerto esté en el rango permitido
validate_port_range() {
    local port=$1
    
    # Puertos del sistema (1-1023) requieren root y están restringidos
    if [ "$port" -lt 1024 ]; then
        echo -e "${YELLOW}⚠️  Advertencia: Puerto $port está en rango de sistema (1-1023)${NC}"
        echo -e "${YELLOW}   Esto puede requerir privilegios especiales${NC}"
        return 1
    fi
    
    # Rango válido para usuarios: 1024-65535
    if [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}❌ Error: Puerto $port fuera de rango válido (1024-65535)${NC}"
        return 2
    fi
    
    return 0
}

# Sugerir puerto alternativo disponible
suggest_alternative_port() {
    local base_port=$1
    local max_attempts=${2:-10}
    local suggested_port=$base_port
    
    for i in $(seq 1 $max_attempts); do
        suggested_port=$((base_port + i))
        
        # No exceder el rango válido
        if [ "$suggested_port" -gt 65535 ]; then
            suggested_port=$((base_port - i))
        fi
        
        if check_port_available "$suggested_port"; then
            echo "$suggested_port"
            return 0
        fi
    done
    
    # No se encontró puerto disponible
    return 1
}

# Verificar puerto con feedback completo al usuario
validate_port_interactive() {
    local port=$1
    local service_name=${2:-"servicio"}
    
    echo -e "${CYAN}🔍 Verificando puerto $port para $service_name...${NC}"
    
    # Validar rango
    if ! validate_port_range "$port"; then
        return 1
    fi
    
    # Verificar disponibilidad
    if check_port_available "$port"; then
        echo -e "${GREEN}✅ Puerto $port disponible${NC}"
        return 0
    else
        local process=$(get_port_process "$port")
        echo -e "${RED}❌ Puerto $port ocupado${NC}"
        echo -e "${YELLOW}   Proceso usando el puerto: $process${NC}"
        
        # Sugerir alternativa
        local alternative=$(suggest_alternative_port "$port")
        if [ $? -eq 0 ]; then
            echo -e "${CYAN}💡 Puerto alternativo sugerido: $alternative${NC}"
            echo ""
            read -p "¿Deseas usar el puerto $alternative en su lugar? [Y/n]: " response
            if [ "$response" != "n" ] && [ "$response" != "N" ]; then
                echo "$alternative"
                return 0
            fi
        else
            echo -e "${RED}⚠️  No se encontraron puertos alternativos disponibles${NC}"
        fi
        
        return 1
    fi
}

# Verificar múltiples puertos de una vez
validate_multiple_ports() {
    local all_available=true
    local ports=("$@")
    
    echo -e "${CYAN}🔍 Verificando disponibilidad de ${#ports[@]} puertos...${NC}"
    echo ""
    
    for port in "${ports[@]}"; do
        if check_port_available "$port"; then
            echo -e "  ✅ Puerto $port: ${GREEN}disponible${NC}"
        else
            local process=$(get_port_process "$port")
            echo -e "  ❌ Puerto $port: ${RED}ocupado${NC} (proceso: $process)"
            all_available=false
        fi
    done
    
    echo ""
    
    if $all_available; then
        echo -e "${GREEN}✅ Todos los puertos están disponibles${NC}"
        return 0
    else
        echo -e "${RED}❌ Algunos puertos no están disponibles${NC}"
        return 1
    fi
}

# Función para mostrar ayuda
show_help() {
    cat << 'EOF'
port_validator.sh - Validación de puertos para Enola Server

USO:
    source /opt/enola/scripts/common/port_validator.sh
    
FUNCIONES DISPONIBLES:

    check_port_available <puerto>
        Verifica si un puerto está disponible
        Retorna: 0 si disponible, 1 si ocupado
        
    get_port_process <puerto>
        Obtiene el proceso que está usando un puerto
        
    validate_port_range <puerto>
        Valida que el puerto esté en rango 1024-65535
        
    suggest_alternative_port <puerto_base> [intentos]
        Sugiere un puerto alternativo disponible
        
    validate_port_interactive <puerto> [nombre_servicio]
        Verificación interactiva con sugerencias
        
    validate_multiple_ports <puerto1> <puerto2> ...
        Verifica múltiples puertos a la vez

EJEMPLOS:

    # Verificar un puerto
    if check_port_available 8080; then
        echo "Puerto 8080 disponible"
    fi
    
    # Validación interactiva
    new_port=$(validate_port_interactive 8080 "WordPress")
    
    # Verificar múltiples puertos
    validate_multiple_ports 8080 3306 9000

EOF
}

# Si se ejecuta directamente (no con source), mostrar ayuda
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_help
fi
