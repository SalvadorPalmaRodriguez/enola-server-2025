#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

# ====================================================================
# SCRIPT PARA HABILITAR/DESHABILITAR SMOKE TEST TIMER
# ====================================================================
# Permite al usuario controlar cuándo ejecutar el smoke test periódico
# ====================================================================

log()   { echo -e "[SMOKE_TOGGLE] $(date '+%F %T') | $*"; }
die()   { echo -e "[SMOKE_TOGGLE] $(date '+%F %T') | ERROR | $*" >&2; exit 1; }

# Verificar que se ejecuta como root
if [ "$(id -u)" -ne 0 ]; then
    die "Este script debe ejecutarse como root (sudo)"
fi

TIMER_NAME="enola-smoke.timer"
SERVICE_NAME="enola-smoke.service"

# Verificar si las unidades de systemd existen
check_units() {
    if ! systemctl list-unit-files 2>/dev/null | grep -qw "${TIMER_NAME}"; then
        die "❌ No se encontró ${TIMER_NAME} en systemd"
    fi
    if ! systemctl list-unit-files 2>/dev/null | grep -qw "${SERVICE_NAME}"; then
        die "❌ No se encontró ${SERVICE_NAME} en systemd"
    fi
}

# Mostrar estado actual
show_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "    ESTADO DEL SMOKE TEST TIMER"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if systemctl is-enabled --quiet "$TIMER_NAME" 2>/dev/null; then
        echo "  🟢 Estado: HABILITADO"
        echo "  📍 Se ejecuta periódicamente en segundo plano"
        
        if systemctl is-active --quiet "$TIMER_NAME" 2>/dev/null; then
            echo "  ✅ Timer: ACTIVO"
            
            # Mostrar próxima ejecución
            local next_run=$(systemctl list-timers "$TIMER_NAME" --no-pager 2>/dev/null | grep "$TIMER_NAME" | awk '{print $1, $2, $3}')
            if [ -n "$next_run" ]; then
                echo "  ⏰ Próxima ejecución: $next_run"
            fi
        else
            echo "  ⚠️  Timer: INACTIVO (ejecuta: sudo systemctl start $TIMER_NAME)"
        fi
    else
        echo "  🔴 Estado: DESHABILITADO"
        echo "  📍 No se ejecuta automáticamente"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Habilitar smoke test
enable_smoke_test() {
    log "Habilitando smoke test timer..."
    
    systemctl enable "$TIMER_NAME" || die "No se pudo habilitar $TIMER_NAME"
    systemctl start "$TIMER_NAME" || die "No se pudo iniciar $TIMER_NAME"
    
    log "✅ Smoke test habilitado correctamente"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ El smoke test se ejecutará periódicamente"
    echo "  📋 Ver logs: journalctl -u $SERVICE_NAME"
    echo "  📋 Ver timer: systemctl list-timers $TIMER_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Deshabilitar smoke test
disable_smoke_test() {
    log "Deshabilitando smoke test timer..."
    
    systemctl stop "$TIMER_NAME" 2>/dev/null || true
    systemctl disable "$TIMER_NAME" || die "No se pudo deshabilitar $TIMER_NAME"
    
    log "✅ Smoke test deshabilitado correctamente"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ El smoke test ya no se ejecutará automáticamente"
    echo "  💡 Puedes ejecutarlo manualmente: sudo bash /opt/enola/scripts/common/smoke_test.sh"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Main
check_units
show_status

# Preguntar acción
echo "¿Qué deseas hacer?"
echo ""
echo "  1) Habilitar smoke test periódico"
echo "  2) Deshabilitar smoke test periódico"
echo "  3) Ver estado actual (ya mostrado arriba)"
echo "  0) Salir"
echo ""

read -rp "Elige una opción: " choice

case "$choice" in
    1)
        if systemctl is-enabled --quiet "$TIMER_NAME" 2>/dev/null; then
            echo ""
            echo "⚠️  El smoke test ya está habilitado"
            show_status
        else
            enable_smoke_test
        fi
        ;;
    2)
        if ! systemctl is-enabled --quiet "$TIMER_NAME" 2>/dev/null; then
            echo ""
            echo "⚠️  El smoke test ya está deshabilitado"
            show_status
        else
            disable_smoke_test
        fi
        ;;
    3)
        show_status
        ;;
    0)
        log "Saliendo..."
        exit 0
        ;;
    *)
        die "Opción inválida: $choice"
        ;;
esac

log "Operación completada"
