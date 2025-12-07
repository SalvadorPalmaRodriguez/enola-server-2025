#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# Enola Server - Script de instalación con dependencias
# Copyright (c) 2025 Salvador Palma Rodríguez
# Licensed under: ENOLA SERVER - LICENCIA DE USO NO COMERCIAL v1.0
# =============================================================================
# Uso: sudo ./install_and_deps.sh ./enola-server_1.0.0_all.deb
#
# Este script:
#   1. Actualiza los índices de paquetes
#   2. Instala las dependencias necesarias
#   3. Copia el .deb a /tmp para evitar warnings de permisos
#   4. Instala el paquete con apt
# =============================================================================

PKG_PATH=${1:-}
if [[ -z "$PKG_PATH" ]]; then
  echo "Uso: sudo $0 ./enola-server_...deb"
  echo ""
  echo "Ejemplo:"
  echo "  sudo ./install_and_deps.sh ./enola-server_1.0.0_all.deb"
  exit 2
fi

if [[ ! -f "$PKG_PATH" ]]; then
  echo "❌ Error: No se encontró el archivo: $PKG_PATH"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "❌ Error: Ejecuta como root: sudo $0 $PKG_PATH"
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🧅 Enola Server - Instalador"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "[1/4] Actualizando índices de paquetes..."
apt update -y

echo ""
echo "[2/4] Instalando dependencias del sistema..."
apt install -y tor nginx podman curl dialog figlet certbot python3-certbot-nginx apache2-utils openssh-server || true

echo ""
echo "[3/4] Preparando paquete para instalación..."
# Copiar a /tmp para evitar warning de permisos de _apt
TMP_PKG="/tmp/$(basename "$PKG_PATH")"
cp "$PKG_PATH" "$TMP_PKG"
chmod 644 "$TMP_PKG"

echo ""
echo "[4/4] Instalando Enola Server..."
apt install -y "$TMP_PKG"

# Limpiar
rm -f "$TMP_PKG"

# Configurar pendientes si los hubiera
dpkg --configure -a 2>/dev/null || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Instalación completada"
echo ""
echo "  Ejecuta el menú principal:"
echo "    sudo enola-server"
echo ""
echo "  O ejecuta el smoke test:"
echo "    sudo enola-server --smoke"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit 0
