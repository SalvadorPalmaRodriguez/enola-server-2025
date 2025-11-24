#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail # Exit immediately if a command fails or a variable is not defined.

# ====================================================================
# SCRIPT DE CONFIGURACION Y DESPLIEGUE DE NGINX
# ====================================================================

# Rutas principales del proyecto
SHARE_DIR="/usr/share/enola-server"
TEMPLATES_DIR="$SHARE_DIR/templates"
CONFIG_PATH="/etc/nginx/sites-available/default"

# Funciones de Logging
log()   { echo -e "[NGINX_CONFIG] $(date '+%F %T') | $*" >&2; }
warn()  { echo -e "[NGINX_CONFIG] $(date '+%F %T') | WARN | $*" >&2; }
error() { echo -e "[NGINX_CONFIG] $(date '+%F %T') | ERROR | $*" >&2; }
die()   { error "$*"; exit 1; }

# La logica principal del script
log "Iniciando configuracion de NGINX..."

# ====================================================================
# IMPORTANTE: Este script solo se ejecuta si existe el servicio web
# El servicio "web" ya NO se crea automáticamente en la instalación
# El usuario debe crearlo manualmente cuando lo necesite
# ====================================================================

# Verificar si existe el servicio web en Tor
if [ ! -f "/etc/tor/enola.d/web.conf" ]; then
    log "⚠️  No existe servicio web Tor. Saltando configuración de NGINX."
    log "💡 Para crear un servicio web, usa:"
    log "   • enola-server → Opción Tor → Añadir servicio web"
    log "   • sudo bash /opt/enola/scripts/tor/deploy_tor_web.sh"
    exit 0
fi

# Variables por defecto
NGINX_EXTERNAL="80"
LOG_DIR="/var/log/enola-server"

# Verificamos que NGINX y envsubst estén instalados
if ! command -v nginx &>/dev/null; then
    die "NGINX no esta instalado. Por favor, asegurese de que el paquete 'nginx' este instalado."
fi

if ! command -v envsubst &>/dev/null; then
    die "La herramienta 'envsubst' no esta instalada. Por favor, instale el paquete 'gettext'."
fi

log "NGINX detectado. Procediendo con la configuracion."

# Función para encontrar puerto libre
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
        
        # Verificar si está usado en configuraciones de Tor
        if grep -rq "127.0.0.1:${port}" /etc/tor/enola.d/*.conf 2>/dev/null; then
            continue
        fi
        
        echo "$port"
        return 0
    done
    
    return 1
}

# Intentar obtener el puerto del servicio web Tor si ya existe
# Este será el puerto donde NGINX debe escuchar
if [ -f "/etc/tor/enola.d/web.conf" ]; then
    NGINX_EXTERNAL=$(grep "HiddenServicePort" /etc/tor/enola.d/web.conf | grep "127.0.0.1:" | head -1 | sed 's/.*127.0.0.1://' | awk '{print $1}')
    if [ -n "$NGINX_EXTERNAL" ]; then
        log "NGINX escuchará en el puerto del servicio web Tor: $NGINX_EXTERNAL"
    fi
fi

# Si no existe o no se pudo obtener, buscar puerto libre
if [ -z "$NGINX_EXTERNAL" ]; then
    NGINX_EXTERNAL=$(find_free_port 8000 9000)
    if [ -z "$NGINX_EXTERNAL" ]; then
        die "No se pudo encontrar un puerto libre entre 8000-9000 para NGINX"
    fi
    log "Puerto libre encontrado para NGINX: $NGINX_EXTERNAL"
fi

# Puerto del backend (aplicación real, no NGINX)
# Buscar puerto libre para el backend
BACKEND_PORT=$(find_free_port 8080 8200)
if [ -z "$BACKEND_PORT" ]; then
    die "No se pudo encontrar un puerto libre entre 8080-8200 para el backend"
fi
log "Puerto libre encontrado para backend: $BACKEND_PORT"

# Creamos el directorio de logs si no existe
log "Creando directorio de logs de NGINX si no existe: $LOG_DIR"
mkdir -p "$LOG_DIR" || die "Fallo al crear el directorio de logs: $LOG_DIR."
chown -R www-data:adm "$LOG_DIR" || warn "Fallo al cambiar los permisos del directorio de logs. Pueden ocurrir problemas."

# Creamos el archivo de configuracion de NGINX
log "Configurando NGINX en: $CONFIG_PATH"

log "Configurando NGINX en: $CONFIG_PATH"

# Exportar variables para envsubst
export BACKEND_PORT LOG_DIR NGINX_EXTERNAL

# Sustituir variables en plantilla
envsubst '$NGINX_EXTERNAL $BACKEND_PORT $LOG_DIR' < "$TEMPLATES_DIR/nginx.template" > "$CONFIG_PATH"


# Verificamos sintaxis de NGINX
log "Verificando sintaxis de la configuracion de NGINX..."
nginx -t || die "Error en la configuracion de NGINX. Por favor, revise los logs de error."

# Reiniciamos NGINX
log "Reiniciando NGINX para aplicar cambios..."
systemctl restart nginx || die "Fallo al reiniciar NGINX. Verifique el estado del servicio."

# Habilitamos NGINX al inicio
log "Asegurando que NGINX se inicie automaticamente al arrancar el sistema."
systemctl enable nginx || warn "Fallo al habilitar NGINX al inicio."

log "✅ Configuracion de NGINX completada correctamente."

