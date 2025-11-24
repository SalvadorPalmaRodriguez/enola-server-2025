#!/bin/bash
# WordPress Utilities Module
# Funciones compartidas para gestión de contenedores WordPress

# Función para recrear contenedores WordPress cuando cambia el puerto backend
# Parámetros:
#   $1: service_name - Nombre del servicio (ej: limon, pera)
#   $2: new_backend_port - Nuevo puerto backend
#   $3: old_backend_port - Puerto backend actual (opcional, para validación)
# Retorna:
#   0 si éxito, 1 si error
recreate_wordpress_container() {
    local service_name="$1"
    local new_backend_port="$2"
    local old_backend_port="${3:-}"

    # Validación de parámetros
    if [ -z "$service_name" ] || [ -z "$new_backend_port" ]; then
        echo "Error: Parámetros insuficientes para recreate_wordpress_container" >&2
        return 1
    fi

    # Verificar que es un servicio WordPress
    local env_file="/opt/enola/wordpress/${service_name}.env"
    if [ ! -f "$env_file" ]; then
        echo "Error: No es un servicio WordPress (falta ${env_file})" >&2
        return 1
    fi

    # Nombres de contenedores
    local WP_CONTAINER="enola-${service_name}-wp"
    local MYSQL_CONTAINER="enola-${service_name}-mysql"

    echo "Recreando contenedor WordPress para servicio: ${service_name}"
    echo "Nuevo puerto backend: ${new_backend_port}"

    # Obtener información del contenedor actual antes de eliminarlo
    local WP_NETWORK_NAME
    WP_NETWORK_NAME=$(sudo podman inspect "$WP_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' 2>/dev/null)
    
    if [ -z "$WP_NETWORK_NAME" ]; then
        echo "Advertencia: No se pudo obtener la red del contenedor, usando red por defecto" >&2
        WP_NETWORK_NAME="enola_net_${service_name}"
    fi

    # 1. Detener servicio systemd
    echo "Deteniendo servicio systemd..."
    sudo systemctl stop "container-${WP_CONTAINER}.service" 2>/dev/null

    # 2. Detener y eliminar contenedor WordPress
    echo "Eliminando contenedor antiguo..."
    sudo podman stop "$WP_CONTAINER" 2>/dev/null
    sudo podman rm -f "$WP_CONTAINER" 2>/dev/null

    # 3. Crear nuevo contenedor con el nuevo puerto
    echo "Creando contenedor con puerto ${new_backend_port}..."
    sudo podman run -d \
        --name "$WP_CONTAINER" \
        --network "$WP_NETWORK_NAME" \
        --env-file "$env_file" \
        -p "127.0.0.1:${new_backend_port}:80" \
        --restart=always \
        docker.io/library/wordpress:latest

    if [ $? -ne 0 ]; then
        echo "Error: Falló la creación del contenedor WordPress" >&2
        return 1
    fi

    # 4. Regenerar archivo de servicio systemd
    echo "Regenerando servicio systemd..."
    cd /etc/systemd/system/ || return 1
    sudo podman generate systemd --name "$WP_CONTAINER" --files --new

    if [ $? -ne 0 ]; then
        echo "Error: Falló la generación del archivo systemd" >&2
        return 1
    fi

    # 5. Recargar systemd y reiniciar servicio
    echo "Recargando systemd y habilitando servicio..."
    sudo systemctl daemon-reload
    sudo systemctl enable "container-${WP_CONTAINER}.service"
    sudo systemctl start "container-${WP_CONTAINER}.service"

    if [ $? -ne 0 ]; then
        echo "Error: Falló al iniciar el servicio systemd" >&2
        return 1
    fi

    echo "✓ Contenedor WordPress recreado exitosamente"
    echo "✓ Servicio escuchando en 127.0.0.1:${new_backend_port}"
    
    return 0
}

# Función para verificar si un servicio es WordPress
# Parámetros:
#   $1: service_name - Nombre del servicio
# Retorna:
#   0 si es WordPress, 1 si no lo es
is_wordpress_service() {
    local service_name="$1"
    [ -f "/opt/enola/wordpress/${service_name}.env" ]
}

# Función para obtener el puerto backend actual de un servicio WordPress
# Parámetros:
#   $1: service_name - Nombre del servicio
# Retorna:
#   Puerto backend en stdout, o cadena vacía si no se encuentra
get_wordpress_backend_port() {
    local service_name="$1"
    local container_name="enola-${service_name}-wp"
    
    # Obtener el puerto del mapeo del contenedor
    sudo podman port "$container_name" 80 2>/dev/null | grep -oP '127.0.0.1:\K\d+' || echo ""
}

# Función para mostrar resumen rápido después de recrear contenedor
# Parámetros:
#   $1: service_name - Nombre del servicio
#   $2: old_port - Puerto anterior (opcional)
#   $3: new_port - Puerto nuevo
show_recreation_summary() {
    local service_name="$1"
    local old_port="${2:-N/A}"
    local new_port="$3"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ CONTENEDOR RECREADO EXITOSAMENTE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📦 Servicio:       $service_name"
    echo "🔄 Puerto anterior: $old_port"
    echo "✨ Puerto nuevo:    $new_port"
    echo ""
    
    # Verificar que el contenedor esté corriendo
    local container_name="enola-${service_name}-wp"
    if sudo podman ps --filter "name=${container_name}" --format "{{.Status}}" 2>/dev/null | grep -q "Up"; then
        echo "✅ Contenedor:     Corriendo"
    else
        echo "⚠️  Contenedor:     Estado desconocido"
    fi
    
    # Verificar estado REAL del contenedor (no solo systemd)
    local real_status=$(podman inspect --format '{{.State.Status}}' "$container_name" 2>/dev/null || echo "missing")
    local systemd_active=false
    systemctl is-active --quiet "container-${container_name}.service" 2>/dev/null && systemd_active=true
    
    # Detectar desincronización
    if [ "$systemd_active" = true ] && [ "$real_status" != "running" ]; then
        echo "⚠️  Systemd:        Active (desincronizado: contenedor $real_status)"
    elif [ "$systemd_active" = true ]; then
        echo "✅ Systemd:        Active"
    else
        echo "⚠️  Systemd:        Inactive"
    fi
    
    # Verificar respuesta HTTP
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 http://127.0.0.1:${new_port} 2>/dev/null)
    if [ "$http_code" = "302" ] || [ "$http_code" = "200" ]; then
        echo "✅ HTTP:           Responde (código $http_code)"
    else
        echo "⚠️  HTTP:           Código $http_code"
    fi
    
    echo ""
    echo "💡 Acceso local:   http://127.0.0.1:${new_port}"
    echo ""
}
