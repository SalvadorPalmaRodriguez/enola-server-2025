#!/bin/bash

# backup_manager.sh
# Sistema de backup automático y rollback para Enola Server

BACKUP_DIR="/var/backups/enola-server"
MAX_BACKUPS=5  # Mantener últimas 5 versiones

# Colores
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
NC="\033[0m"

# Crear directorio de backup si no existe
init_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR" 2>/dev/null || sudo mkdir -p "$BACKUP_DIR"
        echo -e "${GREEN}✅ Directorio de backups creado: $BACKUP_DIR${NC}"
    fi
}

# Hacer backup de un archivo
backup_file() {
    local file_path="$1"
    local service_name="${2:-unknown}"
    
    if [ ! -f "$file_path" ]; then
        echo -e "${RED}❌ Archivo no encontrado: $file_path${NC}"
        return 1
    fi
    
    init_backup_dir
    
    local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local filename=$(basename "$file_path")
    local backup_name="${timestamp}_${service_name}_${filename}.bak"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    # Copiar archivo
    if cp "$file_path" "$backup_path" 2>/dev/null || sudo cp "$file_path" "$backup_path"; then
        echo -e "${GREEN}✅ Backup creado: $backup_name${NC}"
        
        # Limpiar backups antiguos
        cleanup_old_backups "$service_name" "$filename"
        
        echo "$backup_path"  # Retornar ruta del backup
        return 0
    else
        echo -e "${RED}❌ Error al crear backup${NC}"
        return 1
    fi
}

