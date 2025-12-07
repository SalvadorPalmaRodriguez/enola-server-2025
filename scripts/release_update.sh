#!/usr/bin/env bash
# =============================================================================
# Enola Server - Script de actualización de release
# Copyright (c) 2025 Salvador Palma Rodríguez
# Licensed under: ENOLA SERVER - LICENCIA DE USO NO COMERCIAL v1.0
# =============================================================================
#
# Este script automatiza:
#   1. Detectar la versión actual y la nueva versión
#   2. Actualizar todas las referencias de versión en el proyecto
#   3. Reconstruir el paquete .deb con el nuevo nombre
#   4. Hacer commit y push
#   5. Actualizar el tag para que apunte al último commit
#   6. Subir el nuevo .deb a la release de GitHub
#
# Uso:
#   ./scripts/release_update.sh <nueva_version>    # Actualizar a nueva versión
#   ./scripts/release_update.sh 1.2.0
#
#   ./scripts/release_update.sh --sync             # Solo sincronizar tag y asset
#                                                   # (sin cambiar versión)
#
# =============================================================================

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directorio del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# =============================================================================
# Funciones de utilidad
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Función: Solo sincronizar tag y asset (sin cambiar versión)
# =============================================================================

sync_release() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🧅 Enola Server - Sincronizar Release"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Obtener versión actual
    local VERSION=$(grep "^Version:" enola/DEBIAN/control | awk '{print $2}')
    local TAG_NAME="v${VERSION}"
    local DEB_FILE="enola-server_${VERSION}_all.deb"
    
    log_info "Versión actual: $VERSION"
    log_info "Tag: $TAG_NAME"
    
    # Verificar si hay cambios sin commit
    if ! git diff --quiet HEAD 2>/dev/null; then
        log_info "[1/4] Hay cambios pendientes, haciendo commit..."
        git add -A
        git commit -m "chore: Sincronizar release v${VERSION}"
        git push origin main
        log_success "  Commit y push completados"
    else
        log_info "[1/4] No hay cambios pendientes"
    fi
    
    # Reconstruir .deb
    log_info "[2/4] Reconstruyendo paquete .deb..."
    rm -f enola-server_*.deb
    bash scripts/build.sh > /dev/null 2>&1
    
    # Renombrar si es necesario
    local BUILT_DEB=$(ls -t enola-server_*.deb 2>/dev/null | head -1)
    if [[ -n "$BUILT_DEB" ]] && [[ "$BUILT_DEB" != "$DEB_FILE" ]]; then
        mv "$BUILT_DEB" "$DEB_FILE"
    fi
    log_success "  Paquete: $DEB_FILE"
    
    # Actualizar tag
    log_info "[3/4] Actualizando tag $TAG_NAME..."
    git tag -d "$TAG_NAME" 2>/dev/null || true
    git tag "$TAG_NAME"
    git push origin --delete "$TAG_NAME" 2>/dev/null || true
    git push origin "$TAG_NAME"
    log_success "  Tag actualizado al commit: $(git rev-parse --short HEAD)"
    
    # Actualizar asset en release
    log_info "[4/4] Actualizando asset en GitHub..."
    if gh release view "$TAG_NAME" > /dev/null 2>&1; then
        gh release delete-asset "$TAG_NAME" "$DEB_FILE" --yes 2>/dev/null || true
        gh release upload "$TAG_NAME" "$DEB_FILE"
        log_success "  Asset actualizado: $DEB_FILE"
    else
        log_warning "  No existe release para $TAG_NAME, creándola..."
        gh release create "$TAG_NAME" "$DEB_FILE" --title "v${VERSION}" --notes "Release v${VERSION}"
        log_success "  Release creada"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ Sincronización completada"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  🏷️  Tag:     $TAG_NAME → $(git rev-parse --short HEAD)"
    echo "  📦 Asset:   $DEB_FILE (actualizado)"
    echo "  🔗 Release: https://github.com/SalvadorPalmaRodriguez/enola-server-2025/releases/tag/$TAG_NAME"
    echo ""
    exit 0
}

# =============================================================================
# Validaciones
# =============================================================================

# Verificar si es modo sync
if [[ "${1:-}" == "--sync" ]] || [[ "${1:-}" == "-s" ]]; then
    sync_release
fi

