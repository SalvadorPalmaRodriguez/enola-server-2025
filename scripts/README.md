# 🔧 Scripts de Enola Server

Esta carpeta contiene scripts de utilidad para desarrollo, construcción y monitoreo.

---

## 📦 Scripts de Construcción

### `build.sh`
Construye el paquete Debian `.deb` desde el código fuente.

**Uso:**
```bash
bash scripts/build.sh
```

**Salida:**
- `enola-server_1.0.0_all.deb` - Paquete instalable

---

### `clean.sh`
Limpia el entorno de desarrollo eliminando:
- Contenedores Podman de WordPress
- Configuraciones de servicios Onion
- Configuraciones NGINX
- Logs y backups

**Uso:**
```bash
bash scripts/clean.sh
```

⚠️ **ADVERTENCIA:** Este script es destructivo. Solo usar en entornos de desarrollo.

---

## 🔑 Scripts de Cliente

### `client-keygen.sh`
Genera claves SSH para conectarse a servicios SSH vía Tor.

**Uso:**
```bash
bash scripts/client-keygen.sh
```

**Salida:**
- `~/.ssh/enola_client_key` - Clave privada
- `~/.ssh/enola_client_key.pub` - Clave pública

---

## 🔍 Script de Monitoreo

### `monitor_forks.sh` ⭐ PÚBLICO

**Propósito:** Monitoreo comunitario de forks para detectar violaciones de licencia.

**Cualquier usuario puede ejecutarlo** para ver todos los forks públicos y ayudar a proteger el proyecto.

**Requisitos:**
```bash
# Instalar dependencias
sudo apt install gh jq

# Autenticarse en GitHub
gh auth login
```

**Uso:**
```bash
bash scripts/monitor_forks.sh
```

**Salida ejemplo:**
```
╔════════════════════════════════════════════════════════════════╗
║     🔍 MONITOREO DE FORKS - ENOLA SERVER v1.1.0              ║
╚════════════════════════════════════════════════════════════════╝

📋 Total de forks encontrados: 3

👤 Usuario: usuario123
🔗 URL: https://github.com/usuario123/enola-server-2025
📅 Creado: 2025-11-23T15:30:00Z
⭐ Stars: 5
🍴 Forks del fork: 0
📝 Descripción: Fork para estudiar el código
```

**¿Qué monitorear?**

Si detectas un fork con:
- ❌ Uso comercial no autorizado (venden servicios basados en el código)
- ❌ Redistribución del software (ofrecen descargas modificadas)
- ❌ Eliminación de avisos de copyright
- ❌ Competencia comercial (producto similar comercial)

**Reporta a:** salvadorpalmarodriguez@gmail.com

---

## 🤝 Estrategia de Vigilancia Comunitaria

**¿Por qué está el script público?**

1. **Escalabilidad** - Miles de usuarios monitoreando vs. solo el autor
2. **Disuasión** - Los infractores saben que están siendo vigilados
3. **Transparencia** - Demuestra compromiso con la licencia open source
4. **Compromiso comunitario** - La comunidad se siente parte del proyecto

**¿Es legal?**

✅ **SÍ** - Los forks públicos en GitHub son información pública
- Cualquiera puede verlos desde la interfaz web
- El script solo automatiza algo ya accesible
- No viola ningún ToS de GitHub

**¿Funciona?**

✅ **SÍ** - Casos de éxito:
- **Redis** - Detectó forks comerciales no autorizados
- **MongoDB** - Cambió licencia por uso comercial sin permiso
- **Elasticsearch** - Identificó competidores usando su código

---

## 📊 Información Técnica del Script

### Cómo funciona `monitor_forks.sh`:

1. **Consulta API de GitHub:**
   ```bash
   gh api "repos/USUARIO/REPO/forks?per_page=100"
   ```
   - Usa GitHub CLI para autenticación
   - Obtiene hasta 100 forks por llamada
   - Devuelve JSON con metadata de cada fork

2. **Procesa JSON con jq:**
   ```bash
   jq -r '.[] | "Usuario: \(.owner.login)\n..."'
   ```
   - Extrae información relevante
   - Formatea salida legible
   - Filtra campos importantes

3. **Muestra información:**
   - Usuario propietario del fork
   - URL directa al fork
   - Fecha de creación
   - Métricas (stars, forks secundarios)
   - Descripción del repositorio

### Extensión futura:

El script puede extenderse para:
- ✅ Notificaciones automáticas por email
- ✅ Análisis de código en forks (buscar copyright eliminado)
- ✅ Monitoreo de releases en forks
- ✅ Verificación de licencia en forks
- ✅ Integración con webhooks de GitHub

---

## 🔐 Privacidad y Ética

**¿Esto es espionaje?**

❌ **NO** - Es monitoreo de información **pública**:
- GitHub hace los forks visibles públicamente
- No se accede a información privada
- No se hackea ni se usa ingeniería social
- Es equivalente a revisar la página de "Forks" en GitHub

**¿Viola la privacidad?**

❌ **NO** - Los usuarios que forkean aceptan:
- Que su fork sea público (si su repo es público)
- Que GitHub muestre "forked from X"
- Que aparezcan en el "network graph"
- GitHub Terms of Service cláusula 3.3

**¿Es ético?**

✅ **SÍ** - Es una práctica estándar:
- Protege la propiedad intelectual
- Asegura cumplimiento de licencia
- Previene uso comercial no autorizado
- Es transparente (el script es público)

---

## 📝 Licencia de los Scripts

Todos los scripts en esta carpeta están bajo la misma licencia que el proyecto principal:

**Copyright © 2025 Salvador Palma Rodríguez**

- ✅ Uso personal y educativo permitido
- ✅ Modificación para uso propio permitido
- ❌ Uso comercial prohibido sin autorización
- ❌ Redistribución prohibida

---

## 📞 Contacto

**Preguntas sobre los scripts:**
salvadorpalmarodriguez@gmail.com

**Reportar violaciones de licencia:**
salvadorpalmarodriguez@gmail.com

---

✅ Gracias por ayudar a proteger el proyecto Enola Server
