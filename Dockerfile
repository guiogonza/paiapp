# Multi-stage build para construir Flutter y servir con Nginx
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Copiar archivos necesarios para pub get
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copiar código fuente
COPY lib/ lib/
COPY assets/ assets/
COPY web/ web/

# Construir para web
RUN flutter build web --release

# Stage 2: Servir con Nginx
FROM nginx:stable-alpine

# Copiar build/web desde el stage anterior
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copiar configuración de nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
