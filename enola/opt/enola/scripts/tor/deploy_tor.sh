#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

# ====================================================================
# SCRIPT DE CONFIGURACIÓN Y DESPLIEGUE DE SERVICIOS OCULTOS DE TOR
# ====================================================================

SERVICES_DIR="/etc/tor/enola.d"
TOR_DIR="/var/lib/tor"
TEMPLATES_DIR="/usr/share/enola-server/templates"
TORRC="/etc/tor/torrc"
COMMON_DIR="/opt/enola/scripts/common"

# Importar utilidades de puertos
source "$COMMON_DIR/port_utils.sh" || { echo "Error: No se pudo cargar port_utils.sh"; exit 1; }

log()   { echo "[TOR_DEPLOY] $(date '+%F %T') | $*" >&2; }
die()   { echo "[TOR_DEPLOY] $(date '+%F %T') | ERROR | $*" >&2; exit 1; }

# --------------------------------------------------------------------
# Asegurarse de que Tor esté activo y habilitado
# --------------------------------------------------------------------
if ! systemctl is-active --quiet enola-tor; then
    log "enola-tor.service no activo. Iniciando servicio..."
    systemctl start enola-tor || die "No se pudo iniciar enola-tor.service"
fi
systemctl enable enola-tor || log "⚠️ No se pudo habilitar enola-tor.service al inicio"

# --------------------------------------------------------------------
# Crear directorio de configuraciones
# --------------------------------------------------------------------
mkdir -p "$SERVICES_DIR"
chmod 755 "$SERVICES_DIR"

# Incluir configs en torrc si no está ya incluido
if ! grep -qF "%include $SERVICES_DIR/*.conf" "$TORRC"; then
    echo "%include $SERVICES_DIR/*.conf" >> "$TORRC"
    chmod 640 "$TORRC"
    chown root:debian-tor "$TORRC"
    log "Incluido $SERVICES_DIR/*.conf en $TORRC"
else
    log "✅ $TORRC ya incluye $SERVICES_DIR/*.conf"
fi


# --------------------------------------------------------------------
# Función para crear servicios
# --------------------------------------------------------------------
create_service() {
    local name="$1"
    local backend_port="$2"
    local onion_port="$3"

    local hs_dir="$TOR_DIR/hidden_service_$name"
    local conf_file="$SERVICES_DIR/$name.conf"

    log "Configurando servicio $name..."

    # Limpiar si existe
    [ -d "$hs_dir" ] && rm -rf "$hs_dir"

    # Crear directorio y aplicar permisos correctos
    mkdir -p "$hs_dir"
    chmod 700 "$hs_dir"
    chown -R debian-tor:debian-tor "$hs_dir"

    # Aplicar plantilla
    local template_file="$TEMPLATES_DIR/hidden_service.template"
    [ -f "$template_file" ] || die "Plantilla no encontrada: $template_file"

    sed "s|{HS_DIR}|$hs_dir|; s|{ONION_PORT}|$onion_port|; s|{BACKEND_PORT}|$backend_port|" \
        "$template_file" > "$conf_file"
    chmod 640 "$conf_file"
    chown root:debian-tor "$conf_file"

    log "Servicio $name configurado en $conf_file"
}

# --------------------------------------------------------------------
# Función para esperar hostname con timeout
# --------------------------------------------------------------------
wait_for_onion() {
    local name="$1"
    local hs_dir="$TOR_DIR/hidden_service_$name"
    local hs_file="$hs_dir/hostname"
    local timeout=30
    local waited=0

    log "Esperando hostname para servicio '$name'..."

    until [ -f "$hs_file" ] || [ $waited -ge $timeout ]; do
        sleep 1
        waited=$((waited+1))
    done

    if [ -f "$hs_file" ]; then
        local onion
        onion=$(<"$hs_file")
        log "✅ Servicio onion '$name' activo en: $onion"
    else
        die "⛔ No se pudo generar hostname de '$name' en $timeout segundos. Verifica la configuración de Tor."
    fi
}

# --------------------------------------------------------------------
# MAIN: crear servicios
# --------------------------------------------------------------------
# Nota: El servicio "web" ya NO se crea automáticamente
# El usuario puede crearlo manualmente cuando lo necesite mediante:
#   - deploy_tor_web.sh (servicio web personalizado)
#   - generate_wordpress.sh (WordPress)

SSH_SERVICE="ssh"
SSH_BACKEND_PORT=22
SSH_ONION_PORT="${SSH_TOR_PORT:-2222}"

create_service "$SSH_SERVICE" "$SSH_BACKEND_PORT" "$SSH_ONION_PORT"

# --------------------------------------------------------------------
# Reiniciar enola-tor.service para aplicar cambios
# --------------------------------------------------------------------
log "Reiniciando enola-tor.service para aplicar cambios..."
systemctl restart enola-tor
if ! systemctl is-active --quiet enola-tor; then
    journalctl -u enola-tor -n 20 --no-pager
    die "Tor no pudo iniciar"
fi
log "✅ enola-tor.service reiniciado correctamente."

# --------------------------------------------------------------------
# Esperar hostnames
# --------------------------------------------------------------------
wait_for_onion "$SSH_SERVICE"

# --------------------------------------------------------------------
# RESUMEN
# --------------------------------------------------------------------
SSH_ONION=$(<"$TOR_DIR/hidden_service_$SSH_SERVICE/hostname")

cat <<EOL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧅 Servicio Onion desplegado
🔐 SSH:    ssh -p $SSH_ONION_PORT usuario@$SSH_ONION

💡 Tip: Para crear un servicio web, usa:
   • enola-server → Opción Tor → Añadir servicio web
   • sudo bash /opt/enola/scripts/wordpress/generate_wordpress.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOL

log "🎉 Despliegue completado."
