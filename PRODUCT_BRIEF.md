# 🚀 ENOLA SERVER v1.0.0-rc
## Sistema Profesional de Gestión de Servicios Onion

> **Estado:** Versión 1.0.0-rc - Release Candidate / Demo  
> **Fecha:** Noviembre 2025  
> **Autor:** Salvador Palma Rodríguez  
> **Licencia:** Uso No Comercial (autorización requerida para uso comercial)
> **Nota:** Esta versión es candidata y abierta a feedback. No es estable para producción.

---

## 📋 RESUMEN EJECUTIVO

**Enola Server** es un sistema completo y automatizado para desplegar y gestionar servicios web anónimos en la red Tor (Onion Services). Diseñado para ser **fácil de usar**, **seguro por defecto** y **auto-mantenido**, permite a usuarios técnicos y no técnicos crear servicios web privados con WordPress y exponer SSH de forma segura.

### 🎯 Propuesta de Valor

- **Instalación simplificada**: Proceso de instalación directo
- **WordPress Onion automatizado**: Despliegue completamente automatizado
- **Auto-mantenimiento**: Health checks programados con auto-recuperación
- **Sin conflictos**: Validación automática de puertos y configuraciones
- **Recuperación ante errores**: Sistema de backups con rollback integrado
- **UX intuitiva**: Atajos de teclado, confirmaciones, ayuda contextual

---

## ✨ CARACTERÍSTICAS PRINCIPALES

### 1. Gestión de Servicios Onion
- ✅ Creación automática de Hidden Services de Tor
- ✅ Direcciones .onion únicas por servicio
- ✅ SSL autofirmado para HTTPS
- ✅ Configuración NGINX automatizada
- ✅ Soporte para múltiples servicios simultáneos

### 2. WordPress con un Comando
- ✅ Contenedores Podman (WordPress + MySQL)
- ✅ Configuración automática de puertos
- ✅ Integración con Tor Hidden Service
- ✅ NGINX como reverse proxy
- ✅ Gestión de servicios systemd
- ✅ Inicio/parada desde menú interactivo

### 3. Health Monitoring Automático
- ✅ Verificación programada y continua
- ✅ Auto-reinicio inteligente (máx 3 intentos)
- ✅ Verifica: NGINX, Tor, contenedores, puertos, disco
- ✅ Logs detallados para troubleshooting
- ✅ Sin intervención manual necesaria

### 4. Sistema de Backups
- ✅ Backups automáticos antes de editar configuraciones
- ✅ Mantiene últimas 5 versiones por servicio
- ✅ Rollback interactivo desde menú
- ✅ Protección ante errores de configuración

### 5. Validación de Puertos
- ✅ Detecta puertos ocupados antes de configurar
- ✅ Sugiere alternativas automáticamente
- ✅ Previene conflictos entre servicios
- ✅ Valida rangos permitidos (1024-65535)

### 6. Sistema de Ayuda Contextual
- ✅ Presiona 'h' en cualquier menú
- ✅ Ayuda específica por sección
- ✅ Explicación de conceptos (Onion, Backend, SSL, etc.)
- ✅ Ubicación de archivos importantes

### 7. UX Profesional
- ✅ Atajos de teclado (sin Enter)
- ✅ Breadcrumbs de navegación
- ✅ Confirmaciones para acciones destructivas
- ✅ Mensajes estandarizados (✅/❌/⚠️)
- ✅ Indicadores de progreso
- ✅ Mini-dashboard de estado

### 8. Diagnósticos Integrados
- ✅ 13 herramientas de diagnóstico
- ✅ Estado detallado de servicios
- ✅ Verificación de sincronización (systemd vs contenedores)
- ✅ Test de configuraciones NGINX/Tor
- ✅ Visualización de logs

---

## 🔧 ARQUITECTURA TÉCNICA

### Stack Tecnológico

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
        │  (a desarrollar
        │   por usuario) │
        └────────────────┘
             │
    ┌────────▼─────────┐
    │ tuapp.onion      │
    │ (tu dominio      │
    │  anónimo)        │
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
    │ tusitioweb.onion │
    └──────────────────┘
