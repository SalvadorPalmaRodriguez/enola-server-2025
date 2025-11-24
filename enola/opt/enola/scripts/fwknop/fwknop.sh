#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

# ====================================================================
# SCRIPT DE CONFIGURACIÓN FWKNOP (SPA)
# ====================================================================

TEMPLATES_DIR="/usr/share/enola-server/templates"
TEMPLATE="$TEMPLATES_DIR/fwknop"
ACCESS_CONF="/etc/fwknop/access.conf"

# Funciones de logging
log()   { echo -e "[FWKNOP] $(date '+%F %T') | $*"; }
warn()  { echo -e "[FWKNOP] $(date '+%F %T') | WARN | $*"; }
die()   { echo -e "[FWKNOP] $(date '+%F %T') | ERROR | $*"; exit 1; }

# Función para pedir valor al usuario
prompt_var() {
    local label="$1"
    local default="$2"
    read -p "$label [$default]: " input
    echo "${input:-$default}"
}

# Función para aplicar plantilla con reemplazo de placeholders
apply_template() {
    local template="$1"
    local dest="$2"
    shift 2
    local content
    content=$(cat "$template")
    while [ "$#" -gt 0 ]; do
        local placeholder="$1"
        local value="$2"
        content="${content//$placeholder/$value}"
        shift 2
    done
    echo "$content" > "$dest"
}

# ===========================
# 1. Definir variables editables
# ===========================
echo "Configura FWKNOP (deja vacío para valores por defecto)"
SOURCE=$(prompt_var "SOURCE" "ANY")
OPEN_PORTS=$(prompt_var "OPEN_PORTS" "tcp/2222")
GPG_HOME=$(prompt_var "GPG_HOME" "/root/.gnupg")
GPG_DECRYPT_ID=$(prompt_var "GPG_DECRYPT_ID" "YOUR_DEFAULT_FINGERPRINT_HERE")
ENABLE_IPT_AUTO_RULES=$(prompt_var "ENABLE_IPT_AUTO_RULES" "Y")
FW_ACCESS_TIMEOUT=$(prompt_var "FW_ACCESS_TIMEOUT" "30")

# ===========================
# 2. Verificar template
# ===========================
[[ ! -f "$TEMPLATE" ]] && die "Plantilla FWKNOP no encontrada: $TEMPLATE"

# ===========================
# 3. Hacer backup de access.conf
# ===========================
[[ -f "$ACCESS_CONF" ]] && cp "$ACCESS_CONF" "${ACCESS_CONF}.bak" && log "Backup de access.conf creado."

# ===========================
# 4. Aplicar plantilla
# ===========================
apply_template "$TEMPLATE" "$ACCESS_CONF" \
    "\$SOURCE" "$SOURCE" \
    "\$OPEN_PORTS" "$OPEN_PORTS" \
    "\$GPG_HOME" "$GPG_HOME" \
    "\$GPG_DECRYPT_ID" "$GPG_DECRYPT_ID" \
    "\$ENABLE_IPT_AUTO_RULES" "$ENABLE_IPT_AUTO_RULES" \
    "\$FW_ACCESS_TIMEOUT" "$FW_ACCESS_TIMEOUT"

chmod 600 "$ACCESS_CONF"
log "✅ access.conf generado con éxito."

# ===========================
# 5. Reiniciar fwknopd
# ===========================
systemctl restart fwknopd || die "No se pudo reiniciar fwknopd."
log "🚀 fwknopd reiniciado y configuración aplicada."
