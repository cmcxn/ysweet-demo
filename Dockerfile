FROM node:20-alpine

RUN apk add --no-cache netcat-openbsd \
    && npm install -g y-sweet
WORKDIR /app/data
EXPOSE 8080
CMD ["y-sweet", "serve", "/app/data"]
