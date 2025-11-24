#!/bin/bash
set -euo pipefail

# ====================================================================
# SCRIPT PARA CONSTRUIR EL PAQUETE DEBIAN "ENOLA-SERVER"
# Funciona sin necesidad de sudo/root.
# ====================================================================
PROJECT_ROOT="$(realpath "$(dirname "$0")/..")"

# 2️⃣ Directorio donde está el paquete en formato Debian
PACKAGE_DIR="$PROJECT_ROOT/enola"

# 3️⃣ Versión y arquitectura
VERSION="1.0.0"
ARCH="all"

# 4️⃣ Nombre del archivo .deb resultante (se guarda en raíz del proyecto)
DEB_FILE="$PROJECT_ROOT/enola-server_${VERSION}_${ARCH}.deb"

log() { echo -e "[\e[32mOK\e[0m] $1"; }
warn() { echo -e "[\e[33mWARN\e[0m] $1"; }
error_exit() { echo -e "[\e[31mERROR\e[0m] $1" >&2; exit 1; }

# --- Verificación de herramientas ---
if ! command -v dpkg-deb &> /dev/null; then
    error_exit "dpkg-deb no encontrado. Instala 'dpkg-dev'."
fi

log "Iniciando la construcción del paquete Debian..."

# --- Paso 1: Asegurar permisos de todos los archivos ---
log "Asegurando permisos de todos los archivos para build..."

# Archivos normales (excluyendo DEBIAN)
find "$PACKAGE_DIR" -path "$PACKAGE_DIR/DEBIAN" -prune -o -type f -exec chmod 644 {} \;
# Directorios normales (excluyendo DEBIAN)
find "$PACKAGE_DIR" -path "$PACKAGE_DIR/DEBIAN" -prune -o -type d -exec chmod 755 {} \;

# Scripts de mantenimiento en DEBIAN
if [ -d "$PACKAGE_DIR/DEBIAN" ]; then
    log "Ajustando permisos de scripts de mantenimiento..."
    chmod 755 "$PACKAGE_DIR/DEBIAN/"*
fi

# Scripts ejecutables dentro del paquete
chmod -R 755 "$PACKAGE_DIR/opt/enola/scripts"
chmod 755 "$PACKAGE_DIR/usr/bin/enola-server"

# --- 🔹 Paso 1.5: Generar archivo VERSION dentro del paquete ---
VERSION_FILE="$PACKAGE_DIR/opt/enola/VERSION"
echo "${VERSION} (Build $(date '+%F'))" > "$VERSION_FILE"
log "Archivo de versión generado: $VERSION_FILE"

# --- Paso 2: Construir el paquete ---
log "Permisos listos. Construyendo el paquete .deb..."
dpkg-deb --build --root-owner-group "$PACKAGE_DIR" "$DEB_FILE" \
    || error_exit "Fallo al construir el paquete .deb"

log "Paquete creado con éxito: $DEB_FILE"
log "🎉 Listo para instalar: sudo dpkg -i $DEB_FILE"
