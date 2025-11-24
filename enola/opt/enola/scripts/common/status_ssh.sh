#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

GREEN="\033[0;32m"; RED="\033[0;31m"; CYAN="\033[0;36m"; YELLOW="\033[1;33m"; NC="\033[0m"

_cfg_ports() {
    # Extrae puertos declarados en la configuración de sshd
    local ports=()
    if [ -f /etc/ssh/sshd_config ]; then
        while read -r p; do
            [ -n "$p" ] && ports+=("$p")
        done < <(grep -E "^\s*Port\s+" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    fi

    shopt -s nullglob
    for f in /etc/ssh/sshd_config.d/*.conf; do
        while read -r p; do
            [ -n "$p" ] && ports+=("$p")
        done < <(grep -E "^\s*Port\s+" "$f" 2>/dev/null | awk '{print $2}')
    done
    shopt -u nullglob

    if [ ${#ports[@]} -eq 0 ]; then
        ports+=("22")
    fi
    printf '%s\n' "${ports[@]}" | awk '!seen[$0]++'
}

_is_listening() {
    local port="$1"
    if ! command -v ss >/dev/null 2>&1; then
        return 2
    fi
    # Comprueba listeners TCP para el puerto
    if ss -ltn | awk '{print $4}' | grep -qE ":${port}(\b|$)"; then
        return 0
    else
        return 1
    fi
}

get_ssh_status() {
    echo -e "\n🔐 ${CYAN}Estado de SSH${NC}"

    local unit="ssh"
    if ! systemctl is-active --quiet ssh && systemctl is-active --quiet sshd; then
        unit="sshd"
    fi

    if ! systemctl is-active --quiet "$unit"; then
        echo -e "❌ ${RED}SSH está inactivo${NC}"
    else
        local enabled="$(systemctl is-enabled "$unit" 2>/dev/null || echo "desconocido")"
        echo -e "✅ ${GREEN}SSH está activo${NC} (${enabled})"
    fi

    # Puertos configurados
    mapfile -t ports < <(_cfg_ports)
    if [ ${#ports[@]} -gt 1 ]; then
        echo -e "📌 Puertos configurados: ${ports[*]}"
    else
        echo -e "📌 Puerto configurado: ${ports[0]}"
    fi

    # Listeners
    local any_listen=false
    for p in "${ports[@]}"; do
        if _is_listening "$p"; then
            echo -e "   • ${GREEN}Escuchando${NC} en 0.0.0.0:$p/:::$p"
            any_listen=true
        else
            if [ $? -eq 2 ]; then
                echo -e "   • ${YELLOW}No se pudo verificar listeners (ss no disponible)${NC}"
                break
            else
                echo -e "   • ${YELLOW}No se detecta escucha en el puerto $p${NC}"
            fi
        fi
    done

    # Sugerencia si activo pero sin escucha aparente
    if systemctl is-active --quiet "$unit" && [ "$any_listen" = false ]; then
        echo -e "💡 ${YELLOW}Sugerencia:${NC} revisa configuración y logs: journalctl -u $unit -n 50"
    fi
}

# Ejecutar la función si el script se llama directamente
get_ssh_status
