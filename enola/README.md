# 🧅 Enola Server v1.0.0-rc

> **Sistema completo de gestión de servicios Onion con auto-mantenimiento**

[![Version](https://img.shields.io/badge/version-1.0.0-rc-blue.svg)](https://github.com/SalvadorPalmaRodriguez/enola-server-2025/releases/tag/v1.0.0-rc)
[![License](https://img.shields.io/badge/license-Non--Commercial-orange.svg)](LICENSE)
[![Debian](https://img.shields.io/badge/debian-package-red.svg)](https://www.debian.org/)

**Enola Server** es un sistema profesional para desplegar y gestionar servicios web anónimos en la red Tor (Hidden Services). Esta versión es una release candidate (demo), abierta a feedback y revisión. No se recomienda para producción.

---

## ✨ Características Principales

### 🚀 Instalación y Despliegue Rápido
- ✅ Instalación completa simplificada
- ✅ WordPress Onion funcional rápidamente
- ✅ Configuración automática de NGINX con SSL
- ✅ Hidden Services de Tor auto-configurados
- ✅ Smoke test automático post-instalación

### 🔄 Auto-Mantenimiento Inteligente
- ✅ **Health checks programados** (systemd timer)
- ✅ **Auto-reinicio inteligente** (máx 3 intentos con cooldown)
- ✅ Verifica: NGINX, Tor, WordPress, puertos, disco
- ✅ Logs detallados en `/var/log/enola-server/health.log`
- ✅ Sin intervención manual necesaria

### 🛡️ Seguridad y Recuperación
- ✅ **Backups automáticos** antes de cada edición
- ✅ **Rollback interactivo** (últimas 5 versiones)
- ✅ **Validación de puertos** (previene conflictos)
- ✅ SSL autofirmado por defecto
- ✅ Contenedores Podman (sin privilegios de root)

### 💡 UX Profesional
- ✅ **Atajos de teclado** (sin presionar Enter)
- ✅ **Breadcrumbs de navegación**
- ✅ **Sistema de ayuda contextual** (presiona 'h')
- ✅ **Confirmaciones para acciones destructivas**
- ✅ **Mensajes estandarizados** (✅/❌/⚠️)
- ✅ **Mini-dashboard de estado**

### 🔧 Diagnósticos Completos
- ✅ 13 herramientas de diagnóstico integradas
- ✅ Estado detallado de servicios
- ✅ Verificación de sincronización (systemd ↔ contenedores)
- ✅ Test de configuraciones (NGINX, Tor)
- ✅ Visualización de logs

---

## 📦 Instalación

### Requisitos Previos

**Sistema operativo:** Debian 11/12 (o derivados)

**Dependencias automáticas:**
```bash
# Se instalan automáticamente con el paquete
tor nginx openssh-server podman curl dialog figlet
certbot python3-certbot-nginx apache2-utils
```

**Opcionales (recomendadas):**
```bash
sudo apt install ufw fwknop-client fzf xclip toilet
```

### Instalación desde .deb

```bash
# 1. Descargar el paquete (ejemplo GitHub Releases)
wget https://github.com/SalvadorPalmaRodriguez/enola-server-2025/releases/download/v1.0.0-rc/enola-server_1.0.0-rc_all.deb

# 2. Instalar
sudo dpkg -i enola-server_1.0.0-rc_all.deb

# 3. Resolver dependencias si es necesario
sudo apt-get install -f

# 4. Verificar instalación (smoke test ejecutado automáticamente)
sudo enola-server --smoke
```

### Verificación Post-Instalación

```bash
# Verificar servicios systemd
systemctl status enola-tor.service
systemctl status enola-health.timer

# Ver logs del health monitor
sudo tail -f /var/log/enola-server/health.log

# Verificar directorios creados
ls -la /opt/enola/scripts/
ls -la /var/lib/enola-server/health/
```

---

## 🎯 Uso Rápido

### Menú Principal

```bash
# Lanzar menú interactivo
sudo enola-server
```

**Opciones principales:**
1. **Gestión de Servicios Tor** → Crear/listar/eliminar Hidden Services
2. **WordPress** → Generar, editar, start/stop
3. **NGINX** → Configuración de reverse proxy
4. **SSH Hidden Service** → Acceso anónimo vía Tor
5. **Diagnósticos** → 13 herramientas de troubleshooting
6. **Configuración** → Editar puertos, fwknop, etc.

### WordPress en 3 Pasos

```bash
# Paso 1: Ejecutar menú
sudo enola-server

# Paso 2: Generar WordPress
# WordPress → Generar nuevo WordPress
#   - Nombre: blog
#   - Puerto backend: 8080
#   - Sistema crea automáticamente:
#     * Contenedores Podman (WordPress + MySQL)
#     * Servicio Tor Hidden Service (.onion)
#     * Configuración NGINX reverse proxy
#     * Servicio systemd para auto-inicio

# Paso 3: Acceder
# WordPress → Listar servicios WordPress
#   - Copiar dirección .onion
#   - Abrir en Tor Browser
#   - Completar wizard de instalación WordPress
```

### Gestión de Servicios Tor

```bash
sudo enola-server
→ Gestión de Servicios Tor

# Opciones disponibles:
1. Añadir servicio         # Crear nuevo Hidden Service
2. Habilitar servicio      # Activar servicio deshabilitado
3. Deshabilitar servicio   # Desactivar (no elimina config)
4. Eliminar servicio       # Borrar completamente
5. Listar servicios        # Ver todos los servicios activos
```

### Comandos Útiles

```bash
# Smoke test (diagnóstico rápido)
sudo enola-server --smoke

# Ver logs del health monitor
sudo journalctl -u enola-health.service -f

# Estado de todos los contenedores WordPress
podman ps -a | grep enola

# Ver servicios Onion activos
sudo cat /etc/tor/torrc.d/enola-services.conf
```

---

## 📚 Documentación

### Estructura del Proyecto

```
/opt/enola/scripts/
├── menu/
│   └── enola_menu.sh              # Menú principal
├── common/
│   ├── health_monitor.sh          # Health checks automáticos
│   ├── smoke_test.sh              # Diagnóstico rápido
│   ├── backup_manager.sh          # Sistema de backups
│   └── status_functions.sh        # Funciones de estado
├── tor/
│   ├── deploy_tor.sh              # Configurar Tor principal
│   ├── deploy_tor_web.sh          # Crear Hidden Service
│   └── list_services.sh           # Listar servicios
├── services/
│   ├── enable/                    # Scripts para habilitar
│   ├── disable/                   # Scripts para deshabilitar
│   └── remove/                    # Scripts para eliminar
├── nginx/
│   └── deploy_nginx.sh            # Configurar NGINX
└── wordpress/
    ├── generate_wordpress.sh      # Desplegar WordPress
    ├── edit_wordpress.sh          # Editar configuración
    └── toggle_wordpress.sh        # Start/Stop

/etc/tor/torrc.d/                  # Configuraciones Tor
/etc/nginx/sites-available/        # Configuraciones NGINX
/var/log/enola-server/             # Logs centralizados
/var/lib/enola-server/health/      # Estado del health monitor
/var/backups/enola-server/         # Backups automáticos
```

### Sistema de Ayuda Contextual

Presiona **'h'** en cualquier menú para ver:
- Explicación de la sección actual
- Conceptos clave (Onion, Backend, SSL, etc.)
- Ubicación de archivos importantes
- Ejemplos de uso

### Health Monitor

**Archivo:** `/opt/enola/scripts/common/health_monitor.sh`

**Verificaciones:**
- ✅ NGINX: Estado + validación de config (`nginx -t`)
- ✅ Tor: Estado + puerto SOCKS 9050
- ✅ WordPress: Todos los contenedores (WP + MySQL)
- ✅ Systemd: Servicios `container-enola-*`
- ✅ Puertos críticos
- ✅ Espacio en disco (alerta >80%, error >90%)

**Protecciones:**
- Máximo 3 intentos de reinicio por servicio
- Cooldown entre reintentos
- Reseteo automático si servicio estabiliza
- Logs detallados para troubleshooting

**Configuración:**
```bash
# Ver estado del timer
systemctl status enola-health.timer

# Ver última ejecución
sudo journalctl -u enola-health.service -n 50

# Ejecutar manualmente
sudo /opt/enola/scripts/common/health_monitor.sh

# Deshabilitar (no recomendado)
sudo systemctl disable --now enola-health.timer
```

### Sistema de Backups

**Automático:** Antes de editar cualquier configuración  
**Ubicación:** `/var/backups/enola-server/<tipo>/<nombre>/`  
**Retención:** Últimas 5 versiones por servicio

**Rollback manual:**
```bash
sudo enola-server
→ Configuración → Backups y Rollback
→ Selecciona servicio y versión a restaurar
```

---

## 🚀 Casos de Uso

### 1. Blog Personal Anónimo
```bash
# Desplegar WordPress en .onion
sudo enola-server → WordPress → Generar nuevo WordPress
# Resultado: Blog accesible solo vía Tor Browser
```

### 2. Acceso SSH Anónimo
```bash
# Configurar SSH Hidden Service
sudo enola-server → Gestión de Servicios Tor → Añadir servicio
# Puerto local: 22 (SSH) → Puerto Onion: 22
# Conectar desde cliente: torify ssh usuario@<direccion>.onion
```

### 3. Hosting de Aplicaciones Web
```bash
# Crear servicio HTTP personalizado
# 1. Tu app corre en localhost:puerto (ej: 3000)
# 2. Crear Hidden Service
sudo enola-server → Gestión de Servicios Tor → Añadir servicio
#    Puerto local: 3000 → Puerto Onion: 80
# 3. Opcional: Configurar NGINX como reverse proxy
sudo enola-server → NGINX → Desplegar configuración NGINX
```

---

## 🛠️ Troubleshooting

### Problema: Servicios no inician

```bash
# 1. Verificar logs del health monitor
sudo tail -50 /var/log/enola-server/health.log

# 2. Verificar servicios systemd
systemctl status enola-tor.service
systemctl status nginx.service

# 3. Ejecutar smoke test
sudo enola-server --smoke

# 4. Ver logs del servicio específico
sudo journalctl -u enola-tor.service -n 100
```

### Problema: WordPress no accesible

```bash
# 1. Verificar contenedores
podman ps -a | grep enola-<nombre>

# 2. Ver logs del contenedor
podman logs enola-<nombre>-wp

# 3. Verificar sincronización systemd
sudo enola-server → Diagnósticos → Verificar sync systemd vs contenedores

# 4. Reiniciar servicios
sudo enola-server → WordPress → Start/Stop servicios
```

### Problema: Puerto ocupado

```bash
# Sistema valida automáticamente, pero si ocurre:
# 1. Ver qué proceso usa el puerto
sudo ss -tulpn | grep :<puerto>

# 2. Editar configuración con nuevo puerto
sudo enola-server → WordPress → Editar WordPress
# Sistema detectará conflicto y sugerirá puerto libre
```

### Problema: Health checks fallan constantemente

```bash
# 1. Verificar máximo de reintentos alcanzado
sudo ls -la /var/lib/enola-server/health/

# 2. Resetear contador manualmente
sudo rm /var/lib/enola-server/health/<servicio>_*

# 3. Verificar problema subyacente
sudo journalctl -u <servicio> -n 200
```

---

## 🗺️ Roadmap

### ✅ Completado (v1.0.0)

| Fase | Características | Estado |
|------|----------------|--------|
| **Fase 1** | UX Básicas (breadcrumbs, dashboard, '0=Volver') | ✅ 100% |
| **Fase 2** | UX Avanzadas (atajos, confirmaciones, mensajes) | ✅ 100% |
| **Fase 3** | Seguridad (validación puertos, backups, ayuda) | ✅ 100% |
| **Fase 4** | Hardening (health checks, auto-reinicio) | ✅ 100% |

### 🔮 Futuro (Requiere Financiación)

**Fase 5: Observabilidad**
- Dashboard de recursos en tiempo real
- Logs centralizados con filtros
- Métricas de uso y uptime

**Fase 6: Automatización**
- Despliegue batch desde YAML
- API REST para gestión remota
- Webhooks y CI/CD

**Fase 7: Seguridad Avanzada**
- 🔒 UFW Firewall automático
- 📁 File Sharing Onion
- 🔐 fwknop (Port Knocking)
- 🔑 HTTP Basic Auth
- 👤 Usuario dedicado (sin sudo)

**Ver detalles:** [PRODUCT_BRIEF.md](../PRODUCT_BRIEF.md)

---

## 📈 Estadísticas del Proyecto

| Métrica | Valor |
|---------|-------|
| **Líneas de código** | ~5,000+ |
| **Scripts Bash** | 30+ |
| **Tests unitarios** | 15/15 ✅ |
| **Uptime estimado** | >95% (con health checks) |
| **Reducción de errores** | 50-60% vs manual |

---

## 📄 Licencia

**Copyright © 2025 Salvador Palma Rodríguez**

**Licencia Source Available - No Comercial**

✅ **Permitido:**
- Uso personal y educativo
- Investigación y pruebas
- Crear forks públicos para estudio, auditoría o proponer mejoras
- Modificaciones en forks para uso no comercial
- Contribuciones al proyecto oficial (Issues, Discussions, Pull Requests)
- Participar en monitoreo comunitario de forks

❌ **Prohibido:**
- Uso comercial sin autorización (original o fork)
- Redistribución comercial
- Usar forks para distribución no autorizada
- Comercializar modificaciones o forks
- Competencia comercial
- Remover avisos de copyright

💡 **TRANSPARENCIA Y FORKS:**
El código está disponible públicamente y los **forks están PERMITIDOS** para estudio, auditoría y colaboración. Todos los forks son monitoreados públicamente para proteger la licencia. Esta apertura demuestra calidad y permite a la comunidad contribuir a la seguridad del proyecto.

🔍 **MONITOREO COMUNITARIO:**
La comunidad puede usar `/opt/enola/scripts/monitor_forks.sh` para vigilar el cumplimiento de esta licencia. Se agradece reportar violaciones a: salvadorpalmarodriguez@gmail.com

⚠️ **GARANTÍAS:**
- Software proporcionado **"TAL CUAL"** (AS IS)
- **Sin garantías** de ningún tipo
- Sin responsabilidad por daños

**Contacto para licencias comerciales:**  
📧 salvadorpalmarodriguez@gmail.com

---

## 🤝 Contribuciones

Este proyecto está en **búsqueda de financiación** para completar las Fases 5-7.

**Actualmente aceptamos:**
- 🐛 **Issues** - Reportes de bugs
- 💡 **Discussions** - Propuestas de mejoras

**Pull Requests:** Temporalmente cerrados (se abrirán post-financiación)

**Interesado en:**
- 💰 Invertir en el proyecto
- 🤝 Proponer partnership
- 📝 Licencia Enterprise
- 💻 Colaborar en desarrollo

**Contactar:** salvadorpalmarodriguez@gmail.com

---

## 📞 Soporte

**GitHub Issues:** [enola-server-2025/issues](https://github.com/SalvadorPalmaRodriguez/enola-server-2025/issues)  
**Email:** salvadorpalmarodriguez@gmail.com  
**Documentación completa:** Ver archivos `PRODUCT_BRIEF.md` y `docs/ROADMAP.md`

---

## 🙏 Agradecimientos

- **Tor Project** - Red de anonimato
- **NGINX** - Reverse proxy de alto rendimiento
- **Podman** - Contenedores sin privilegios
- **Debian** - Base del sistema

---

**¿Listo para desplegar servicios Onion profesionales?**

```bash
sudo dpkg -i enola-server_1.0.0_all.deb
sudo enola-server
```