# Verificar argumentos
if [[ $# -lt 1 ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🧅 Enola Server - Actualización de Release"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Uso:"
    echo "  $0 <nueva_version>    Actualizar a nueva versión"
    echo "  $0 --sync             Solo sincronizar tag y asset"
    echo ""
    echo "Ejemplos:"
    echo "  $0 1.2.0              Actualiza todo a v1.2.0"
    echo "  $0 --sync             Sincroniza tag y .deb con main actual"
    echo ""
    echo "El script:"
    echo "  1. Actualiza todas las referencias de versión"
    echo "  2. Reconstruye el paquete .deb"
    echo "  3. Hace commit y push a main"
    echo "  4. Actualiza/crea el tag de la release"
    echo "  5. Sube el .deb a GitHub Releases"
    echo ""
    exit 1
fi

NEW_VERSION="$1"

# Validar formato de versión (X.Y.Z)
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Formato de versión inválido: $NEW_VERSION"
    log_error "Usa formato semántico: X.Y.Z (ej: 1.2.0)"
    exit 1
fi

# Verificar que estamos en la rama main
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    log_error "Debes estar en la rama 'main'. Actual: $CURRENT_BRANCH"
    log_info "Ejecuta: git checkout main"
    exit 1
fi

# Verificar que no hay cambios sin commit
if ! git diff --quiet HEAD 2>/dev/null; then
    log_error "Hay cambios sin commit. Haz commit o stash primero."
    git status --short
    exit 1
fi

# Verificar que gh está instalado
if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) no está instalado."
    log_info "Instala con: sudo apt install gh"
    exit 1
fi

# Verificar autenticación de gh
if ! gh auth status &> /dev/null; then
    log_error "No estás autenticado en GitHub CLI."
    log_info "Ejecuta: gh auth login"
    exit 1
fi

# =============================================================================
# Detectar versión actual
# =============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🧅 Enola Server - Actualización de Release"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Obtener versión actual del control file
CURRENT_VERSION=$(grep "^Version:" enola/DEBIAN/control | awk '{print $2}')
log_info "Versión actual: $CURRENT_VERSION"
log_info "Nueva versión:  $NEW_VERSION"

if [[ "$CURRENT_VERSION" == "$NEW_VERSION" ]]; then
    log_warning "La versión ya es $NEW_VERSION"
    read -p "¿Continuar de todos modos? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 0
    fi
fi

echo ""
read -p "¿Proceder con la actualización a v$NEW_VERSION? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    log_info "Operación cancelada."
    exit 0
fi

# =============================================================================
# Paso 1: Actualizar referencias de versión
# =============================================================================

echo ""
log_info "[1/6] Actualizando referencias de versión..."

# Archivos a actualizar
FILES_TO_UPDATE=(
    "README.md"
    "enola/README.md"
    "enola/DEBIAN/control"
    "PRODUCT_BRIEF.md"
    "scripts/README.md"
)

# Patrones a reemplazar
OLD_VERSION_ESCAPED=$(echo "$CURRENT_VERSION" | sed 's/\./\\./g')
NEW_VERSION_ESCAPED=$(echo "$NEW_VERSION" | sed 's/\./\\./g')

for file in "${FILES_TO_UPDATE[@]}"; do
    if [[ -f "$file" ]]; then
        # Reemplazar versión en formato vX.Y.Z
        sed -i "s/v${OLD_VERSION_ESCAPED}/v${NEW_VERSION}/g" "$file"
        # Reemplazar versión en badges
        sed -i "s/version-${OLD_VERSION_ESCAPED}-/version-${NEW_VERSION}-/g" "$file"
        # Reemplazar Version: X.Y.Z en control
        sed -i "s/^Version: ${OLD_VERSION_ESCAPED}$/Version: ${NEW_VERSION}/" "$file"
        # Reemplazar nombre de .deb
        sed -i "s/enola-server_${OLD_VERSION_ESCAPED}_all\.deb/enola-server_${NEW_VERSION}_all.deb/g" "$file"
        log_success "  Actualizado: $file"
    fi
done

# Actualizar install_and_deps.sh si existe
if [[ -f "scripts/install_and_deps.sh" ]]; then
    sed -i "s/enola-server_${OLD_VERSION_ESCAPED}_all\.deb/enola-server_${NEW_VERSION}_all.deb/g" "scripts/install_and_deps.sh"
    log_success "  Actualizado: scripts/install_and_deps.sh"
fi

# =============================================================================
# Paso 2: Verificar que no quedan referencias antiguas
# =============================================================================

echo ""
log_info "[2/6] Verificando referencias..."

REMAINING=$(grep -rn "v${CURRENT_VERSION}\|enola-server_${CURRENT_VERSION}" \
    --include="*.md" --include="control" --include="*.sh" 2>/dev/null | \
    grep -v "enola-server_${NEW_VERSION}" | \
    grep -v "\.git" || true)

if [[ -n "$REMAINING" ]]; then
    log_warning "Quedan algunas referencias a la versión anterior:"
    echo "$REMAINING"
    read -p "¿Continuar de todos modos? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
else
    log_success "  No quedan referencias a versiones antiguas"
fi

# =============================================================================
# Paso 3: Reconstruir paquete .deb
# =============================================================================

echo ""
log_info "[3/6] Reconstruyendo paquete .deb..."

# Eliminar .deb anterior si existe
rm -f enola-server_*.deb

# Construir
bash scripts/build.sh > /dev/null 2>&1

# El build genera con el nombre del control, renombramos si es necesario
if [[ -f "enola-server_${CURRENT_VERSION}_all.deb" ]] && [[ "$CURRENT_VERSION" != "$NEW_VERSION" ]]; then
    mv "enola-server_${CURRENT_VERSION}_all.deb" "enola-server_${NEW_VERSION}_all.deb"
fi

# Verificar que se creó el nuevo .deb
# El script build.sh puede usar diferentes nombres, buscar el más reciente
DEB_FILE=$(ls -t enola-server_*.deb 2>/dev/null | head -1)
if [[ -z "$DEB_FILE" ]]; then
    log_error "No se pudo crear el paquete .deb"
    exit 1
fi

# Si el nombre no coincide con la nueva versión, renombrar
EXPECTED_DEB="enola-server_${NEW_VERSION}_all.deb"
if [[ "$DEB_FILE" != "$EXPECTED_DEB" ]]; then
    mv "$DEB_FILE" "$EXPECTED_DEB"
    DEB_FILE="$EXPECTED_DEB"
fi

log_success "  Paquete creado: $DEB_FILE"

# =============================================================================
# Paso 4: Commit y push
# =============================================================================

echo ""
log_info "[4/6] Haciendo commit y push..."

git add -A

# Verificar si hay cambios para commit
if git diff --cached --quiet; then
    log_warning "  No hay cambios para commit"
else
    git commit -m "release: Actualizar a v${NEW_VERSION}

- Actualizar todas las referencias de versión
- Reconstruir paquete .deb
- Sincronizar documentación"

    git push origin main
    log_success "  Commit y push completados"
fi

# =============================================================================
# Paso 5: Actualizar tag
# =============================================================================

echo ""
log_info "[5/6] Actualizando tag v${NEW_VERSION}..."

TAG_NAME="v${NEW_VERSION}"

# Verificar si el tag ya existe localmente
if git tag -l | grep -q "^${TAG_NAME}$"; then
    log_info "  Eliminando tag local existente..."
    git tag -d "$TAG_NAME" > /dev/null 2>&1
fi

# Verificar si el tag existe en remoto
if git ls-remote --tags origin | grep -q "refs/tags/${TAG_NAME}$"; then
    log_info "  Eliminando tag remoto existente..."
    git push origin --delete "$TAG_NAME" > /dev/null 2>&1
fi

# Crear nuevo tag
git tag "$TAG_NAME"
git push origin "$TAG_NAME"
log_success "  Tag $TAG_NAME creado y subido"

# =============================================================================
# Paso 6: Actualizar release en GitHub
# =============================================================================

echo ""
log_info "[6/6] Actualizando release en GitHub..."

# Verificar si la release existe
if gh release view "$TAG_NAME" > /dev/null 2>&1; then
    log_info "  Release existe, actualizando asset..."
    
    # Eliminar asset anterior si existe
    OLD_ASSET="enola-server_${CURRENT_VERSION}_all.deb"
    gh release delete-asset "$TAG_NAME" "$OLD_ASSET" --yes 2>/dev/null || true
    gh release delete-asset "$TAG_NAME" "$DEB_FILE" --yes 2>/dev/null || true
    
    # Subir nuevo asset
    gh release upload "$TAG_NAME" "$DEB_FILE" --clobber
    log_success "  Asset actualizado: $DEB_FILE"
else
    log_info "  Creando nueva release..."
    
    gh release create "$TAG_NAME" "$DEB_FILE" \
        --title "v${NEW_VERSION}" \
        --notes "## Enola Server v${NEW_VERSION}

### Instalación

\`\`\`bash
wget https://github.com/SalvadorPalmaRodriguez/enola-server-2025/releases/download/v${NEW_VERSION}/enola-server_${NEW_VERSION}_all.deb
sudo apt install -y ./enola-server_${NEW_VERSION}_all.deb
\`\`\`

### Ejecutar

\`\`\`bash
sudo enola-server
\`\`\`
"
    log_success "  Release creada: $TAG_NAME"
fi

# =============================================================================
# Resumen final
# =============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Actualización completada"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Versión anterior: $CURRENT_VERSION"
echo "  Nueva versión:    $NEW_VERSION"
echo ""
echo "  📦 Paquete: $DEB_FILE"
echo "  🏷️  Tag:     $TAG_NAME"
echo "  🔗 Release: https://github.com/SalvadorPalmaRodriguez/enola-server-2025/releases/tag/$TAG_NAME"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
