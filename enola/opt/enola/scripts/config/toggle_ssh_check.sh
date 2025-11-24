#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

# ====================================================================
# HABILITAR/DESHABILITAR CHECK DE SSH EN SMOKE TEST
# ====================================================================

SSH_CHECK_FLAG="/var/lib/enola-server/ssh_check_enabled"
STATE_DIR="/var/lib/enola-server"

# Funciones de logging
log()   { echo -e "[SSH_CHECK] $(date '+%F %T') | $*"; }
warn()  { echo -e "[SSH_CHECK] $(date '+%F %T') | WARN | $*"; }
die()   { echo -e "[SSH_CHECK] $(date '+%F %T') | ERROR | $*"; exit 1; }

# Crear directorio de estado si no existe
mkdir -p "$STATE_DIR"

# Función para mostrar estado actual
show_status() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 ESTADO DEL CHECK DE SSH EN SMOKE TEST"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ -f "$SSH_CHECK_FLAG" ]]; then
        echo "Estado: ✅ HABILITADO"
        echo ""
        echo "El smoke test verificará que:"
        echo "  • El proceso sshd esté corriendo"
        echo "  • SSH escuche en los puertos configurados"
        echo ""
        # Verificar estado actual de SSH
        if pgrep -x sshd >/dev/null 2>&1; then
            echo "Estado actual: ✅ sshd está corriendo"
        else
            echo "Estado actual: ⚠️  sshd NO está corriendo"
            echo "  → Configura SSH desde el menú: SSH → Configurar SSH"
        fi
    else
        echo "Estado: ⚠️  DESHABILITADO"
        echo ""
        echo "El smoke test NO verificará SSH"
        echo "  → Ideal si aún no has configurado SSH"
        echo "  → Habilítalo después de configurar SSH"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Función para habilitar check de SSH
enable_ssh_check() {
    if [[ -f "$SSH_CHECK_FLAG" ]]; then
        warn "El check de SSH ya está habilitado"
        return 0
    fi
    
    touch "$SSH_CHECK_FLAG"
    log "✅ Check de SSH habilitado en smoke test"
    
    # Verificar si SSH está configurado
    if ! pgrep -x sshd >/dev/null 2>&1; then
        warn "⚠️  ATENCIÓN: sshd no está corriendo"
        echo ""
        echo "Has habilitado el check de SSH pero el servicio no está activo."
        echo "Para configurar SSH:"
        echo "  1. Ejecuta: sudo enola-server"
        echo "  2. Ve a: SSH → Configurar SSH"
        echo "  3. Configura usuario, puerto y claves"
        echo ""
    fi
}

# Función para deshabilitar check de SSH
disable_ssh_check() {
    if [[ ! -f "$SSH_CHECK_FLAG" ]]; then
        warn "El check de SSH ya está deshabilitado"
        return 0
    fi
    
    rm -f "$SSH_CHECK_FLAG"
    log "✅ Check de SSH deshabilitado en smoke test"
    log "El smoke test ya no verificará el estado de SSH"
}

# Menú interactivo
while true; do
    echo ""
    show_status
    echo ""
    echo "¿Qué deseas hacer?"
    echo "1) Habilitar check de SSH"
    echo "2) Deshabilitar check de SSH"
    echo "3) Mostrar estado actual"
    echo "4) Salir"
    echo ""
    read -rp "Selecciona una opción [1-4]: " choice
    
    case "$choice" in
        1)
            enable_ssh_check
            ;;
        2)
            disable_ssh_check
            ;;
        3)
            show_status
            ;;
        4)
            echo "Saliendo..."
            exit 0
            ;;
        *)
            warn "Opción inválida"
            ;;
    esac
done
