---
title: Traefik setup with Docker Compose
date: 2022-07-21 11:10:00 +0000
categories: [Homelab, Docker]
tags: [homelab, docker, docker compose, traefik]
---

My Traefik setup with Docker Compose

## Docker network
A docker network is required if you want to use multiple `docker-compose.yml` files.
I like to also name the network bridge that docker creates for this `br-proxy` (so it shows up in `ip a` with that name).

```bash
docker network create -o "com.docker.network.bridge.name"="br-proxy" proxy
```

## Traefik setup

Setup files:

```bash
touch acme.json
chmod 0600 acme.json
mkdir file-providers
touch traefik.yaml

# Create logging directory for traefik
mkdir /var/log/traefik
```

### docker-compose.yaml
Create your `docker-compose.yaml` file, with the following contents:

```yaml
version: '3'

services:
  traefik:
    image: traefik:v2.8
    container_name: traefik
    ports:
      - "80:80"
      - "443:443"
      - "8082:8082" # Prometheus metrics port
    # Setup your Let's Encrypt DNS challenge
    # environment:
    #   - "DO_AUTH_TOKEN="
    volumes:
      - ./traefik.yaml:/traefik.yaml
      - ./acme.json:/acme.json
      - ./file-providers:/file-providers
      - /var/log/traefik:/logs
      - /var/run/docker.sock:/var/run/docker.sock
    restart: always
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=proxy"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.mydomain.com`)"
      - "traefik.http.routers.dashboard.entryPoints=websecure"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.middlewares=local-whitelist@file"

networks:
  proxy:
    external: true
```
{: file="docker-compose.yaml" }

### traefik.yaml
```yaml
global:
  sendAnonymousUsage: false
  CheckNewVersion: true

log:
  level: INFO

accessLog:
  filePath: "/logs/access.log"
  format: json
  bufferingSize: 10

ping: {}
api:
  dashboard: true

metrics:
  prometheus:
    addRoutersLabels: true
    addEntryPointsLabels: true
    addServicesLabels: true
    entryPoint: metrics

providers:
  file:
    directory: /file-providers
  docker:
    endpoint: 'unix:///var/run/docker.sock'
    exposedbydefault: false

entryPoints:
  web:
    address: ':80'
    http:
      # Auto redirect to our https site
      redirections:
        entryPoint:
          to: websecure
          scheme: https

  websecure:
    address: ':443'
    http:
      middlewares:
        - security-headers@file
        - compression@file
      tls:
        certResolver: secure
        domains:
          - main: mydomain.com
            sans: ['*.mydomain.com']
  metrics:
    address: ':8082'
certificatesResolvers:
  secure:
    acme:
      email: you@mydomain.com
      storage: /acme.json
      dnsChallenge: # Setup your own DNS provider here, or use a different type of challenge
        provider: digitalocean
        delayBeforeCheck: 0

tls:
  options:
    default:
      minVersion: VersionTLS13
acme:
  domains:
    - main: '*.mydomain.com'
      sans:
        - mydomain.com
```
{: file="traefik.yaml" }


## Custom middleware
You might have noticed the `file-providers` directory, here we can specify dynamic configuration that do not need a restart from Traefik.

#### Local whitelist middleware
The purpose of this middleware is to allow only access from the local network:
```yaml
http:
  middlewares:
    local-whitelist:
      ipWhiteList:
        sourceRange:
          - 127.0.0.1/32
          - 10.0.0.1/24
          - 10.40.0.1/24
          - 10.50.0.1/24
```
{: file="file-providers/local-whitelist.yaml" }

#### Security Headers middleware
The purpose of this middleware is to add security headers to all responses.
```yaml
http:
  middlewares:
    security-headers:
      headers:
        frameDeny: false
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true
```
{: file="file-providers/security-headers.yaml" }

#### Compression middleware
The purpose of this middleware is to compress all responses
```yaml
http:
  middlewares:
    compression:
      compress: {}
```
{: file="file-providers/compression.yaml" }

## Service setup

### Docker

### Service on local network
