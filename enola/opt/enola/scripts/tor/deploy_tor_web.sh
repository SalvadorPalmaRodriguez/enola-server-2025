#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail
set -x

# ==========================
# Variables globales Tor
# ==========================
TOR_DIR="/var/lib/tor"
SERVICES_DIR="/etc/tor/enola.d"
TEMPLATES_DIR="/usr/share/enola-server/templates"
TORRC="/etc/tor/torrc"
COMMON_DIR="/opt/enola/scripts/common"

# Importar utilidades de puertos
source "$COMMON_DIR/port_utils.sh" || { echo "Error: No se pudo cargar port_utils.sh"; exit 1; }

log() {
    echo -e "[WEB] $(date '+%F %T') | $1"
}

die() {
    echo -e "[WEB] $(date '+%F %T') | ERROR | $1"
    exit 1
}

ensure_services_dir() {
    mkdir -p "$SERVICES_DIR"
    chmod 755 "$SERVICES_DIR" 2>/dev/null || true
    # Garantizar inclusión de configs en torrc si no existe
    if [ -f "$TORRC" ] && ! grep -qF "%include $SERVICES_DIR/*.conf" "$TORRC"; then
        echo "%include $SERVICES_DIR/*.conf" >> "$TORRC"
        chmod 640 "$TORRC" 2>/dev/null || true
        chown root:debian-tor "$TORRC" 2>/dev/null || true
        log "Incluido $SERVICES_DIR/*.conf en $TORRC"
    fi
}

check_port() {
    local port=$1
    if ss -tulnH | awk '{print $5}' | grep -q ":$port$"; then
        die "El puerto $port ya está en uso"
    fi
}

