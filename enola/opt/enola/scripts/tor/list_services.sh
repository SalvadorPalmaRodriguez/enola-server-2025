#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

# ==========================
# Listado de servicios Onion (versión amigable con paginación)
# ==========================

SERVICES_DIR="/etc/tor/enola.d"
DISABLED_DIR="$SERVICES_DIR/disabled"

# 📝 Funciones de log
log() { echo -e "[ONION-LIST] $(date '+%F %T') | $*"; }

# � Seleccionar lector seguro para archivos .conf (maneja no-root y sudo -n)
PERM_NOTICE_PRINTED=false
determine_reader() {
    local conf="$1"
    if [[ -r "$conf" ]]; then
        echo "cat"
        return 0
    fi
    if command -v sudo >/dev/null 2>&1; then
        if sudo -n test -r "$conf" 2>/dev/null; then
            echo "sudo -n cat"
            return 0
        fi
    fi
    # No se puede leer: notificar una sola vez de forma amable
    if [[ "$PERM_NOTICE_PRINTED" == false ]]; then
        echo "[ONION-LIST] ℹ️ Ejecuta con sudo para ver detalles de Tor (.conf protegidos)." >&2
        PERM_NOTICE_PRINTED=true
    fi
    echo ""
    return 0
}

# �🔍 Comprobar puerto y proceso
check_port() {
    local port="$1"
    local line
    # Tomar solo la primera coincidencia para evitar duplicados visuales
    line=$(ss -tulnp 2>/dev/null | awk '{print $0}' | grep -m1 ":$port\b" || true)

    if [[ -n "$line" ]]; then
        # Extraer el nombre de proceso si está disponible entre comillas
        local proc
        proc=$(echo "$line" | awk -F '"' '{print $2}' | head -n1)
        [[ -z "$proc" ]] && proc="desconocido"
        echo "✅ Abierto (proceso: $proc)"
    else
        echo "❌ Cerrado"
    fi
}

# 🎨 Mostrar bloque de un servicio
print_service_info() {
    local name="$1"
    local conf="$2"
    local status="$3"

    # Categoría visual
    case "$name" in
        ssh)  ICON="🔐";;
        web)  ICON="🌐";;
        *)    ICON="📦";;
    esac

    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$ICON Servicio: $name"
    echo "📂 Configuración: $conf"
    echo "📌 Estado: $status"

    # Dirección Onion
    local hs_dir
    local READER
    READER=$(determine_reader "$conf")

    if [[ -n "$READER" ]]; then
        hs_dir=$($READER "$conf" | awk 'tolower($1)=="hiddenservicedir" {print $2; exit}' || true)
        if [[ -n "$hs_dir" && -f "$hs_dir/hostname" ]]; then
            echo "🌍 Dirección Onion: $(cat "$hs_dir/hostname")"
        else
            echo "🌍 Dirección Onion: ⚠️ No disponible aún"
        fi
    else
        echo "🌍 Dirección Onion: 🔒 Sin permisos para leer configuración (usa sudo)"
    fi

    # Puertos asociados
    if [[ -n "$READER" ]]; then
        while read -r in_port out_addr; do
            [[ -n "$in_port" && -n "$out_addr" ]] || continue
            local out_port
            # soporta host:port y [ipv6]:port
            out_port=$(echo "$out_addr" | awk -F: '{print $NF}')
            local state
            state=$(check_port "$out_port")
            echo "🔄 Redirección: Onion $in_port → $out_addr"
            if [[ "$state" == *"Cerrado"* ]]; then
                echo "⚠️ Backend: $state → El servicio local no está activo, revisa si se inició."
            else
                echo "🟢 Backend: $state"
            fi
        done < <($READER "$conf" | awk 'tolower($1)=="hiddenserviceport" {print $2, $3}')
    else
        echo "🔄 Redirecciones: 🔒 Sin permisos para leer (ejecuta con sudo para detalles)."
    fi
}

# ==========================
# 🔧 Programa principal
# ==========================

log "📋 Revisando servicios Onion en el sistema..."

TMP_OUTPUT=$(mktemp)
trap 'rm -f "$TMP_OUTPUT"' EXIT

found=false
# Cabecera visible en el listado
echo "------ Lista de servicios ------" > "$TMP_OUTPUT"
echo >> "$TMP_OUTPUT"

# Servicios activos
if [[ -d "$SERVICES_DIR" ]]; then
    for conf in "$SERVICES_DIR"/*.conf; do
        [[ -f "$conf" ]] || continue
        name=$(basename "$conf" .conf)
        print_service_info "$name" "$conf" "ACTIVO" >> "$TMP_OUTPUT"
        found=true
    done
fi 

# Servicios deshabilitados (dos formatos soportados)
# 1) En carpeta "disabled" con extensión .conf
if [[ -d "$DISABLED_DIR" ]]; then
    for conf in "$DISABLED_DIR"/*.conf; do
        [[ -f "$conf" ]] || continue
        name=$(basename "$conf" .conf)
        print_service_info "$name" "$conf" "🚫 DESHABILITADO" >> "$TMP_OUTPUT"
        found=true
    done
fi

# 2) En el mismo directorio con sufijo .conf.disabled
for conf in "$SERVICES_DIR"/*.conf.disabled; do
    [[ -f "$conf" ]] || continue
    name=$(basename "$conf" .conf.disabled)
    print_service_info "$name" "$conf" "🚫 DESHABILITADO" >> "$TMP_OUTPUT"
    found=true
done 

if [[ "$found" = false ]]; then
    echo -e "\n⚠️ No se encontraron servicios Onion configurados en $SERVICES_DIR" >> "$TMP_OUTPUT"
fi

{
    echo
    echo "💡 Consejo: Si algún servicio aparece como ❌ Cerrado, asegúrate de que el proceso local (nginx, sshd, etc.) esté corriendo."
    echo
    echo "[ONION-LIST] ✅ Fin del listado."
} >> "$TMP_OUTPUT"

# ==========================
# 📜 Mostrar resultado
# ==========================

# Simplemente mostrar el contenido sin paginador para evitar bloqueos
cat "$TMP_OUTPUT"

# Limpiar archivo temporal
rm -f "$TMP_OUTPUT"
trap - EXIT
exit 0



