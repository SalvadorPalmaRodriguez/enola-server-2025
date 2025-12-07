# ⚠️ Licencia de Uso No Comercial

**Este software está protegido por una licencia de uso NO COMERCIAL.**

Queda prohibido el uso en entornos empresariales, comerciales, SaaS, venta, o cualquier actividad con fines de lucro, salvo autorización expresa del titular.

*El titular (Salvador Palma Rodríguez) se reserva el derecho de comercializar, licenciar o autorizar el uso comercial del software.*

Consulta el archivo LICENSE para detalles completos.

# 🧅 Enola Server

> **Sistema profesional de gestión de servicios Onion (Tor Hidden Services) con auto-mantenimiento**

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://github.com/SalvadorPalmaRodriguez/enola-server-2025/releases/tag/v1.1.0)
[![License](https://img.shields.io/badge/license-Non--Commercial-orange.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Debian%2FUbuntu-red.svg)](https://www.debian.org/)

---

## 📋 Descripción

**Enola Server** automatiza completamente el despliegue y gestión de servicios web anónimos en la red Tor. Esta versión es una release candidate (demo), abierta a feedback y revisión. No se recomienda para producción.

### ✨ Características Destacadas

- 🚀 **WordPress automatizado** - Deployment completo con contenedores Podman
- 🔄 **Health checks automáticos** - Monitoreo continuo con auto-reinicio inteligente
- 🛡️ **Backups y rollback** - Sistema de respaldo automático antes de cada cambio
- ⚡ **UX intuitiva** - Atajos de teclado, ayuda contextual, confirmaciones
- 🔧 **13 herramientas de diagnóstico** - Troubleshooting integrado
- ✅ **Validación proactiva** - Previene conflictos de puertos y errores de configuración

---

## 🎯 Casos de Uso

- **Blogs anónimos** - WordPress en Hidden Service con SSL
- **Acceso SSH seguro** - SSH vía Tor sin exponer IP
- **Hosting de apps web** - Cualquier aplicación HTTP/HTTPS
- **Desarrollo y testing** - Entorno aislado para pruebas

---

### 🌐 Casos de Uso Reales

**1. Desarrollo web sin gastos ni complicaciones**  
Cuando desarrollas una app web, normalmente solo puedes probar en local. Si quieres mostrar una demo a otros, debes contratar hosting, comprar dominio, configurar DNS y tener conocimientos avanzados de redes. Enola Server 2025 elimina todo eso: despliegue automático, seguro y privado en la red Tor, sin gastos ni exposición pública. Ideal para pruebas, demos y validación antes de invertir en infraestructura.

**2. Demos privadas para clientes en consultoras**  
En empresas de desarrollo y consultoras, mostrar avances a clientes suele requerir publicar la web antes de tiempo, comprar dominios y exponer la idea a la competencia. Con Enola Server 2025, puedes compartir el acceso solo con quien tú quieras, sin revelar el proyecto ni incurrir en gastos innecesarios. Así proteges la confidencialidad y la estrategia comercial.

**3. Publicación segura de denuncias y testimonios**  
Personas que quieren denunciar corrupción, negligencias médicas, estafas, acoso o violencia, y temen por su seguridad, pueden publicar información de forma anónima y segura usando Enola Server 2025, sin dejar rastro ni exponerse a represalias. La red Tor y el sistema de Enola garantizan privacidad y protección.

---

## 📦 Instalación Rápida

### Requisitos

- Debian 11/12 (o derivados como Ubuntu)
- 1GB RAM mínimo, 2GB recomendado
- Conexión a internet

### Método 1: Instalación Manual (Recomendado)

Usa `apt` para instalar el paquete — resolverá dependencias automáticamente.

```bash
# Descargar última versión
wget https://github.com/SalvadorPalmaRodriguez/enola-server-2025/releases/download/v1.1.0/enola-server_1.1.0_all.deb

# Instalar con apt (resuelve dependencias automáticamente)
sudo apt update
sudo apt install -y ./enola-server_1.1.0_all.deb

# Ejecutar menú principal
sudo enola-server
```

### Método 2: Script Instalador (Para Usuarios Novatos)

Si prefieres un instalador que haga todo automáticamente:

```bash
# Descargar paquete y script instalador
wget https://github.com/SalvadorPalmaRodriguez/enola-server-2025/releases/download/v1.1.0/enola-server_1.1.0_all.deb
wget https://raw.githubusercontent.com/SalvadorPalmaRodriguez/enola-server-2025/main/scripts/install_and_deps.sh

# Ejecutar instalador
chmod +x install_and_deps.sh
sudo ./install_and_deps.sh ./enola-server_1.1.0_all.deb
```

El script `install_and_deps.sh`:
- ✅ Actualiza índices de paquetes
- ✅ Instala todas las dependencias necesarias
- ✅ Instala el paquete .deb
- ✅ Ejecuta verificación post-instalación

### Método 3: Desde Código Fuente (Desarrolladores)

```bash
# Clonar repositorio
git clone https://github.com/SalvadorPalmaRodriguez/enola-server-2025.git
cd enola-server-2025

# Construir paquete
bash scripts/build.sh

# Instalar con apt
sudo apt update
sudo apt install -y ./enola-server_1.1.0_all.deb
```

---

## 🚀 Inicio Rápido

### 1. Desplegar WordPress en Onion

```bash
sudo enola-server
→ WordPress → Generar nuevo WordPress
→ Nombre: "blog"
→ Puerto backend: 8080
```

Resultado: WordPress funcional en dirección `.onion` con SSL y MySQL

### 2. Ver servicios activos

```bash
sudo enola-server
→ Gestión de Servicios Tor → Listar servicios
```

### 3. Acceder vía Tor Browser

```
http://<tu-direccion>.onion
```

---

## 📚 Documentación

### Para Usuarios

- **[README Completo](enola/README.md)** - Documentación detallada del servidor
- **[Configuración SSH Cliente](docs/CLIENT_SSH_SETUP.md)** - Cómo conectar vía SSH
- **[Product Brief](PRODUCT_BRIEF.md)** - Presentación para inversores
- **[Scripts de Desarrollo](scripts/README.md)** - Documentación de scripts

### Scripts de Desarrollo

```bash
# Construir paquete .deb
bash scripts/build.sh

# Limpiar entorno (elimina contenedores, configs, etc.)
bash scripts/clean.sh

# Generar claves SSH cliente
bash scripts/client-keygen.sh

# Actualizar release a nueva versión
./scripts/release_update.sh 1.2.0

# Sincronizar tag y asset con main actual (sin cambiar versión)
./scripts/release_update.sh --sync
```

---

## 🏗️ Arquitectura

**Arquitectura General:**
```
┌─────────────────────────────────────────┐
│           Enola Server v1.0             │
│         (Bash + Systemd)                │
└────────────┬────────────────────────────┘
             │
             │
        ┌────▼────┐
        │   Tor   │
        │ Hidden  │
        │ Service │
        └────┬────┘
             │
        ┌────▼─────┐
        │  NGINX   │
        │  Reverse │
        │  Proxy   │
        └────┬─────┘
             │
        ┌────▼──────────┐
        │ Tu Aplicación │
        │  (Backend en  │
        │   localhost)  │
        └───────────────┘
             │
    ┌────────▼─────────┐
    │ tuapp.onion      │
    │ (Dirección .onion│
    │  generada)       │
    └──────────────────┘
```

**Caso de Uso: WordPress (incluido):**
```
┌─────────────────────────────────────────┐
│           Enola Server v1.0             │
└────────────┬────────────────────────────┘
             │
             │
        ┌────▼────┐
        │   Tor   │
        │ Hidden  │
        │ Service │
        └────┬────┘
             │
        ┌────▼─────┐
        │  NGINX   │
        │  Reverse │
        │  Proxy   │
        └────┬─────┘
             │
        ┌────▼───────┐
        │   Podman   │
        │ (Container)│
        └────┬───────┘
             │
        ┌────▼───────┐
        │ WordPress  │
        │  + MySQL   │
        └────────────┘
             │
    ┌────────▼─────────┐
    │ tuweb.onion      │
    │ (Dirección .onion│
    │  generada)       │
    └──────────────────┘
```

**Componentes:**
- **Tor** - Hidden Services y proxy SOCKS
- **NGINX** - Reverse proxy con SSL
- **Podman** - Contenedores sin privilegios
- **Systemd** - Gestión de servicios y timers
- **Health Monitor** - Auto-recuperación automática

---

## 📈 Estado del Proyecto

### ✅ Completado (v1.1.0)

| Fase | Características | Estado |
|------|----------------|--------|
| **Fase 1** | UX Básicas (breadcrumbs, dashboard, '0=Volver') | ✅ 100% |
| **Fase 2** | UX Avanzadas (atajos, confirmaciones, mensajes) | ✅ 100% |
| **Fase 3** | Seguridad (validación puertos, backups, ayuda) | ✅ 100% |
| **Fase 4** | Hardening (health checks, auto-reinicio) | ✅ 100% |

### 🔮 Roadmap Futuro (Requiere Financiación)

- **Fase 5:** Observabilidad (dashboard recursos, logs centralizados)
- **Fase 6:** Automatización (despliegue YAML, API REST)
- **Fase 7:** Seguridad Avanzada (UFW, file sharing, fwknop, HTTP auth)

El roadmap completo se encuentra resumido en este documento. Para más detalles, consulta futuras actualizaciones.

---

## 🤝 Contribuir

Este proyecto está bajo una **licencia Source Available** que permite:
- ✅ Uso personal y educativo
- ✅ Estudiar el código fuente
- ✅ Reportar bugs mediante Issues

**Actualmente aceptamos:**
- 🐛 **Issues** - Reportes de bugs y problemas
- 💡 **Discussions** - Propuestas e ideas de mejoras

**Pull Requests temporalmente cerrados:** Actualmente el proyecto está en fase de financiación y no hay recursos para revisar código externo. Se abrirán una vez conseguida financiación.

Para detalles sobre cómo contribuir, consulta la sección de contribución en este documento o contacta al autor.

**Nota:** El uso comercial y la redistribución están restringidos. Contacta para licencias comerciales.

### 🔍 Monitoreo de Forks

Este proyecto **permite forks** para facilitar el estudio del código y la auditoría de seguridad. Sin embargo, **todos los forks son monitoreados** públicamente.

**Ayuda a proteger el proyecto:**
```bash
# Ejecuta el script de monitoreo (requiere: gh, jq)
bash scripts/monitor_forks.sh
```

Si detectas un fork con:
- ❌ Uso comercial no autorizado
- ❌ Redistribución del software
- ❌ Eliminación de avisos de copyright
- ❌ Competencia comercial

**Reporta a:** salvadorpalmarodriguez@gmail.com

---

## 📄 Licencia

**Copyright © 2025 Salvador Palma Rodríguez**

Este software está bajo una **Licencia Source Available - No Comercial**.

✅ **Permitido:**
- Uso personal, educativo e investigación
- Estudio del código fuente
- Modificaciones privadas
- Contribuciones al proyecto oficial

❌ **Prohibido:**
- Uso comercial sin autorización
- Redistribución (ni original ni modificado)
- Competencia comercial

**Nota:** Los forks están permitidos para estudio y auditoría, pero son monitoreados públicamente. Ver sección "Monitoreo de Forks" arriba.

⚠️ **GARANTÍAS:**
- El software se proporciona **"TAL CUAL"** (AS IS)
- **Sin garantías** de ningún tipo, expresas o implícitas
- Sin responsabilidad por daños derivados del uso

**[Ver licencia completa](LICENSE)**

---

## 📞 Contacto

**Autor:** Salvador Palma Rodríguez  
**Email:** salvadorpalmarodriguez@gmail.com  
**GitHub:** [@SalvadorPalmaRodriguez](https://github.com/SalvadorPalmaRodriguez)  
**LinkedIn:** [Salvador Palma Rodríguez](https://es.linkedin.com/in/salvadorpalmarodriguez)

### Para Empresas e Inversores

¿Interesado en licencias comerciales, inversión, partnership o colaboración?

Estoy abierto a propuestas de inversión, partnership, licencias comerciales anticipadas y colaboraciones en desarrollo. Todas las condiciones y beneficios se negociarán caso por caso, según el interés y la aportación de cada parte.

Por favor contacta: salvadorpalmarodriguez@gmail.com  
🔗 LinkedIn: [Salvador Palma Rodríguez](https://es.linkedin.com/in/salvadorpalmarodriguez)

---

## 🙏 Agradecimientos

- [Tor Project](https://www.torproject.org/) - Red de anonimato
- [NGINX](https://nginx.org/) - Reverse proxy
- [Podman](https://podman.io/) - Contenedores sin privilegios
- [Debian](https://www.debian.org/) - Sistema base

---

## 📊 Estadísticas

- **5,000+** líneas de código Bash
- **30+** scripts modulares
- **15/15** tests pasando ✅
- **>95%** uptime estimado
- **50-60%** reducción de errores vs manual

---

**🎉 ¡Bienvenido a Enola Server v1.1.0!**

```bash
sudo dpkg -i enola-server_1.1.0_all.deb
sudo enola-server
```
