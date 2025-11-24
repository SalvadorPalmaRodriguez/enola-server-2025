#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

# Estado de WordPress (instancias gestionadas por Podman)

ENV_DIR="/opt/enola/wordpress"
NGINX_SITES="/etc/nginx/sites-enabled"
TOR_DIR="/var/lib/tor"

_container_status() {
    local name="$1"
    if ! command -v podman >/dev/null 2>&1; then
        echo "desconocido (podman no disponible)"
        return
    fi
    local line
    line=$(podman ps -a --format '{{.Names}}|{{.Status}}|{{.Ports}}' | grep -E "^${name}\|" || true)
    if [ -z "$line" ]; then
        echo "no-existe"
        return
    fi
    IFS='|' read -r _nm status ports <<< "$line"
    # normalizar estado corto
    if echo "$status" | grep -qi running; then
        echo "running|$ports"
    else
        echo "stopped|$ports"
    fi
}

_extract_backend_port() {
    # Puertos en formato: 127.0.0.1:8080->80/tcp, ...
    local ports="$1"
    echo "$ports" | grep -oE '127\.0\.0\.1:[0-9]+' | head -1 | cut -d: -f2 || true
}

_nginx_listen_port() {
    local name="$1"
    local site="$NGINX_SITES/${name}.conf"
    if [ -r "$site" ]; then
        grep -E '^\s*listen' "$site" | head -1 | sed -E 's/.*:([0-9]+).*/\1/' || true
    fi
}

_onion_addr() {
    local name="$1"
    local f="$TOR_DIR/hidden_service_${name}/hostname"
    [ -f "$f" ] && cat "$f" || true
}

get_wordpress_status() {
    echo -e "\n📝 Estado de WordPress (Podman)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local found=false

    if [ -d "$ENV_DIR" ]; then
        shopt -s nullglob
        for envf in "$ENV_DIR"/*.env; do
            [ -f "$envf" ] || continue
            local name
            name=$(basename "$envf" .env)
            found=true

            # contenedores
            local wp_name="enola-${name}-wp"
            local db_name="enola-${name}-mysql"

            local wp_status ports db_status db_ports
            wp_status=$(_container_status "$wp_name")
            db_status=$(_container_status "$db_name")

            local wp_state="desconocido" db_state="desconocido" backend=""
            if [ "$wp_status" != "no-existe" ]; then
                wp_state=$(echo "$wp_status" | cut -d'|' -f1)
                ports=$(echo "$wp_status" | cut -d'|' -f2-)
                backend=$(_extract_backend_port "$ports")
            else
                wp_state="no-existe"
            fi
            if [ "$db_status" != "no-existe" ]; then
                db_state=$(echo "$db_status" | cut -d'|' -f1)
            else
                db_state="no-existe"
            fi

            local nginx_port onion
            nginx_port=$(_nginx_listen_port "$name")
            onion=$(_onion_addr "$name")

            echo "📦 Servicio: $name"
            echo "   - WP: $wp_state${backend:+ (backend 127.0.0.1:$backend)}"
            echo "   - DB: $db_state"
            if [ -n "$nginx_port" ]; then
                echo "   - NGINX: escuchando en 127.0.0.1:$nginx_port"
            else
                echo "   - NGINX: no encontrado"
            fi
            if [ -n "$onion" ]; then
                echo "   - Onion: http://$onion"
            else
                echo "   - Onion: (no disponible aún)"
            fi
            echo ""
        done
        shopt -u nullglob
    fi

    if [ "$found" = false ]; then
        echo "❌ No se encontraron instancias de WordPress gestionadas por Enola"
        echo "(buscando en $ENV_DIR/*.env)"
    fi
}

# Ejecutar la función si el script se llama directamente
get_wordpress_status
