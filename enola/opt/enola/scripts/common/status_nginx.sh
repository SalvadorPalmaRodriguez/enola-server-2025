#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

GREEN="\033[0;32m"; RED="\033[0;31m"; YELLOW="\033[1;33m"; CYAN="\033[0;36m"; NC="\033[0m"

get_nginx_status() {
    echo -e "\n🌐 ${CYAN}Estado de NGINX${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! systemctl is-active --quiet nginx; then
        echo -e "❌ ${RED}NGINX está inactivo o fallando${NC}"
        return
    fi

    echo -e "✅ ${GREEN}NGINX está activo${NC}"

    # Puerto visible (intentar con y sin sudo)
    port=$(sudo ss -tulnp 2>/dev/null | grep nginx | awk '{print $5}' | head -n1 | cut -d: -f2 || \
           grep -E "^\s*listen" /etc/nginx/sites-enabled/default 2>/dev/null | grep -o '[0-9]\+' | head -1 || \
           echo "80")
    
    echo "📌 Puerto configurado: $port"

    # Test de respuesta local
    code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$port 2>/dev/null || echo "000")
    if [[ "$code" == "200" ]]; then
        echo -e "🟢 Respuesta HTTP: ${GREEN}$code OK${NC}"
    elif [[ "$code" == "000" ]]; then
        echo -e "⚠️  No se pudo conectar (puede ser normal si está en localhost)"
    else
        echo -e "⚠️  Respuesta HTTP: $code"
    fi

    # Información adicional
    echo ""
    echo "📂 Configuración principal: /etc/nginx/nginx.conf"
    echo "📂 Sites habilitados: /etc/nginx/sites-enabled/"
    
    # Mostrar sites configurados
    if [ -d /etc/nginx/sites-enabled ]; then
        echo ""
        echo "🔗 Sitios configurados:"
        site_count=0
        for site in /etc/nginx/sites-enabled/*; do
            if [ -f "$site" ]; then
                site_name=$(basename "$site")
                site_count=$((site_count + 1))
                
                # Extraer información del puerto del sitio
                if [ -r "$site" ]; then
                    listen_port=$(grep -E "^\s*listen" "$site" 2>/dev/null | head -1 | sed -E 's/.*:([0-9]+).*/\1/' || echo "?")
                    proxy_pass=$(grep -E "proxy_pass" "$site" 2>/dev/null | grep -o 'http://[^;]*' | head -1 || echo "")
                    
                    echo "   • $site_name"
                    echo "     - Puerto: $listen_port"
                    if [ -n "$proxy_pass" ]; then
                        echo "     - Backend: $proxy_pass"
                    fi
                else
                    echo "   • $site_name (sin permisos de lectura)"
                fi
            fi
        done
        
        if [ $site_count -eq 0 ]; then
            echo "   (ninguno configurado)"
        else
            echo ""
            echo "📊 Total: $site_count sitio(s) configurado(s)"
        fi
    fi
    
    # Verificar configuración
    echo ""
    config_test=$(nginx -t 2>&1 || sudo nginx -t 2>&1 || echo "failed")
    if echo "$config_test" | grep -q "syntax is ok"; then
        echo -e "✅ ${GREEN}Configuración válida${NC}"
    else
        echo -e "ℹ️  Verificación de configuración requiere permisos"
    fi
}

# Ejecutar la función si el script se llama directamente
get_nginx_status
