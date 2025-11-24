#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

# ====================================================================
# SCRIPT PARA ANADIR CLAVE PUBLICA SSH
#
# Este script solicita al usuario una clave publica SSH y la anade
# al archivo authorized_keys para permitir el acceso sin contrasena.
# ====================================================================

# Funciones de logging
log()   { echo -e "[\e[32mOK\e[0m] $*"; }
warn()  { echo -e "[\e[33mWARNING\e[0m] $*" >&2; }
error() { echo -e "[\e[31mERROR\e[0m] $*" >&2; exit 1; }

# ========================
# 1. Pedir al usuario datos necesarios
# ========================
read -rp "👤 Nombre del usuario del servidor: " TARGET_USER
# ✅ SOLUCION: Usamos echo para mostrar el prompt y read para la entrada
echo -n "🔑 Pega la clave publica SSH aqui: "
read PUBKEY_INPUT

# ========================
# 2. Validaciones
# ========================
[[ -z "$TARGET_USER" || -z "$PUBKEY_INPUT" ]] && error "Usuario o clave vacios"
id "$TARGET_USER" &>/dev/null || error "El usuario $TARGET_USER no existe"

# Validar formato aproximado de clave publica
if [[ ! "$PUBKEY_INPUT" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
    error "Formato de clave invalido. Asegurate de que comience con ssh-ed25519, ssh-rsa, etc."
fi

# ========================
# 3. Preparar directorios y archivos
# ========================
USER_HOME=$(eval echo "~$TARGET_USER")
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
touch "$AUTHORIZED_KEYS"

# ========================
# 4. Evitar duplicados
# ========================
if grep -qF -- "$PUBKEY_INPUT" "$AUTHORIZED_KEYS"; then
    warn "La clave ya existe en authorized_keys"
else
    echo "$PUBKEY_INPUT" >> "$AUTHORIZED_KEYS"
    log "Clave agregada correctamente para $TARGET_USER"
fi

# ========================
# 5. Ajustar permisos y propietario
# ========================
chown -R "$TARGET_USER:$TARGET_USER" "$SSH_DIR"
chmod 700 "$SSH_DIR"
chmod 600 "$AUTHORIZED_KEYS"

log "✅ authorized_keys actualizado para $TARGET_USER"