# ───────────────────────────────
# 1. Nombre del servicio
# Acepta argumentos: $1=SERVICE_NAME, $2=BACKEND_PORT, $3=NGINX_PORT (opcionales)
if [[ -n "${1:-}" ]]; then
    # Modo no interactivo: argumentos desde CLI
    SERVICE_NAME="$1"
    [[ -n "${2:-}" ]] && BACKEND_PORT_ARG="$2" || BACKEND_PORT_ARG=""
    [[ -n "${3:-}" ]] && NGINX_PORT_ARG="$3" || NGINX_PORT_ARG=""
    
    # Validar nombre
    if ! [[ "$SERVICE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        die "Nombre inválido: $SERVICE_NAME. Usa solo letras, números, '-' y '_'"
    fi
    
    SERVICE_CONF="/etc/tor/enola.d/${SERVICE_NAME}.conf"
    HS_DIR="/var/lib/tor/hidden_service_${SERVICE_NAME}"
    
    if [[ -f "$SERVICE_CONF" || -d "$HS_DIR" ]]; then
        die "El servicio $SERVICE_NAME ya existe"
    fi
else
    # Modo interactivo: solicita nombre
    while true; do
        read -rp "👉 Ingresa el nombre del servicio web: " SERVICE_NAME
        [[ -z "$SERVICE_NAME" ]] && continue

        # Validar nombre (solo letras, números, guion y guion_bajo)
        if ! [[ "$SERVICE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "❌ Nombre inválido. Usa solo letras, números, '-' y '_'"
            continue
        fi

        SERVICE_CONF="/etc/tor/enola.d/${SERVICE_NAME}.conf"
        HS_DIR="/var/lib/tor/hidden_service_${SERVICE_NAME}"

        if [[ -f "$SERVICE_CONF" || -d "$HS_DIR" ]]; then
            echo "⚠️ El servicio $SERVICE_NAME ya existe, elige otro."
            continue
        fi
        break
    done
fi

# ───────────────────────────────
# 2. Variables dinámicas
LOG_DIR="/var/log/enola-server/${SERVICE_NAME}"
CONFIG_PATH="/etc/nginx/sites-available/${SERVICE_NAME}.conf"

# ───────────────────────────────
# 3. Puertos
# Usar puertos de argumentos CLI si fueron proporcionados, sino buscar libres
if [[ -n "${BACKEND_PORT_ARG:-}" ]]; then
    BACKEND_PORT="$BACKEND_PORT_ARG"
    log "✅ Puerto interno (argumento): $BACKEND_PORT"
else
    BACKEND_PORT=$(find_free_port 8080 8100) || die "No se encontró puerto interno libre"
    log "✅ Puerto interno (automático): $BACKEND_PORT"
fi

if [[ -n "${NGINX_PORT_ARG:-}" ]]; then
    NGINX_PORT="$NGINX_PORT_ARG"
    log "✅ Puerto externo NGINX (argumento): $NGINX_PORT"
else
    NGINX_PORT=$(find_free_port 9000 9100) || die "No se encontró puerto externo libre"
    log "✅ Puerto externo NGINX (automático): $NGINX_PORT"
fi

check_port "$BACKEND_PORT"
check_port "$NGINX_PORT"

# ───────────────────────────────
# 4. Configuración de NGINX
mkdir -p "$LOG_DIR"
ensure_services_dir
if [[ -f "$TEMPLATES_DIR/nginx.template" ]]; then
    export BACKEND_PORT NGINX_EXTERNAL="$NGINX_PORT" LOG_DIR SERVICE_NAME
    envsubst '${BACKEND_PORT} ${NGINX_EXTERNAL} ${LOG_DIR} ${SERVICE_NAME}' \
        < "$TEMPLATES_DIR/nginx.template" > "$CONFIG_PATH"
    ln -sf "$CONFIG_PATH" "/etc/nginx/sites-enabled/${SERVICE_NAME}.conf"
    nginx -t || die "Error en la configuración de NGINX"
    
    # Iniciar NGINX si no está activo, o recargar si ya está corriendo
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx || die "No se pudo recargar NGINX"
    else
        systemctl start nginx || die "No se pudo iniciar NGINX"
    fi
    
    log "✅ NGINX configurado y recargado en puerto $NGINX_PORT"
else
    die "No se encontró la plantilla de NGINX en $TEMPLATES_DIR"
fi

# ───────────────────────────────
# 5. Servicio Onion
create_onion_service() {
    local name="$1"
    local backend_port="$2"
    local onion_port=80

    local hs_dir="$TOR_DIR/hidden_service_$name"
    local conf_file="$SERVICES_DIR/$name.conf"
    local hs_file="$hs_dir/hostname"

    log "⚙️ Configurando servicio Onion '$name'..."
    [ -d "$hs_dir" ] && sudo rm -rf "$hs_dir"
    [ -f "$conf_file" ] && sudo rm -f "$conf_file"

    sudo mkdir -p "$hs_dir"
    sudo chmod 700 "$hs_dir"
    sudo chown -R debian-tor:debian-tor "$hs_dir"

    local template="$TEMPLATES_DIR/hidden_service.template"
    [[ -f "$template" ]] || die "Plantilla no encontrada: $template"

    sudo bash -c "sed \
        -e 's|{HS_DIR}|$hs_dir|' \
        -e 's|{ONION_PORT}|$onion_port|' \
        -e 's|{BACKEND_PORT}|$backend_port|' \
        '$template' > '$conf_file'"

    sudo chmod 640 "$conf_file"
    sudo chown root:debian-tor "$conf_file"

    if ! systemctl is-active --quiet enola-tor; then
        log "enola-tor.service no activo. Iniciando..."
        sudo systemctl start enola-tor || die "No se pudo iniciar enola-tor.service"
    fi

    sudo systemctl reload enola-tor || die "No se pudo recargar enola-tor.service"
    log "✅ Configuración de Tor aplicada, esperando hostname..."

    local timeout=60 count=0
    until [ -f "$hs_file" ] || [ $count -ge $timeout ]; do
        sleep 1; ((count++))
    done

    [[ -f "$hs_file" ]] || die "❌ No se pudo obtener la dirección Onion de '$name'"

    ONION_ADDR=$(<"$hs_file")
    log "✅ Servicio Onion '$name' creado: http://$ONION_ADDR"
}

create_onion_service "$SERVICE_NAME" "$NGINX_PORT"

# ───────────────────────────────
# 6. Resumen
cat <<EOL

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🌍 Servicio web preparado
📦 Nombre:              $SERVICE_NAME
📡 Puerto interno:       127.0.0.1:$BACKEND_PORT
📡 Puerto externo NGINX: 127.0.0.1:$NGINX_PORT
🧅 Dirección Onion:      http://$ONION_ADDR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👉 Ahora levanta tu aplicación escuchando en el puerto $BACKEND_PORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOL

/opt/enola/scripts/tor/list_services.sh
log "Script finalizado."

