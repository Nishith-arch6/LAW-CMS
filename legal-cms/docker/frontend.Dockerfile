FROM flutter:3.22-sdk AS build

WORKDIR /app
COPY frontend/ .
RUN flutter pub get && flutter build web --release

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
