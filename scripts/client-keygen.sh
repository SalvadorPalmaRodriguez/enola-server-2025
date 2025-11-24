#!/bin/bash
set -euo pipefail

check_env() {
  echo -e "\n[\e[33mCHECK\e[0m] Verificando entorno del cliente..."

  # Paquetes necesarios
  local pkgs=(tor torsocks netcat-openbsd openssh-client socat)
  local missing=()
  for pkg in "${pkgs[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
      missing+=("$pkg")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    echo -e "[\e[31mERROR\e[0m] Faltan paquetes: ${missing[*]}"
    echo "  Instalando..."
    sudo apt-get update && sudo apt-get install -y "${missing[@]}"
  else
    echo -e "[\e[32mOK\e[0m] Todos los paquetes necesarios están instalados."
  fi

  # Verificar tor corriendo en 127.0.0.1:9050
  if ss -tnlp | grep -q "127.0.0.1:9050"; then
    echo -e "[\e[32mOK\e[0m] Tor está corriendo y escuchando en 127.0.0.1:9050 (proxy SOCKS)."
  else
    echo -e "[\e[31mERROR\e[0m] Tor no está corriendo o no escucha en 127.0.0.1:9050."
    echo "  Por favor, arranca Tor antes de continuar."
    exit 1
  fi

  # Mostrar versiones relevantes
  echo -e "\n[\e[33mINFO\e[0m] Versiones instaladas:"
  tor --version
  ssh -V
  nc -h | head -n 1
  torsocks --version || echo "torsocks no encontrado."

  # Verificar permisos de ~/.ssh
  echo -e "\n[\e[33mINFO\e[0m] Permisos del directorio ~/.ssh y archivos:"
  ls -ld "$HOME/.ssh"
  ls -l "$HOME/.ssh" || echo "No hay archivos en ~/.ssh"

  echo -e "[\e[33mCHECK\e[0m] Verificación de entorno finalizada.\n"
}

check_env

log() {
  echo -e "[\e[32mINFO\e[0m] $1"
}
error_exit() {
  echo -e "[\e[31mERROR\e[0m] $1" >&2
  exit 1
}

# ================================
# Función para generar clave con passphrase
# ================================
generate_key_with_passphrase() {
  read -rp "¿Quieres proteger la clave SSH con passphrase? (y/n): " USE_PASSPHRASE
  if [[ "$USE_PASSPHRASE" == "y" ]]; then
    read -rsp "Introduce la passphrase: " PASSPHRASE_1
    echo
    read -rsp "Confirma la passphrase: " PASSPHRASE_2
    echo
    if [[ "$PASSPHRASE_1" != "$PASSPHRASE_2" ]]; then
      error_exit "Las passphrases no coinciden. Abortando."
    fi
    ssh-keygen -t ed25519 -f "$SSH_KEY" -C "$TARGET_USER@cliente" -N "$PASSPHRASE_1"
  else
    ssh-keygen -t ed25519 -f "$SSH_KEY" -C "$TARGET_USER@cliente" -N ""
  fi
}

# ================================
# 1. Solicitar datos al usuario
# ================================

read -rp "🌐 Ingresa la dirección .onion del servidor: " ONION_HOST
[[ -z "$ONION_HOST" ]] && error_exit "La dirección .onion no puede estar vacía"

read -rp "🔢 Ingresa el puerto SSH configurado en el servidor (ej. 2222): " ONION_PORT
[[ -z "$ONION_PORT" ]] && error_exit "El puerto no puede estar vacío"

read -rp "👤 Ingresa el nombre de usuario en el servidor: " TARGET_USER
[[ -z "$TARGET_USER" ]] && error_exit "El nombre de usuario no puede estar vacío"

# ================================
# 2. Verificar programas necesarios
# ================================

log "🔍 Verificando herramientas necesarias..."

for pkg in torsocks openssh-client netcat-openbsd; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    log "📦 Instalando $pkg..."
    sudo apt-get update && sudo apt-get install -y "$pkg"
  else
    log "✅ $pkg ya está instalado"
  fi
done

# ================================
# 3. Verificar que Tor está corriendo (proxy SOCKS en 127.0.0.1:9050)
# ================================

if ! ss -tnlp | grep -q "127.0.0.1:9050"; then
  error_exit "Tor no está corriendo o no está escuchando en 127.0.0.1:9050. Arráncalo antes de continuar."
fi

log "✅ Tor está corriendo en 127.0.0.1:9050"

# ================================
# 4. Preparar directorio .ssh
# ================================

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# ================================
# 5. Generar clave SSH nueva solo si no existe
# ================================

SSH_KEY="$HOME/.ssh/id_${TARGET_USER}_${ONION_PORT}_${ONION_HOST//./_}"
if [[ -f "$SSH_KEY" ]]; then
  read -rp "La clave $SSH_KEY ya existe. ¿Deseas sobrescribirla? (y/n): " OVERWRITE
  if [[ "$OVERWRITE" != "y" ]]; then
    log "Usando clave existente: $SSH_KEY"
  else
    generate_key_with_passphrase
    log "🔐 Clave SSH sobrescrita en $SSH_KEY"
  fi
else
  generate_key_with_passphrase
  log "🔐 Clave SSH generada en $SSH_KEY"
  #guarda passphrase en sesion
  #eval "$(ssh-agent -s)"
  #ssh-add "$SSH_KEY"

fi

chmod 600 "$SSH_KEY" "$SSH_KEY.pub"

# ================================
# 6. Mostrar clave pública para el servidor
# ================================

echo ""
log "📋 Clave pública generada. Debes colocarla en el servidor:"
echo "----------------------------------------------------"
cat "$SSH_KEY.pub"
echo "----------------------------------------------------"
echo "📌 Ruta destino en el servidor:"
echo "/home/$TARGET_USER/.ssh/authorized_keys"
echo ""
echo "✅ Cuando esté lista, conecta con:"
echo "    torsocks ssh -p $ONION_PORT $TARGET_USER@$ONION_HOST"
echo ""

# ================================
# 7. Mostrar archivos en .ssh para verificar
# ================================

log "Archivos en .ssh:"
ls -l "$HOME/.ssh"

