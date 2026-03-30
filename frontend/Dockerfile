FROM nginx:1.29-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY docker-entrypoint.d/40-render-config.sh /docker-entrypoint.d/40-render-config.sh
COPY config.template.js /usr/share/nginx/html/config.template.js
COPY index.html /usr/share/nginx/html/index.html
COPY app.js /usr/share/nginx/html/app.js
COPY styles.css /usr/share/nginx/html/styles.css

RUN chmod +x /docker-entrypoint.d/40-render-config.sh

EXPOSE 80
