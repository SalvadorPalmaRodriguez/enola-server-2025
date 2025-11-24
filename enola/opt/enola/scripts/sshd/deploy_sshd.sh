#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

# === Funciones de log ===
log()    { echo -e "[\e[32mOK\e[0m] $*"; }
warn()   { echo -e "[\e[33mWARNING\e[0m] $*" >&2; }
error()  { echo -e "[\e[31mERROR\e[0m] $*" >&2; exit 1; }

# === Función: Configurar SSH seguro ===
configurar_ssh() {
    read -rp "👤 Ingresa el nombre del usuario del sistema: " MY_USER
    read -rp "🔐 Ingresa el puerto SSH deseado (recomendado: 2222): " SSH_PORT
    SSH_PORT="${SSH_PORT:-2222}"

    id "$MY_USER" &>/dev/null || error "El usuario $MY_USER no existe"

    # === Restaurar sshd_config si no existe ===
    SSHD_CONFIG="/etc/ssh/sshd_config"
    if [[ ! -f "$SSHD_CONFIG" ]]; then
        warn "$SSHD_CONFIG no existe, restaurando archivo por defecto..."
        sudo cp /usr/share/openssh/sshd_config "$SSHD_CONFIG"
        sudo chown root:root "$SSHD_CONFIG"
        sudo chmod 600 "$SSHD_CONFIG"
        log "Archivo sshd_config restaurado"
    fi

    # Reiniciar SSH si está caído
    if ! systemctl is-active --quiet ssh; then
        log "🔄 Servicio SSH no activo, iniciando..."
        sudo systemctl daemon-reload
        sudo systemctl reset-failed ssh
        sudo systemctl start ssh
        sudo systemctl enable ssh
        log "Servicio SSH iniciado"
    fi

    # === Agregar clave pública ===
    read -p "🔑 Pega la clave pública SSH aquí: " PUBKEY_INPUT
    if [[ -z "$PUBKEY_INPUT" ]]; then
        warn "Clave pública vacía, no se agregará"
        return
    fi
    if [[ ! "$PUBKEY_INPUT" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
        warn "Formato de clave inválido. Debe comenzar con ssh-ed25519, ssh-rsa, etc."
        return
    fi

    USER_HOME=$(eval echo "~$MY_USER")
    SSH_DIR="$USER_HOME/.ssh"
    AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

    mkdir -p "$SSH_DIR"
    touch "$AUTHORIZED_KEYS"

    if grep -Fxq "$PUBKEY_INPUT" "$AUTHORIZED_KEYS"; then
        warn "La clave ya existe en authorized_keys"
    else
        echo "$PUBKEY_INPUT" >> "$AUTHORIZED_KEYS"
        log "Clave agregada correctamente para $MY_USER"
    fi

    chown -R "$MY_USER:$MY_USER" "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    chmod 600 "$AUTHORIZED_KEYS"
    log "Permisos de .ssh corregidos"

    # === Configuración endurecida de sshd_config ===
    cp "$SSHD_CONFIG" "$SSHD_CONFIG.bak.$(date +%Y%m%d_%H%M%S)"
    log "Backup de sshd_config creado"

    sed -i '/^ListenAddress/d' "$SSHD_CONFIG"

    declare -A CONFIGS=(
      [Port]="$SSH_PORT"
      [ListenAddress]=127.0.0.1
      [PermitRootLogin]=no
      [PasswordAuthentication]=no
      [PubkeyAuthentication]=yes
      [ChallengeResponseAuthentication]=no
      [UsePAM]=no
      [AllowTcpForwarding]=no
      [X11Forwarding]=no
      [LoginGraceTime]=30
      [MaxAuthTries]=3
      [MaxSessions]=2
    )

    for key in "${!CONFIGS[@]}"; do
        value="${CONFIGS[$key]}"
        if grep -q "^#\?$key" "$SSHD_CONFIG"; then
            sed -i "s|^#\?$key.*|$key $value|" "$SSHD_CONFIG"
        else
            echo "$key $value" >> "$SSHD_CONFIG"
        fi
    done

    if grep -q '^AllowUsers' "$SSHD_CONFIG"; then
        sed -i "s/^AllowUsers.*/AllowUsers $MY_USER/" "$SSHD_CONFIG"
    else
        echo "AllowUsers $MY_USER" >> "$SSHD_CONFIG"
    fi

    if ! grep -q '^Ciphers' "$SSHD_CONFIG"; then
      cat <<EOF >> "$SSHD_CONFIG"

# Algoritmos modernos
Ciphers chacha20-poly1305@openssh.com
KexAlgorithms curve25519-sha256
EOF
    fi

    # Validar sintaxis y reiniciar servicio
    if sshd -t; then
        systemctl restart sshd
        log "✅ Servicio SSH reiniciado con éxito en puerto $SSH_PORT"
    else
        error "Error de sintaxis en sshd_config. Verifica manualmente."
    fi

    echo -e "\n🎯 Configuración SSH completada:"
    echo "👤 Usuario permitido: $MY_USER"
    echo "🔐 Puerto seguro: $SSH_PORT"
    echo "🚫 Root y contraseña deshabilitados"
}

# === Función: Eliminar clave pública ===
eliminar_clave() {
    read -rp "👤 Ingresa el nombre del usuario del sistema: " MY_USER
    id "$MY_USER" &>/dev/null || error "El usuario $MY_USER no existe"

    USER_HOME=$(eval echo "~$MY_USER")
    AUTHORIZED_KEYS="$USER_HOME/.ssh/authorized_keys"
    [[ ! -f "$AUTHORIZED_KEYS" ]] && error "No hay archivo authorized_keys para $MY_USER"

    echo "=== Claves actuales ==="
    nl -ba "$AUTHORIZED_KEYS"

    read -rp "Ingresa el número de línea de la clave a eliminar: " LINE
    sed -i "${LINE}d" "$AUTHORIZED_KEYS"

    chown "$MY_USER:$MY_USER" "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
    log "Clave eliminada correctamente"
}

# === Menú principal ===
while true; do
    echo -e "\n===== CONFIGURACIÓN SSH SEGURA ====="
    echo "1) Configurar conexión SSH (agregar clave y endurecer)"
    echo "2) Eliminar clave pública autorizada"
    echo "3) Salir"
    read -rp "Selecciona una opción: " OPCION

    case "$OPCION" in
        1) configurar_ssh ;;
        2) eliminar_clave ;;
        3) echo "Saliendo..."; exit 0 ;;
        *) echo "[!] Opción inválida" ;;
    esac
done
