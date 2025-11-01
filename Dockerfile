FROM node:20-alpine

RUN apk add --no-cache netcat-openbsd \
    && npm install -g y-sweet
WORKDIR /app/data
EXPOSE 8080

# Allow the storage backend to be configured at runtime. By default, we keep
# the original behaviour of persisting data to the container filesystem, but
# docker-compose can override this to point at MinIO/S3.
ENV Y_SWEET_STORAGE_PATH=/app/data

CMD ["sh", "-c", "y-sweet serve --host 0.0.0.0 \"${Y_SWEET_STORAGE_PATH}\""]
