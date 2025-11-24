#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Script para generar certificados SSL autofirmados para servicios .onion

set -euo pipefail

log() { echo -e "[SSL-GEN] $(date '+%F %T') | $*"; }
die() { echo -e "[SSL-GEN] $(date '+%F %T') | ERROR | $*" >&2; exit 1; }

# Parámetros
ONION_HOSTNAME="$1"
OUTPUT_DIR="$2"
CERT_NAME="${3:-onion}"

[ -z "$ONION_HOSTNAME" ] && die "Uso: $0 <onion_hostname> <output_dir> [cert_name]"
[ -z "$OUTPUT_DIR" ] && die "Uso: $0 <onion_hostname> <output_dir> [cert_name]"

# Crear directorio si no existe
mkdir -p "$OUTPUT_DIR"
chmod 750 "$OUTPUT_DIR"

CERT_FILE="$OUTPUT_DIR/${CERT_NAME}.crt"
KEY_FILE="$OUTPUT_DIR/${CERT_NAME}.key"

# Verificar si ya existe
if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
    log "ℹ️  Certificado existente encontrado, regenerando..."
fi

log "🔧 Generando certificado SSL autofirmado para: $ONION_HOSTNAME"

# Generar certificado SSL autofirmado válido por 10 años
openssl req -x509 -nodes \
    -days 3650 \
    -newkey rsa:4096 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/C=XX/ST=Anonymous/L=Anonymous/O=Tor Hidden Service/OU=Enola Server/CN=${ONION_HOSTNAME}" \
    -addext "subjectAltName=DNS:${ONION_HOSTNAME},DNS:www.${ONION_HOSTNAME}" \
    2>/dev/null

# Establecer permisos seguros
chmod 640 "$KEY_FILE" "$CERT_FILE"
chown root:root "$KEY_FILE" "$CERT_FILE"

log "✅ Certificado generado:"
log "   📄 Certificado: $CERT_FILE"
log "   🔑 Clave privada: $KEY_FILE"
log "   📅 Válido por: 10 años"
log "   🌐 Dominio: $ONION_HOSTNAME"

# Mostrar información del certificado
openssl x509 -in "$CERT_FILE" -noout -subject -dates 2>/dev/null | sed 's/^/   /'

exit 0
