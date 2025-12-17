# Dockerfile para Flutter Web
FROM nginx:alpine

# Copiar los archivos compilados de Flutter web
COPY build/web /usr/share/nginx/html

# Exponer el puerto 80
EXPOSE 80

# Nginx ya está configurado por defecto para servir /usr/share/nginx/html

