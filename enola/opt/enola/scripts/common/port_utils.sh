#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial

# ====================================================================
# UTILIDADES PARA GESTIÓN DE PUERTOS
# ====================================================================
# Funciones compartidas para búsqueda y validación de puertos
# Para usar: source /opt/enola/scripts/common/port_utils.sh
# ====================================================================

# --------------------------------------------------------------------
# Encontrar puerto libre en un rango
# Uso: find_free_port <puerto_inicio> <puerto_fin>
# Retorna: Puerto libre o error (return 1)
# --------------------------------------------------------------------
find_free_port() {
    local start=$1
    local end=$2
    local port

    for port in $(seq "$start" "$end"); do
        # Verificar si está ocupado en el sistema
        if ss -tulnH | awk '{print $5}' | grep -qE ":${port}$"; then
            continue
        fi
        
        # Verificar si está usado en NGINX (sites-available y sites-enabled)
        if grep -rq "listen.*:${port}" /etc/nginx/sites-available/ /etc/nginx/sites-enabled/ 2>/dev/null; then
            continue
        fi
        
        # Verificar si está usado en otras configuraciones de Tor
        if grep -rq "127.0.0.1:${port}" /etc/tor/enola.d/*.conf 2>/dev/null; then
            continue
        fi
        
        echo "$port"
        return 0
    done
    
    return 1
}

# --------------------------------------------------------------------
# Validar formato de puerto
# Uso: validate_port <puerto>
# Retorna: 0 si válido, 1 si inválido
# --------------------------------------------------------------------
validate_port() {
    local p="$1"
    [[ "$p" =~ ^[0-9]+$ ]] || return 1
    (( p >= 1 && p <= 65535 )) || return 1
    return 0
}

# --------------------------------------------------------------------
# Verificar si un puerto está disponible
# Uso: check_port_available <puerto>
# Retorna: 0 si disponible, 1 si ocupado
# --------------------------------------------------------------------
check_port_available() {
    local port="$1"
    if ss -tuln | grep -q ":${port}\s"; then
        return 1  # Puerto ocupado
    fi
    return 0  # Puerto disponible
}
