# syntax=docker/dockerfile:1

# Stage 1 — build the static site with Hexo
FROM --platform=linux/amd64 node:20 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npx hexo clean && npx hexo generate

# Stage 2 — serve the static files with static-web-server
FROM ghcr.io/static-web-server/static-web-server:2
ENV SERVER_ROOT=/public
ENV SERVER_PORT=80
COPY --from=builder /app/public /public
EXPOSE 80
