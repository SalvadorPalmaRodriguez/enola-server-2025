# 🔑 Configuración SSH Cliente - Enola Server

> Guía para conectarse a servicios SSH via Tor Hidden Service

---

## 📋 Requisitos Previos

**En el cliente:**
```bash
sudo apt install tor torsocks openssh-client
```

**En el servidor:**
- Enola Server instalado y configurado
- SSH Hidden Service creado mediante el menú

---

## 1️⃣ Generar Claves SSH en el Cliente

### Generar par de claves

```bash
# Ejecutar SIN sudo (como usuario normal)
ssh-keygen -t ed25519 -f ~/.ssh/enola_client_key -C "usuario@cliente"
```

**Salida esperada:**
```
Generating public/private ed25519 key pair.
Enter passphrase (empty for no passphrase): [ENTER o contraseña]
Enter same passphrase again: [ENTER o contraseña]
Your identification has been saved in /home/usuario/.ssh/enola_client_key
Your public key has been saved in /home/usuario/.ssh/enola_client_key.pub
```

### Verificar claves generadas

```bash
ls -la ~/.ssh/enola_client_key*

# Deberías ver:
# ~/.ssh/enola_client_key      (clave PRIVADA - nunca compartir)
# ~/.ssh/enola_client_key.pub  (clave PÚBLICA - esta se copia al servidor)
```

---

## 2️⃣ Copiar Clave Pública al Servidor

### Formato de la clave pública

La clave pública es una línea de texto que comienza con el tipo de clave:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAbCd3fGhIjKlMnOpQrStUvWxYz... usuario@cliente
```

### Opción A: Copia Manual (Recomendada)

**1. En el CLIENTE, mostrar la clave pública:**

```bash
cat ~/.ssh/enola_client_key.pub
```

**Copiar toda la línea** (es una sola línea larga).

**2. En el SERVIDOR, añadir la clave:**

```bash
# Acceder al servidor (por consola física o método seguro)
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Añadir la clave al archivo authorized_keys
nano ~/.ssh/authorized_keys
# Pegar la clave pública al final del archivo
# Guardar (Ctrl+O) y salir (Ctrl+X)

# Ajustar permisos
chmod 600 ~/.ssh/authorized_keys
chown $USER:$USER ~/.ssh/authorized_keys
```

**3. Verificar:**

```bash
# Ver claves autorizadas
cat ~/.ssh/authorized_keys
```

### Opción B: Script Rápido (Servidor)

Si tienes acceso directo al servidor:

```bash
# Reemplaza CLAVE_PUBLICA_COMPLETA con tu clave
echo 'ssh-ed25519 AAAAC3Nz... usuario@cliente' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Recargar SSH
sudo systemctl reload sshd
```

---

## 3️⃣ Conectarse via Tor

### Obtener dirección .onion del servidor

**En el servidor, ejecutar:**

```bash
sudo enola-server
→ Gestión de Servicios Tor → Listar servicios
```

**Buscar el servicio SSH** y copiar la dirección `.onion`, ejemplo:
```
abcdef1234567890ghijklmnopqrstuvwxyz1234567890abcdefghijk.onion
```

### Conectarse desde el cliente

```bash
# Sintaxis:
torsocks ssh -i ~/.ssh/enola_client_key -p 22 usuario@DIRECCION.onion

# Ejemplo:
torsocks ssh -i ~/.ssh/enola_client_key -p 22 miusuario@abcdef1234567890ghijklmnopqrstuvwxyz1234567890abcdefghijk.onion
```

**Parámetros:**
- `torsocks`: Enruta la conexión a través de Tor
- `-i ~/.ssh/enola_client_key`: Especifica la clave privada
- `-p 22`: Puerto SSH (usualmente 22)
- `usuario@DIRECCION.onion`: Usuario y dirección del Hidden Service

### Primera conexión

La primera vez verás:

```
The authenticity of host 'abcd...onion' can't be established.
ED25519 key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
```

Escribe `yes` y presiona Enter.

---

## 4️⃣ Configuración Persistente (Opcional)

Para no tener que escribir el comando completo cada vez:

### Crear alias en `.bashrc` o `.zshrc`

```bash
echo "alias ssh-enola='torsocks ssh -i ~/.ssh/enola_client_key -p 22 miusuario@abcd...onion'" >> ~/.bashrc
source ~/.bashrc

# Ahora puedes conectarte con:
ssh-enola
```

### Configurar `~/.ssh/config`

```bash
nano ~/.ssh/config
```

Añadir:

```
Host enola-server
    HostName abcdef1234567890ghijklmnopqrstuvwxyz1234567890abcdefghijk.onion
    User miusuario
    Port 22
    IdentityFile ~/.ssh/enola_client_key
    ProxyCommand nc -X 5 -x localhost:9050 %h %p
```

**Conectar con:**

```bash
ssh enola-server
```

---

## 5️⃣ Troubleshooting

### Error: "Connection refused"

```bash
# Verificar que Tor está corriendo en el cliente
systemctl status tor

# Verificar puerto SOCKS de Tor
ss -tulpn | grep 9050
```

### Error: "Permission denied (publickey)"

```bash
# Verificar que la clave pública está en el servidor
cat ~/.ssh/authorized_keys | grep "usuario@cliente"

# Verificar permisos en el servidor
ls -la ~/.ssh/authorized_keys
# Debe ser: -rw------- (600)
```

### Error: "Bad owner or permissions"

```bash
# Corregir permisos en el cliente
chmod 700 ~/.ssh
chmod 600 ~/.ssh/enola_client_key
chmod 644 ~/.ssh/enola_client_key.pub
```

### Verbose mode (debug)

```bash
torsocks ssh -vvv -i ~/.ssh/enola_client_key -p 22 usuario@DIRECCION.onion
```

---

## 6️⃣ Seguridad

### ✅ Buenas Prácticas

- ✅ Usar claves ED25519 (más seguras que RSA 2048)
- ✅ Proteger clave privada con passphrase
- ✅ Nunca compartir la clave privada (`.ssh/enola_client_key`)
- ✅ Mantener permisos correctos (700 para `.ssh`, 600 para claves)
- ✅ Usar diferentes claves para diferentes servidores

### ❌ NO Hacer

- ❌ NO ejecutar ssh-keygen con sudo
- ❌ NO copiar la clave privada por email/chat
- ❌ NO usar claves sin passphrase en entornos de producción
- ❌ NO reutilizar claves de otros servicios

---

## 7️⃣ Comandos de Referencia Rápida

```bash
# CLIENTE: Generar claves
ssh-keygen -t ed25519 -f ~/.ssh/enola_client_key

# CLIENTE: Ver clave pública
cat ~/.ssh/enola_client_key.pub

# SERVIDOR: Añadir clave pública
echo 'ssh-ed25519 AAAAC3Nz... user@client' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# CLIENTE: Conectar via Tor
torsocks ssh -i ~/.ssh/enola_client_key -p 22 usuario@DIRECCION.onion

# SERVIDOR: Ver servicios Onion
sudo enola-server
→ Gestión de Servicios Tor → Listar servicios

# SERVIDOR: Ver logs SSH
sudo journalctl -u sshd -f
```

---

## 📞 Soporte

**¿Problemas?**
- Abre un [Issue en GitHub](https://github.com/SalvadorPalmaRodriguez/enola-server-2025/issues)
- Revisa la [documentación completa](https://github.com/SalvadorPalmaRodriguez/enola-server-2025)

---

**Copyright © 2025 Salvador Palma Rodríguez**  
**Licencia:** Source Available - No Comercial
