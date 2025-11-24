#!/bin/bash
set -euo pipefail

echo "=== Limpiando el entorno del proyecto 'enola-server' ==="

# -------------------------------
# 1️⃣ Detener y eliminar TODOS los contenedores de WordPress
# -------------------------------
echo "Deteniendo y eliminando todos los contenedores WordPress..."
for container in $(sudo podman ps -a --format "{{.Names}}" | grep -E "^enola-.*-(wp|mysql|wordpress)$" || true); do
    echo "  - Eliminando contenedor: $container"
    sudo podman rm -f "$container" 2>/dev/null || true
done

# -------------------------------
# 2️⃣ Eliminar servicios systemd de contenedores
# -------------------------------
echo "Eliminando servicios systemd de contenedores..."
for service in /etc/systemd/system/container-enola-*.service; do
    if [ -f "$service" ]; then
        svc_name=$(basename "$service")
        echo "  - Deshabilitando y eliminando: $svc_name"
        sudo systemctl stop "$svc_name" 2>/dev/null || true
        sudo systemctl disable "$svc_name" 2>/dev/null || true
        sudo rm -f "$service"
    fi
done
sudo systemctl daemon-reload

# -------------------------------
# 3️⃣ Eliminar red interna de Podman
# -------------------------------
echo "Eliminando redes de Podman..."
for network in $(sudo podman network ls --format "{{.Name}}" | grep -E "^enola_" || true); do
    echo "  - Eliminando red: $network"
    sudo podman network rm "$network" 2>/dev/null || true
done

# -------------------------------
# 4️⃣ Eliminar imágenes de WordPress y MySQL
# -------------------------------
echo "Eliminando imágenes Docker..."
IMAGES=("docker.io/library/wordpress:latest" "docker.io/library/mysql:8.0")
for img in "${IMAGES[@]}"; do
    if sudo podman images --format "{{.Repository}}:{{.Tag}}" | grep -q "^$img$" 2>/dev/null; then
        echo "  - Eliminando imagen: $img"
        sudo podman rmi -f "$img" 2>/dev/null || true
    fi
done

# -------------------------------
# 5️⃣ Eliminar directorios de servicios ocultos de Tor
# -------------------------------
echo "Eliminando todos los servicios ocultos de Tor..."
sudo rm -rf /var/lib/tor/hidden_service_* 2>/dev/null || true
sudo rm -rf /var/lib/tor/hidden_service_*.disabled 2>/dev/null || true

# -------------------------------
# 6️⃣ Eliminar configuraciones de Tor
# -------------------------------
echo "Eliminando configuraciones de Tor..."
sudo rm -rf /etc/tor/enola.d/*.conf 2>/dev/null || true
sudo rm -rf /etc/tor/enola.d/*.conf.disabled 2>/dev/null || true

# Eliminar línea de inclusión modular en torrc si existe
if grep -q '%include /etc/tor/enola.d/\*\.conf' /etc/tor/torrc 2>/dev/null; then
    echo "Eliminando línea de inclusión modular en torrc..."
    sudo sed -i '/%include \/etc\/tor\/enola.d\/\*\.conf/d' /etc/tor/torrc
fi

# -------------------------------
# 7️⃣ Reiniciar Tor
# -------------------------------
echo "Reiniciando Tor para limpiar configuraciones..."
sudo systemctl restart tor 2>/dev/null || true
sudo systemctl restart enola-tor 2>/dev/null || true

# -------------------------------
# 8️⃣ Eliminar TODAS las configuraciones de NGINX
# -------------------------------
echo "Eliminando configuraciones de NGINX..."
# Sites-enabled (symlinks)
for conf in /etc/nginx/sites-enabled/enola-* /etc/nginx/sites-enabled/*.conf; do
    if [ -f "$conf" ] || [ -L "$conf" ]; then
        echo "  - Eliminando enabled: $(basename $conf)"
        sudo rm -f "$conf" 2>/dev/null || true
    fi
done

# Sites-available (archivos reales)
for conf in /etc/nginx/sites-available/enola-* /etc/nginx/sites-available/*.conf; do
    # Preservar default
    if [ -f "$conf" ] && [ "$(basename $conf)" != "default" ]; then
        echo "  - Eliminando available: $(basename $conf)"
        sudo rm -f "$conf" 2>/dev/null || true
    fi
done

# -------------------------------
# 9️⃣ Eliminar certificados SSL
# -------------------------------
echo "Eliminando certificados SSL..."
sudo rm -rf /etc/enola-server/ssl/* 2>/dev/null || true

# -------------------------------
# 🔟 Eliminar configuraciones y scripts de Enola
# -------------------------------
echo "Eliminando configuraciones y scripts de Enola..."
sudo rm -rf /opt/enola/wordpress/*.env 2>/dev/null || true
sudo rm -rf /etc/enola-server 2>/dev/null || true

# -------------------------------
# 1️⃣1️⃣ Eliminar logs
# -------------------------------
echo "Eliminando logs de Enola..."
sudo rm -rf /var/log/enola-server/* 2>/dev/null || true

# -------------------------------
# 1️⃣2️⃣ Limpiar WordPress antiguo
# -------------------------------
echo "Eliminando WordPress antiguo en /var/www/html..."
sudo rm -rf /var/www/html/* 2>/dev/null || true

# -------------------------------
# 1️⃣3️⃣ Reiniciar NGINX
# -------------------------------
echo "Reiniciando NGINX..."
sudo systemctl restart nginx 2>/dev/null || true

echo ""
echo "✅ Limpieza completa. Entorno listo para una nueva instalación."
echo ""

# -------------------------------
# 1️⃣4️⃣ Listado final de estado
# -------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Estado del sistema:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Contenedores restantes:"
sudo podman ps -a
echo ""
echo "Redes existentes:"
sudo podman network ls
echo ""
echo "Servicios Tor activos:"
ls -1 /etc/tor/enola.d/*.conf 2>/dev/null | wc -l || echo "0"
echo ""
echo "Configuraciones NGINX activas:"
ls -1 /etc/nginx/sites-enabled/ 2>/dev/null | grep -v default | wc -l || echo "0"
echo ""
