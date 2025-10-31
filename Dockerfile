FROM node:20-alpine
RUN npm config set registry https://registry.npmmirror.com \
    && npm install -g y-sweet
WORKDIR /app/data
EXPOSE 8080
CMD ["y-sweet", "serve", "/app/data"]