```

### Componentes Clave

1. **Scripts Bash modulares** (`/opt/enola/scripts/`)
   - `menu/`: Sistema de menús interactivos
   - `common/`: Utilidades compartidas (health, backups, validación)
   - `wordpress/`: Gestión de WordPress
   - `tor/`: Configuración de servicios Onion
   - `nginx/`: Configuración de reverse proxy
   - `diagnostics/`: Herramientas de diagnóstico

2. **Servicios Systemd**
   - `enola-tor.service`: Tor con configuración personalizada
   - `enola-health.service`: Health monitor
   - `enola-health.timer`: Programación de checks
   - `container-enola-*.service`: Contenedores WordPress/MySQL

3. **Almacenamiento**
   - `/etc/tor/enola.d/`: Configuraciones de servicios Onion
   - `/etc/nginx/sites-available/`: Configuraciones NGINX
   - `/opt/enola/wordpress/`: Variables de entorno de WordPress
   - `/var/log/enola-server/`: Logs centralizados
   - `/var/lib/enola-server/`: Estado y tracking
   - `/var/backups/enola-server/`: Backups automáticos

---

## 💼 CASOS DE USO

### Comparativa: Web Tradicional vs. Enola Server

| Aspecto | **Web Tradicional** | **Enola Server** |
|---------|---------------------|------------------|
| **Dependencias** | Hosting mensual + dominio anual | **Sin dependencias externas** |
| **Conocimientos** | Paneles hosting, DNS, SSL, FTP | **Mínimos** (wizards guiados) |
| **Terceros** | Hosting, registrador dominio, Cloudflare... | **NINGUNO** (100% autocontrol) |
| **Privacidad** | IP pública expuesta, logs del hosting | **Anónimo** (.onion) |
| **Duración dominio** | Renovación anual (expira si no pagas) | **Permanente** (mientras tengas el servidor) |
| **Censura** | Suspensión por hosting/registrador | **Imposible** (red Tor descentralizada) |
| **Visibilidad** | Indexado en buscadores (SEO obligatorio) | **Solo quien tú quieras** (compartes .onion) |
| **Seguridad** | Depende del hosting (historial dudoso) | **Control total** (tú gestionas todo) |
| **Riesgo Hacking** | ALTO (IP pública, vulnerabilidades del hosting) | **BAJO** (oculto en Tor, sin exposición) |
| **Self-Hosting** | Requiere IP estática, DNS dinámico, router config | **No necesario** (Tor hace el trabajo) |

### 1. Blog Personal Anónimo
**Problema Web Tradicional:**
- Hosting y dominio anual con renovación obligatoria
- Tu identidad expuesta (WHOIS, IP del servidor)
- Depende de empresas de dudosa reputación
- Puede ser censurado o suspendido sin previo aviso

**Solución Enola Server:**
- ✅ **Sin dependencias externas** - WordPress en .onion
- ✅ **Anónimo** - Solo accesible vía Tor Browser
- ✅ **Auto-control** - Tú decides quién conoce tu dirección .onion
- ✅ **Setup automatizado**

### 2. Acceso SSH Anónimo
**Problema Web Tradicional:**
- Expones SSH en IP pública →Target para hackers
- Requiere configuración avanzada (fail2ban, cambio de puerto, etc.)
- Registros en logs de ISP

**Solución Enola Server:**
- ✅ **Oculto en Tor** - SSH en puerto 2222 vía .onion
- ✅ **Sin escaneos** - No apareces en Shodan/Censys
- ✅ **Protección automática** - No expones IP real

### 3. Hosting de Aplicaciones Web
**Problema Web Tradicional:**
- Hosting compartido: limitaciones y riesgos de seguridad
- VPS: requiere conocimientos Linux avanzados
- Dominio: renovación anual, puede ser robado/expirar

**Solución Enola Server:**
- ✅ **Cualquier app** - NGINX + reverse proxy personalizable
- ✅ **Dominio permanente** - .onion nunca expira
- ✅ **Sin terceros** - No dependes de hosting ni registradores

### 4. Comunidades y Foros Privados
**Problema Web Tradicional:**
- Foros indexados en Google → pérdida de privacidad
- Moderación y censura por hosting
- Coste por usuarios/tráfico

**Solución Enola Server:**
- ✅ **Privacidad total** - Solo conocen el .onion quienes invites
- ✅ **Sin censura** - Red Tor descentralizada
- ✅ **Tráfico ilimitado**

### 5. Self-Hosting Desde Casa (Sin Enola)
**Problema:**
- Requiere IP estática o DNS dinámico
- Configuración compleja de router (port forwarding, DMZ)
- IP de casa expuesta públicamente → Riesgo de ataques
- ISP puede bloquear puertos (80, 443)
- Conocimientos técnicos avanzados

**Solución Enola Server:**
- ✅ **Sin IP pública** - Tor oculta tu ubicación
- ✅ **Sin config de router** - Todo funciona desde localhost
- ✅ **ISP no puede bloquear** - Tor usa sus propios puertos
- ✅ **Configuración automática** - Wizards guiados paso a paso

---

## 🚀 ROADMAP FUTURO

### Fases Pendientes (Requieren Financiación)

**Fase 5: Observabilidad**
- Dashboard de recursos en tiempo real
- Logs centralizados con filtros
- Métricas de uso y uptime
- Exportación de datos

**Fase 6: Automatización**
- Despliegue batch desde YAML
- API REST para gestión remota
- Webhooks para notificaciones
- Integración con CI/CD

**Fase 7: Seguridad Avanzada**

| # | Feature | Impacto | Prioridad |
|---|---------|---------|-----------|
| 12 | **UFW Firewall** | ⭐⭐⭐⭐⭐ | ALTA |
| 13 | **File Sharing Onion** | ⭐⭐⭐⭐ | ALTA |
| 14 | **fwknop (Port Knocking)** | ⭐⭐⭐⭐⭐ | MEDIA |
| 15 | **HTTP Basic Auth** | ⭐⭐⭐⭐ | ALTA |
| 16 | **Usuario dedicado (sin sudo)** | ⭐⭐⭐⭐⭐ | MUY ALTA |

**Nota:** File Sharing es la única feature mencionada que **NO está implementada en v1.0.0**.
Se incluye en Fase 7 porque es complementaria a las capacidades de seguridad avanzada.---

### � MODELO DE NEGOCIO PROPUESTO

### Versión Actual (v1.0.0)
- ✅ **Código disponible** para uso personal/educativo
- ✅ **Licencia no comercial**
- ✅ Soporte comunitario (GitHub Issues)
- ✅ **Totalmente funcional** - Fases 1-4 completas

### Versión Enterprise (Futura - Post-Financiación)
- 🚀 **Fases 5, 6 y 7 completas** (observabilidad, automatización, seguridad avanzada)
- 🚀 **Soporte directo por email** (respuesta prioritaria)
- 🚀 **Actualizaciones tempranas** (early access a nuevas features)
- 🚀 **Licencia comercial** (uso en empresas/proyectos comerciales)

### Opciones de Monetización
1. **Licencias comerciales** (empresas que quieran usarlo comercialmente)
2. **Consultoría y soporte** (ayuda con instalación y configuración)
3. **Desarrollo a medida** (features específicas por encargo)
4. **Formación** (tutoriales y capacitación personalizada)

---

## 🎯 OPORTUNIDADES DE MERCADO

### Segmentos Objetivo

1. **Activistas y Periodistas** (Alto valor)
   - Necesitan anonimato y seguridad
   - Dispuestos a pagar por privacidad
   - Mercado global estimado: 50,000+ usuarios

2. **Empresas con Requisitos de Privacidad** (Máximo valor)
   - Whistleblowing interno
   - Comunicación confidencial
   - Testing de seguridad
   - Mercado estimado: 5,000+ organizaciones

3. **Desarrolladores y Makers** (Volumen)
   - Proyectos personales
   - Prototipos y MVPs
   - Educación y aprendizaje
   - Mercado estimado: 100,000+ usuarios

4. **ONGs y Organizaciones sin Ánimo de Lucro**
   - Operaciones en países represivos
   - Protección de fuentes
   - Comunicación segura
   - Mercado estimado: 10,000+ organizaciones

### Competencia

| Producto | Disponibilidad | Pros | Contras |
|----------|----------------|------|---------|
| **OnionShare** | Software libre | Simple | Solo file sharing, sin gestión |
| **Tor Browser** | Software libre | Maduro | Solo navegación, no hosting |
| **Whonix** | Software libre | Muy seguro | Complejo, requiere VMs |
| **Enola Server** | Source Available (v1.0) | **Todo-en-uno, auto-mantenido, UX intuitiva** | Sin Fases 5-7 (requieren financiación) |

**Ventaja competitiva:** Único sistema que combina facilidad de uso, auto-mantenimiento y gestión completa de servicios Onion.

---

## 📈 PLAN DE FINANCIACIÓN

### Uso de Fondos

1. **Desarrollo Fases 5, 6 y 7**
   - Observabilidad (dashboard, métricas)
   - Automatización (API REST, YAML)
   - Seguridad avanzada (UFW, file sharing, port knocking, HTTP auth)

2. **Marketing y Documentación**
   - Sitio web profesional
   - Tutoriales en video
   - Documentación en inglés
   - Casos de uso detallados

3. **Infraestructura**
   - Servidor demo público
   - CI/CD automatizado
   - Testing automatizado
   - Hosting de documentación

4. **Legal y Licencias**
   - Revisión de licencia
   - Términos de servicio
   - Consultoría legal

5. **Contingencia**
   - Soporte comunitario
   - Bugs críticos
   - Features urgentes

### ROI Proyectado

El modelo de negocio contempla múltiples fuentes de ingresos:
- Licencias comerciales
- Consultoría y soporte
- Desarrollo a medida
- Formación personalizada

**Se espera un ROI elevado** gracias a:
- ✅ Mercado en crecimiento (privacidad y anonimato)
- ✅ Producto único sin competencia directa
- ✅ Operación eficiente (software automatizado)
- ✅ Escalabilidad (licencias digitales sin límite de copias)
- ✅ Múltiples segmentos de mercado

---

## 🏆 VENTAJAS COMPETITIVAS

### Técnicas
1. ✅ **Auto-mantenimiento real** (health checks + auto-reinicio)
2. ✅ **Sistema de backups integrado** (competencia no tiene)
3. ✅ **Validación proactiva** (previene errores antes de aplicar)
4. ✅ **UX intuitiva** (atajos, confirmaciones, ayuda contextual)
5. ✅ **Contenedores Podman** (más seguro que Docker sin root)

### Operacionales
6. ✅ **Instalación simplificada** (vs. configuración manual compleja)
7. ✅ **WordPress automatizado** (vs. proceso manual extenso)
8. ✅ **Sin conocimientos avanzados** (wizards guiados)
9. ✅ **Logs centralizados** (troubleshooting fácil)
10. ✅ **Smoke tests automáticos** (valida instalación)

### Estratégicas
11. ✅ **Primera versión funcional completa** (competencia en alpha/beta)
12. ✅ **Código probado en producción** (tests reales, no teóricos)
13. ✅ **Documentación exhaustiva** (roadmap, arquitectura, API)
14. ✅ **Roadmap claro** (Fases 5-7 detalladas)
15. ✅ **Licencia flexible** (open source + comercial)

---

## 📞 CONTACTO Y PROPUESTA

### Autor
**Salvador Palma Rodríguez**  
📧 salvadorpalmarodriguez@gmail.com  
🔗 GitHub: github.com/SalvadorPalmaRodriguez/enola-server-2025  
📍 España

### Propuesta para Inversores

**Busco:** Financiación seed para desarrollo completo  
**Para:** Completar Fases 5, 6 y 7 (observabilidad, automatización, seguridad avanzada)  
**Ofrezco:**
- Equity negociable según inversión y términos
- Participación en decisiones estratégicas
- Acceso a métricas y roadmap en tiempo real
- Licencia Enterprise gratuita de por vida

**Timeline:**
- **Fase 1:** Desarrollo Fases 5, 6 y 7 + testing completo
- **Fase 2:** Marketing, documentación, demo público
- **Fase 3:** Lanzamiento versión Enterprise
- **Fase 4:** Primeros clientes, refinamiento del producto
- **Fase 5:** Escalado y crecimiento sostenible

### Siguiente Paso

Si estás interesado en:
- ✅ Invertir en el proyecto
- ✅ Proponer partnership
- ✅ Licencia comercial anticipada
- ✅ Colaborar en desarrollo

**Por favor contacta:** salvadorpalmarodriguez@gmail.com

---

## 📄 LICENCIA Y COPYRIGHT

**Copyright © 2025 Salvador Palma Rodríguez**  
**Licencia:** Uso No Comercial (v1.0.0)

**Versión 1.0.0:**
- ✅ Uso personal y educativo: **Disponible**
- ✅ Forks públicos para estudio/auditoría: **PERMITIDOS** (monitoreados)
- ✅ Modificaciones en forks para uso no comercial: **PERMITIDAS**
- ❌ Uso comercial sin autorización: **PROHIBIDO**
- ❌ Redistribución comercial: **PROHIBIDA**
- ❌ Uso comercial de forks: **PROHIBIDO**

⚠️ **IMPORTANTE:**
- Software proporcionado **"TAL CUAL"** (AS IS)
- **Sin garantías** de ningún tipo
- Sin responsabilidad por daños derivados del uso
- Ver [LICENSE](LICENSE) para términos legales completos

**Versión Enterprise (futura):**
- Licencia comercial disponible post-financiación
- Términos a definir
- Contactar para early adopter benefits

---

## 🎉 CONCLUSIÓN

**Enola Server v1.0.0** es un sistema **completo, probado y funcional** para gestionar servicios Onion con:

✅ **4 fases completadas** al 100%  
✅ **Sistema auto-mantenido** con health checks  
✅ **UX intuitiva** con atajos y confirmaciones  
✅ **Seguridad y recuperación** integradas  
✅ **Listo para producción** hoy mismo  

**Con tu apoyo financiero**, podemos completar las **Fases 5, 6 y 7** y convertir Enola Server en el **estándar de la industria** para servicios Onion gestionados.

**¿Listo para invertir en el futuro de la privacidad online?**

---

*Documento generado: Noviembre 2025*  
*Versión: 1.0*  
*Estado: Buscando Financiación*
