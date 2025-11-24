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

# Cargar validador de puertos
if [ -f "/opt/enola/scripts/common/port_validator.sh" ]; then
    source "/opt/enola/scripts/common/port_validator.sh"
fi


# Función para loguear con timestamp
log() {
    echo -e "[WORDPRESS] $(date '+%F %T') | $1"
}

# Función para mostrar error y salir
die() {
    echo -e "[WORDPRESS] $(date '+%F %T') | ERROR | $1"
    exit 1
}

# Buscar un puerto libre (host, contenedores y config de NGINX)
find_free_port() {
    local start=$1 end=$2 port
    for port in $(seq "$start" "$end"); do
        # ¿Usado en el host?
        if ss -tulnH | awk '{print $5}' | grep -q ":$port$"; then
            continue
        fi

        # ¿Publicado por un contenedor?
        if podman ps --format '{{.Ports}}' | grep -q ":$port->"; then
            continue
        fi

        # ¿Ya definido en algún conf de NGINX?
        if grep -R "listen .*:$port" /etc/nginx/sites-enabled/* >/dev/null 2>&1; then
            continue
        fi

        echo "$port"
        return 0
    done
    return 1
}

# Chequear que el puerto esté efectivamente libre
check_port() {
    local port=$1
    if ss -tulnH | awk '{print $5}' | grep -q ":$port$"; then
        die "El puerto $port ya está en uso"
    fi
}

# Esperar que un puerto esté escuchando (para WordPress)
wait_for_port() {
    local port=$1 timeout=${2:-30} count=0
    while ! ss -tulnH | grep -q ":$port\b"; do
        sleep 1
        count=$((count + 1))
        if [[ $count -ge $timeout ]]; then
            die "Timeout esperando puerto $port"
        fi
    done
}

# ───────────────────────────────────────────────────────────────
# 1. Preguntar nombre del servicio
while true; do
    read -rp "👉 Ingresa el nombre del servicio WordPress: " SERVICE_NAME
    [[ -z "$SERVICE_NAME" ]] && continue

    SERVICE_CONF="/etc/tor/enola.d/${SERVICE_NAME}.conf"
    HS_DIR="/var/lib/tor/hidden_service_${SERVICE_NAME}"

    if [[ -f "$SERVICE_CONF" || -d "$HS_DIR" ]]; then
        echo "⚠️ El servicio $SERVICE_NAME ya existe, elige otro."
        continue
    fi
    break
done

# ───────────────────────────────────────────────────────────────
# 2. Variables dinámicas
WP_DB_NAME="wordpress_${SERVICE_NAME}"
WP_DB_USER="wp_user_${SERVICE_NAME}"
WP_DB_PASS="$(openssl rand -base64 16)"
WP_DB_ROOT_PASS="$(openssl rand -base64 20)"
PODMAN_NETWORK="enola_net_${SERVICE_NAME}"
DEST_CONFIG="/opt/enola/wordpress/${SERVICE_NAME}.env"
LOG_DIR="/var/log/enola-server/${SERVICE_NAME}"
CONFIG_PATH="/etc/nginx/sites-available/${SERVICE_NAME}.conf"
TEMPLATES_DIR="/usr/share/enola-server/templates"
DB_CONTAINER="enola-${SERVICE_NAME}-mysql"
WP_CONTAINER="enola-${SERVICE_NAME}-wp"

# ───────────────────────────────────────────────────────────────
# 3. Crear red interna
if ! podman network exists "$PODMAN_NETWORK"; then
    podman network create "$PODMAN_NETWORK"
    log "✅ Red interna creada: $PODMAN_NETWORK"
fi

# ───────────────────────────────────────────────────────────────
# 4. Asignar puertos
BACKEND_PORT=$(find_free_port 8080 8100) || die "No se encontró puerto interno libre"
NGINX_HTTP_PORT=$(find_free_port 9000 9100) || die "No se encontró puerto HTTP libre"
NGINX_HTTPS_PORT=$(find_free_port 9100 9200) || die "No se encontró puerto HTTPS libre"

log "✅ Puerto interno WP: $BACKEND_PORT"
log "✅ Puerto externo NGINX HTTP: $NGINX_HTTP_PORT"
log "✅ Puerto externo NGINX HTTPS: $NGINX_HTTPS_PORT"

check_port "$BACKEND_PORT"
check_port "$NGINX_HTTP_PORT"
check_port "$NGINX_HTTPS_PORT"

# ───────────────────────────────────────────────────────────────
# 5. Contenedor MySQL
if ! podman container exists "$DB_CONTAINER"; then
    podman run -d \
        --name "$DB_CONTAINER" \
        --network "$PODMAN_NETWORK" \
        -e MYSQL_ROOT_PASSWORD="$WP_DB_ROOT_PASS" \
        -e MYSQL_DATABASE="$WP_DB_NAME" \
        -e MYSQL_USER="$WP_DB_USER" \
        -e MYSQL_PASSWORD="$WP_DB_PASS" \
        --restart=always \
        docker.io/library/mysql:8.0
    log "✅ Contenedor MySQL levantado: $DB_CONTAINER"
fi

# ───────────────────────────────────────────────────────────────
# 6. Generar archivo de entorno para WordPress
mkdir -p "$(dirname "$DEST_CONFIG")"
cat >"$DEST_CONFIG" <<EOF
WORDPRESS_DB_HOST=$DB_CONTAINER
WORDPRESS_DB_NAME=$WP_DB_NAME
WORDPRESS_DB_USER=$WP_DB_USER
WORDPRESS_DB_PASSWORD=$WP_DB_PASS
EOF
chmod 600 "$DEST_CONFIG"
log "✅ Archivo de configuración generado en $DEST_CONFIG"

# ───────────────────────────────────────────────────────────────
# 7. Contenedor WordPress
if ! podman container exists "$WP_CONTAINER"; then
    podman run -d \
        --name "$WP_CONTAINER" \
        --network "$PODMAN_NETWORK" \
        --env-file "$DEST_CONFIG" \
        -p 127.0.0.1:${BACKEND_PORT}:80 \
        --restart=always \
        docker.io/library/wordpress:latest
    log "✅ Contenedor WordPress levantado: $WP_CONTAINER"
fi

# Esperar a que WordPress esté disponible
wait_for_port "$BACKEND_PORT"
log "✅ WordPress levantado internamente en 127.0.0.1:$BACKEND_PORT"

# ───────────────────────────────────────────────────────────────
# 8. Configuración de NGINX con SSL
mkdir -p "$LOG_DIR"

# Primero necesitamos crear el servicio Onion para obtener el hostname
# Crear directorio del servicio oculto temporalmente
TEMP_HS_DIR="$TOR_DIR/hidden_service_${SERVICE_NAME}"
sudo mkdir -p "$TEMP_HS_DIR"
sudo chmod 700 "$TEMP_HS_DIR"
sudo chown -R debian-tor:debian-tor "$TEMP_HS_DIR"

# Crear configuración temporal de Tor para generar el hostname
TEMP_TOR_CONF="$SERVICES_DIR/${SERVICE_NAME}.conf"
sudo bash -c "cat > '$TEMP_TOR_CONF' <<EOF
HiddenServiceDir $TEMP_HS_DIR
HiddenServiceVersion 3
HiddenServicePort 80 127.0.0.1:$NGINX_HTTP_PORT
EOF"
sudo chmod 640 "$TEMP_TOR_CONF"
sudo chown root:debian-tor "$TEMP_TOR_CONF"

# Recargar Tor para generar hostname
if systemctl is-active --quiet enola-tor; then
    sudo systemctl reload enola-tor
else
    sudo systemctl start enola-tor
fi

# Esperar a que se genere el hostname
log "⏳ Esperando generación de dirección .onion..."
TEMP_HS_FILE="$TEMP_HS_DIR/hostname"
timeout=60
count=0
until [ -f "$TEMP_HS_FILE" ] || [ $count -ge $timeout ]; do
    sleep 1
    ((count++))
done

[[ -f "$TEMP_HS_FILE" ]] || die "❌ No se pudo generar dirección .onion"
ONION_HOSTNAME=$(sudo cat "$TEMP_HS_FILE")
log "✅ Dirección .onion generada: $ONION_HOSTNAME"

# Generar certificado SSL para el dominio .onion
SSL_DIR="/etc/enola-server/ssl/${SERVICE_NAME}"
sudo mkdir -p "$SSL_DIR"
sudo chmod 750 "$SSL_DIR"

SSL_CERT="$SSL_DIR/onion.crt"
SSL_KEY="$SSL_DIR/onion.key"

log "🔐 Generando certificado SSL autofirmado..."
sudo bash /opt/enola/scripts/common/generate_ssl_cert.sh "$ONION_HOSTNAME" "$SSL_DIR" "onion"

# Configurar NGINX con SSL
if [[ -f "$TEMPLATES_DIR/nginx_ssl.template" ]]; then
    export BACKEND_PORT NGINX_EXTERNAL="$NGINX_HTTP_PORT" NGINX_EXTERNAL_SSL="$NGINX_HTTPS_PORT" \
           LOG_DIR SERVICE_NAME ONION_ADDRESS="$ONION_HOSTNAME" SSL_CERT SSL_KEY
    envsubst '${BACKEND_PORT} ${NGINX_EXTERNAL} ${NGINX_EXTERNAL_SSL} ${LOG_DIR} ${SERVICE_NAME} ${ONION_ADDRESS} ${SSL_CERT} ${SSL_KEY}' \
        < "$TEMPLATES_DIR/nginx_ssl.template" > "$CONFIG_PATH"
    ln -sf "$CONFIG_PATH" "/etc/nginx/sites-enabled/${SERVICE_NAME}.conf"
    nginx -t || die "Error en la configuración de NGINX"
    
    # Iniciar NGINX si no está activo, o recargar si ya está corriendo
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx || die "No se pudo recargar NGINX"
    else
        systemctl start nginx || die "No se pudo iniciar NGINX"
    fi
    
    log "✅ NGINX configurado con SSL en puertos HTTP:$NGINX_HTTP_PORT, HTTPS:$NGINX_HTTPS_PORT"
else
    die "No se encontró la plantilla de NGINX SSL en $TEMPLATES_DIR"
fi

# Generar servicios systemd para que arranquen siempre
# Los archivos se crean en el directorio actual, así que usamos un temp dir controlado
SYSTEMD_TEMP=$(mktemp -d)
trap "rm -rf '$SYSTEMD_TEMP'" EXIT

cd "$SYSTEMD_TEMP" || die "No se pudo crear directorio temporal para systemd"
podman generate systemd --name "$DB_CONTAINER" --files --new --restart-policy=always
podman generate systemd --name "$WP_CONTAINER" --files --new --restart-policy=always

# Verificar que se generaron y mover a la ubicación estándar de systemd
if [[ -f "container-$DB_CONTAINER.service" ]] && [[ -f "container-$WP_CONTAINER.service" ]]; then
    sudo mv "container-$DB_CONTAINER.service" "container-$WP_CONTAINER.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable "container-$DB_CONTAINER.service" "container-$WP_CONTAINER.service"
    sudo systemctl start "container-$DB_CONTAINER.service" "container-$WP_CONTAINER.service"
    log "✅ Servicios systemd creados y habilitados en /etc/systemd/system/"
    cd - >/dev/null
else
    cd - >/dev/null
    warn "⚠️ No se pudieron generar los servicios systemd. Los contenedores funcionan pero no arrancarán automáticamente al reiniciar."
fi
# ==========================
# SERVICIO ONION
# ==========================
# ==========================
# SERVICIO ONION (AUTÓNOMO)
# ==========================
create_onion_service() {
    local name="$1"
    local http_port="$2"
    local https_port="$3"

    local hs_dir="$TOR_DIR/hidden_service_$name"
    local conf_file="$SERVICES_DIR/$name.conf"
    local hs_file="$hs_dir/hostname"

    log "⚙️ Actualizando servicio Onion '$name' con soporte SSL..."

    # El directorio ya existe de la configuración temporal
    # Solo actualizamos la configuración de Tor

    # Aplicar plantilla SSL de configuración de Tor
    local template="$TEMPLATES_DIR/hidden_service_ssl.template"
    [[ -f "$template" ]] || die "Plantilla SSL no encontrada: $template"

    sudo bash -c "sed \
        -e 's|{HS_DIR}|$hs_dir|' \
        -e 's|{NGINX_HTTP_PORT}|$http_port|' \
        -e 's|{NGINX_HTTPS_PORT}|$https_port|' \
        '$template' > '$conf_file'"

    # Permisos correctos
    sudo chmod 640 "$conf_file"
    sudo chown root:debian-tor "$conf_file"

    # Recargar Tor para aplicar la configuración SSL
    sudo systemctl reload enola-tor || die "No se pudo recargar enola-tor.service"
    log "✅ Configuración de Tor actualizada con HTTP (80) y HTTPS (443)"

    ONION_ADDR=$(<"$hs_file")
    log "✅ Servicio Onion '$name' con SSL: https://$ONION_ADDR"
}

# ----------------------------
# Llamada al servicio Onion
# ----------------------------
create_onion_service "$SERVICE_NAME" "$NGINX_HTTP_PORT" "$NGINX_HTTPS_PORT"


# ==========================
# RESUMEN
# ==========================
cat <<EOL

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🌍 WordPress desplegado con SSL
📦 Contenedor MySQL:  $DB_CONTAINER
📦 Contenedor WP:     $WP_CONTAINER
📡 Puerto interno:    127.0.0.1:$BACKEND_PORT
📡 Puerto NGINX HTTP:  127.0.0.1:$NGINX_HTTP_PORT
📡 Puerto NGINX HTTPS: 127.0.0.1:$NGINX_HTTPS_PORT
🧅 Dirección Onion HTTP:  http://$ONION_ADDR
🔐 Dirección Onion HTTPS: https://$ONION_ADDR
🔑 Certificado SSL: $SSL_CERT
⚙️ Archivo env:       $DEST_CONFIG
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ Abre https://$ONION_ADDR en Tor Browser para acceder con SSL.
⚠️ Acepta el certificado autofirmado cuando el navegador lo solicite.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOL
/opt/enola/scripts/tor/list_services.sh
