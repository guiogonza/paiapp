# ✅ Verificación del Deployment

## Comandos para verificar en Termius

### 1. Verificar que el contenedor esté corriendo

```bash
docker compose ps
```

**Debería mostrar:**
```
NAME      IMAGE           STATUS
pai-app   pai-app:latest  Up (healthy)
```

### 2. Ver logs (sin el ~ al final)

```bash
docker compose logs -f
```

Presiona `Ctrl+C` para salir de los logs.

### 3. Verificar que nginx esté respondiendo

```bash
curl http://localhost
```

Debería mostrar HTML de la aplicación Flutter.

### 4. Verificar desde fuera del VPS

Abre en tu navegador: **http://82.208.21.130**

## 🔍 Si el contenedor sigue reiniciándose

```bash
# Ver logs de error
docker compose logs --tail=100

# Verificar el contenedor
docker inspect pai-app

# Probar ejecutar nginx manualmente
docker exec pai-app nginx -t
```

## ✅ Si todo está bien

El contenedor debería estar en estado "Up" y la aplicación accesible en:
- **http://82.208.21.130**

