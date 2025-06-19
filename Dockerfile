FROM alpine:latest

ARG PB_VERSION=0.20.0

RUN apk add --no-cache \
    ca-certificates \
    unzip \
    wget \
    zip \
    zlib-dev \
    bash

# Download and unzip PocketBase
ADD https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip /tmp/pb.zip
RUN unzip /tmp/pb.zip -d /pb/ && \
    rm /tmp/pb.zip

# Copy custom extensions (if any)
COPY ./pb_hooks /pb/pb_hooks
COPY ./pb_migrations /pb/pb_migrations
COPY ./pb_public /pb/pb_public

# Copy startup script
COPY ./start.sh /pb/start.sh
RUN chmod +x /pb/start.sh

EXPOSE 8090

# Start PocketBase
CMD ["/pb/start.sh"]