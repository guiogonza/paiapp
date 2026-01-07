# 🚀 Instrucciones de Deployment

## 📍 Dónde ejecutar el script

El script `deploy.sh` se ejecuta desde **tu máquina local** (donde tienes el código del proyecto).

## 🔐 Requisitos de SSH

Necesitas tener acceso SSH configurado al VPS. Hay dos formas:

### Opción A: Con clave SSH (Recomendado)

1. **Generar clave SSH** (si no tienes):
   ```bash
   ssh-keygen -t rsa -b 4096
   ```

2. **Copiar clave al VPS**:
   ```bash
   ssh-copy-id root@82.208.21.130
   # O con el usuario que uses:
   ssh-copy-id usuario@82.208.21.130
   ```

3. **Probar conexión**:
   ```bash
   ssh root@82.208.21.130
   ```

### Opción B: Con contraseña

El script te pedirá la contraseña cuando sea necesario.

## 🚀 Ejecutar el Deployment

### Desde tu máquina local:

```bash
cd /Users/juanpablocuartas/Documents/Proyectos\ Flutter/pai_app

# Si el usuario es 'root' (por defecto):
./deploy.sh 82.208.21.130

# Si el usuario es otro (ej: 'ubuntu', 'admin', etc.):
./deploy.sh 82.208.21.130 ubuntu
```

## 📝 Qué hace el script:

1. ✅ Construye la imagen Docker localmente
2. ✅ La comprime y guarda como tar.gz
3. ✅ Se conecta al VPS vía SSH
4. ✅ Crea el directorio `/opt/pai-app` en el VPS
5. ✅ Copia los archivos necesarios
6. ✅ Carga la imagen Docker en el VPS
7. ✅ Ejecuta `docker-compose up -d`
8. ✅ Limpia archivos temporales

## 🔍 Verificar el Deployment

Después de ejecutar el script, verifica:

1. **En el VPS:**
   ```bash
   ssh root@82.208.21.130
   cd /opt/pai-app
   docker-compose ps
   docker-compose logs -f
   ```

2. **En tu navegador:**
   - Abre: `http://82.208.21.130`
   - Deberías ver la aplicación funcionando

## ❌ Si hay problemas

### Error: "Host key verification failed"
```bash
ssh-keyscan -H 82.208.21.130 >> ~/.ssh/known_hosts
```

### Error: "Permission denied"
- Verifica que el usuario tenga permisos SSH
- Prueba con otro usuario: `./deploy.sh 82.208.21.130 ubuntu`

### Error: "Connection refused"
- Verifica que el VPS esté encendido
- Verifica que el puerto 22 (SSH) esté abierto

## 📞 Comandos útiles

```bash
# Ver logs en tiempo real
ssh root@82.208.21.130 "cd /opt/pai-app && docker-compose logs -f"

# Reiniciar la aplicación
ssh root@82.208.21.130 "cd /opt/pai-app && docker-compose restart"

# Ver estado
ssh root@82.208.21.130 "cd /opt/pai-app && docker-compose ps"
```

