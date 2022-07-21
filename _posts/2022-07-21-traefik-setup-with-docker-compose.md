---
title: Traefik setup with Docker Compose
date: 2022-07-21 11:10:00 +0000
categories: [Homelab, Docker]
tags: [homelab, docker, docker compose, traefik]
---

Setup traefik using Docker Compose.
This is my own setup of using Traefik together with Docker Compose.
This guide is created for copy/pasting to your own machine.


![Traefik architecture](https://doc.traefik.io/traefik/assets/img/traefik-architecture.png)
Check out Traefik [here](https://doc.traefik.io/traefik/).

## Traefik setup

Setup files:

```bash
touch acme.json
chmod 0600 acme.json
mkdir file-providers
touch traefik.yaml

# Create logging directory for traefik
mkdir /var/log/traefik

# Create proxy network for all services
# I like to also name the network bridge that docker creates for this
docker network create \
  -o "com.docker.network.bridge.name"="br-proxy" \
  proxy
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

### Local whitelist middleware
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

### Security Headers middleware
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

### Compression middleware
The purpose of this middleware is to compress all responses
```yaml
http:
  middlewares:
    compression:
      compress: {}
```
{: file="file-providers/compression.yaml" }

## Service setup
To proxy your services through Traefik, some setup needs to be done.

### Docker
If you want to proxy a different container on the same host as your traefik container, add these labels to your compose file:
```yaml
...
services:
  service1:
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=proxy"
      # Add this if traefik needs to listen to a specific port
      # - "traefik.http.services.service1-svc.loadbalancer.server.port=8080"
      - "traefik.http.routers.service1.rule=Host(`service1.mydomain.com`)"
      - "traefik.http.routers.service1.entryPoints=websecure"
      # Add your middlewares here
      # - "traefik.http.routers.service1.middlewares=local-whitelist@file"
```
{: file="docker-compose.yaml" }

### Service on local network
If you want to proxy a service on your local network, add a new file under the file-providers with the following contents:

Prometheus example:
```yaml
http:
  # Add the prometheus service:
  services:
    prometheus-svc: # <- This is a custom name
      loadBalancer:
        servers:
          - url: "http://<ip/hostname of prometheus server>:9090/"

  # Add the router that connects this service to a domain name:
  routers:
    prometheus-router: # <- This is a custom name
      rule: "Host(`prometheus.mydomain.com`)"
      service: "prometheus-svc@file"
      middlewares:
        - local-whitelist
      entrypoints:
        - websecure
```
{: file="file-providers/prometheus-proxy.yaml" }
