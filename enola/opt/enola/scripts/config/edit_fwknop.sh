#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

# ====================================================================
# SCRIPT INTERACTIVO DE EDICIÓN FWKNOP
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
    local current="$2"
    read -p "$label [$current]: " input
    echo "${input:-$current}"
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
# 1. Verificar plantilla
# ===========================
[[ ! -f "$TEMPLATE" ]] && die "Plantilla FWKNOP no encontrada: $TEMPLATE"

# ===========================
# 2. Extraer valores actuales del template
# ===========================
CURRENT_SOURCE=$(grep -E '^SOURCE' "$TEMPLATE" | awk '{print $2}' || echo "ANY")
CURRENT_OPEN_PORTS=$(grep -E '^OPEN_PORTS' "$TEMPLATE" | awk '{print $2}' || echo "tcp/2222")
CURRENT_GPG_HOME=$(grep -E '^GPG_HOME' "$TEMPLATE" | awk '{print $2}' || echo "/root/.gnupg")
CURRENT_GPG_DECRYPT_ID=$(grep -E '^GPG_DECRYPT_ID' "$TEMPLATE" | awk '{print $2}' || echo "YOUR_DEFAULT_FINGERPRINT_HERE")
CURRENT_ENABLE_IPT_AUTO_RULES=$(grep -E '^ENABLE_IPT_AUTO_RULES' "$TEMPLATE" | awk '{print $2}' || echo "Y")
CURRENT_FW_ACCESS_TIMEOUT=$(grep -E '^FW_ACCESS_TIMEOUT' "$TEMPLATE" | awk '{print $2}' || echo "30")

# ===========================
# 3. Pedir nuevos valores al usuario
# ===========================
echo "Edita la configuración de FWKNOP (ENTER para mantener valor actual)"
SOURCE=$(prompt_var "SOURCE" "$CURRENT_SOURCE")
OPEN_PORTS=$(prompt_var "OPEN_PORTS" "$CURRENT_OPEN_PORTS")
GPG_HOME=$(prompt_var "GPG_HOME" "$CURRENT_GPG_HOME")
GPG_DECRYPT_ID=$(prompt_var "GPG_DECRYPT_ID" "$CURRENT_GPG_DECRYPT_ID")
ENABLE_IPT_AUTO_RULES=$(prompt_var "ENABLE_IPT_AUTO_RULES" "$CURRENT_ENABLE_IPT_AUTO_RULES")
FW_ACCESS_TIMEOUT=$(prompt_var "FW_ACCESS_TIMEOUT" "$CURRENT_FW_ACCESS_TIMEOUT")

# ===========================
# 4. Hacer backup del access.conf si existe
# ===========================
[[ -f "$ACCESS_CONF" ]] && cp "$ACCESS_CONF" "${ACCESS_CONF}.bak" && log "Backup de access.conf creado."

# ===========================
# 5. Aplicar plantilla con los nuevos valores
# ===========================
apply_template "$TEMPLATE" "$ACCESS_CONF" \
    "\$SOURCE" "$SOURCE" \
    "\$OPEN_PORTS" "$OPEN_PORTS" \
    "\$GPG_HOME" "$GPG_HOME" \
    "\$GPG_DECRYPT_ID" "$GPG_DECRYPT_ID" \
    "\$ENABLE_IPT_AUTO_RULES" "$ENABLE_IPT_AUTO_RULES" \
    "\$FW_ACCESS_TIMEOUT" "$FW_ACCESS_TIMEOUT"

chmod 600 "$ACCESS_CONF"
log "✅ access.conf actualizado con éxito."

# ===========================
# 6. Reiniciar fwknopd
# ===========================
systemctl restart fwknopd || die "No se pudo reiniciar fwknopd."
log "🚀 fwknopd reiniciado con la nueva configuración."