# Backup de múltiples archivos relacionados con un servicio
backup_service() {
    local service_name="$1"
    local backed_up_files=()
    
    echo -e "${CYAN}📦 Creando backup para servicio: $service_name${NC}"
    
    # Backup de configuración Tor
    if [ -f "/etc/tor/enola.d/${service_name}.conf" ]; then
        local bak=$(backup_file "/etc/tor/enola.d/${service_name}.conf" "$service_name")
        [ $? -eq 0 ] && backed_up_files+=("$bak")
    fi
    
    # Backup de configuración NGINX
    if [ -f "/etc/nginx/sites-available/${service_name}.conf" ]; then
        local bak=$(backup_file "/etc/nginx/sites-available/${service_name}.conf" "$service_name")
        [ $? -eq 0 ] && backed_up_files+=("$bak")
    fi
    
    # Backup de .env de WordPress (si existe)
    if [ -f "/opt/enola/wordpress/${service_name}/wordpress.env" ]; then
        local bak=$(backup_file "/opt/enola/wordpress/${service_name}/wordpress.env" "$service_name")
        [ $? -eq 0 ] && backed_up_files+=("$bak")
    fi
    
    if [ ${#backed_up_files[@]} -gt 0 ]; then
        echo -e "${GREEN}✅ Backup completado: ${#backed_up_files[@]} archivo(s)${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  No se encontraron archivos para respaldar${NC}"
        return 1
    fi
}

# Limpiar backups antiguos (mantener solo MAX_BACKUPS)
cleanup_old_backups() {
    local service_name="$1"
    local filename="$2"
    
    # Contar backups existentes para este archivo
    local pattern="*_${service_name}_${filename}.bak"
    local backups=($(ls -t "$BACKUP_DIR"/$pattern 2>/dev/null))
    local count=${#backups[@]}
    
    if [ $count -gt $MAX_BACKUPS ]; then
        echo -e "${YELLOW}🗑️  Limpiando backups antiguos (mantener últimos $MAX_BACKUPS)...${NC}"
        
        # Eliminar los más antiguos
        for i in $(seq $MAX_BACKUPS $((count - 1))); do
            local old_backup="${backups[$i]}"
            rm -f "$old_backup" 2>/dev/null || sudo rm -f "$old_backup"
            echo "   Eliminado: $(basename $old_backup)"
        done
    fi
}

# Listar backups disponibles para un servicio
list_backups() {
    local service_name="${1:-*}"
    
    echo -e "${CYAN}📋 Backups disponibles:${NC}"
    echo ""
    
    local backups=($(ls -t "$BACKUP_DIR"/*_${service_name}_*.bak 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️  No hay backups disponibles para: $service_name${NC}"
        return 1
    fi
    
    local i=1
    for backup in "${backups[@]}"; do
        local basename_file=$(basename "$backup")
        local timestamp=$(echo "$basename_file" | cut -d'_' -f1-2)
        local size=$(du -h "$backup" | cut -f1)
        
        echo -e "${i}) $basename_file"
        echo "   📅 Fecha: $timestamp | 💾 Tamaño: $size"
        echo ""
        ((i++))
    done
    
    return 0
}

# Restaurar desde un backup
restore_backup() {
    local backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}❌ Backup no encontrado: $backup_file${NC}"
        return 1
    fi
    
    # Extraer información del nombre del archivo
    local basename_file=$(basename "$backup_file" .bak)
    local original_name=$(echo "$basename_file" | rev | cut -d'_' -f1 | rev)
    local service_name=$(echo "$basename_file" | cut -d'_' -f3)
    
    # Determinar ruta de destino
    local dest_path=""
    
    if [[ "$original_name" == *.conf ]] && [[ "$backup_file" == *enola.d* ]]; then
        dest_path="/etc/tor/enola.d/$original_name"
    elif [[ "$original_name" == *.conf ]]; then
        dest_path="/etc/nginx/sites-available/$original_name"
    elif [[ "$original_name" == *.env ]]; then
        dest_path="/opt/enola/wordpress/$service_name/$original_name"
    else
        echo -e "${RED}❌ No se pudo determinar la ruta de destino${NC}"
        return 1
    fi
    
    # Confirmar
    echo -e "${YELLOW}⚠️  ¿Restaurar backup?${NC}"
    echo "   Origen:  $backup_file"
    echo "   Destino: $dest_path"
    echo ""
    read -p "¿Continuar? [y/N]: " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}⚠️  Restauración cancelada${NC}"
        return 1
    fi
    
    # Hacer backup del archivo actual antes de restaurar
    if [ -f "$dest_path" ]; then
        echo -e "${CYAN}📦 Creando backup de seguridad del archivo actual...${NC}"
        backup_file "$dest_path" "${service_name}_pre_restore"
    fi
    
    # Restaurar
    if cp "$backup_file" "$dest_path" 2>/dev/null || sudo cp "$backup_file" "$dest_path"; then
        echo -e "${GREEN}✅ Backup restaurado exitosamente${NC}"
        echo -e "${CYAN}💡 Recuerda reiniciar los servicios afectados (nginx, tor, contenedores)${NC}"
        return 0
    else
        echo -e "${RED}❌ Error al restaurar backup${NC}"
        return 1
    fi
}

# Rollback interactivo para un servicio
rollback_service() {
    local service_name="$1"
    
    echo -e "${CYAN}🔄 Rollback de servicio: $service_name${NC}"
    echo ""
    
    if ! list_backups "$service_name"; then
        return 1
    fi
    
    echo ""
    read -p "Selecciona el número del backup a restaurar (o 'q' para cancelar): " choice
    
    if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
        echo -e "${YELLOW}⚠️  Rollback cancelado${NC}"
        return 1
    fi
    
    # Obtener archivo seleccionado
    local backups=($(ls -t "$BACKUP_DIR"/*_${service_name}_*.bak 2>/dev/null))
    local selected_backup="${backups[$((choice - 1))]}"
    
    if [ -z "$selected_backup" ] || [ ! -f "$selected_backup" ]; then
        echo -e "${RED}❌ Selección inválida${NC}"
        return 1
    fi
    
    restore_backup "$selected_backup"
}

# Mostrar ayuda
show_help() {
    cat << 'EOF'
backup_manager.sh - Sistema de Backup para Enola Server

USO:
    source /opt/enola/scripts/common/backup_manager.sh
    
FUNCIONES DISPONIBLES:

    backup_file <archivo> [nombre_servicio]
        Hace backup de un archivo individual
        
    backup_service <nombre_servicio>
        Hace backup de todos los archivos de un servicio
        (Tor .conf, NGINX .conf, WordPress .env)
        
    list_backups [nombre_servicio]
        Lista backups disponibles para un servicio
        
    restore_backup <archivo_backup>
        Restaura un archivo desde un backup
        
    rollback_service <nombre_servicio>
        Rollback interactivo para un servicio

EJEMPLOS:

    # Backup antes de editar
    backup_service "limon"
    
    # Listar backups
    list_backups "limon"
    
    # Rollback interactivo
    rollback_service "limon"

CONFIGURACIÓN:

    BACKUP_DIR: /var/backups/enola-server/
    MAX_BACKUPS: 5 (últimas 5 versiones)

EOF
}

# Si se ejecuta directamente, mostrar ayuda
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_help
fi
