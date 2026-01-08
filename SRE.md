# Stage0 Runbook System - SRE Documentation

Technical documentation for Site Reliability Engineers deploying and customizing the Stage0 Runbook System.

## Table of Contents

- [Container Architecture](#container-architecture)
- [Extending Base Images](#extending-base-images)
- [Packaging Runbooks](#packaging-runbooks)
- [Custom Dockerfiles](#custom-dockerfiles)
- [Production Deployment Guide](#production-deployment-guide)
- [Production Configuration](#production-configuration)
- [Monitoring and Metrics](#monitoring-and-metrics)
- [Authentication and Authorization](#authentication-and-authorization)
- [Troubleshooting](#troubleshooting)

## Container Architecture

The Stage0 Runbook System uses containerized components:

- **Base API Image**: `ghcr.io/agile-learning-institute/stage0_runbook_api:latest`
- **Base SPA Image**: `ghcr.io/agile-learning-institute/stage0_runbook_spa:latest`
- **Extended API Image**: `ghcr.io/agile-learning-institute/stage0_runbook_api:extended` (includes Docker CLI and GitHub CLI)

### Base Image Contents

The base `stage0_runbook_api` image includes:
- Python 3.12 and pipenv
- zsh (required for runbook scripts)
- The runbook runner utility
- Flask API server with Gunicorn
- Prometheus metrics endpoint

The base `stage0_runbook_spa` image includes:
- Nginx web server
- Built Vue.js application
- API proxy configuration

## Extending Base Images

For runbooks that need additional tools (like Docker CLI, GitHub CLI, AWS CLI, etc.), you can extend the base image. This is especially useful when you want to package approved tools with your runbook execution environment.

### Using the Extended Image

An extended image is available that includes Docker CLI and GitHub CLI:

```yaml
services:
  api:
    image: ghcr.io/agile-learning-institute/stage0_runbook_api:extended
    # ... rest of configuration
```

This image is useful for runbooks that need to:
- Build and push Docker images
- Interact with GitHub repositories
- Use Docker-in-Docker capabilities

**Note**: When using Docker CLI, you'll need to mount the Docker socket:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

### Creating Custom Extended Images

You can create your own extended Dockerfile based on your specific needs. Here are common patterns:

#### Pattern 1: Add Single Tool

```dockerfile
FROM ghcr.io/agile-learning-institute/stage0_runbook_api:latest

# Add your custom tool
RUN apt-get update && \
    apt-get install -y --no-install-recommends your-tool && \
    rm -rf /var/lib/apt/lists/*

# Or install from a package manager
RUN curl -fsSL https://your-tool-installer.sh | sh
```

#### Pattern 2: Add Multiple Tools

```dockerfile
FROM ghcr.io/agile-learning-institute/stage0_runbook_api:latest

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        tool1 \
        tool2 \
        tool3 && \
    rm -rf /var/lib/apt/lists/*

# Install tools from other sources
RUN curl -fsSL https://tool-installer.sh | sh
```

#### Pattern 3: Extend the Extended Image

```dockerfile
FROM ghcr.io/agile-learning-institute/stage0_runbook_api:extended

# Add additional tools beyond Docker CLI and GitHub CLI
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        awscli \
        terraform && \
    rm -rf /var/lib/apt/lists/*
```

### Example: AWS CLI Extension

```dockerfile
FROM ghcr.io/agile-learning-institute/stage0_runbook_api:latest

# Install AWS CLI v2
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        unzip && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws && \
    rm -rf /var/lib/apt/lists/*

# Verify installation
RUN aws --version
```

### Example: Terraform Extension

```dockerfile
FROM ghcr.io/agile-learning-institute/stage0_runbook_api:latest

# Install Terraform
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        gnupg \
        software-properties-common && \
    curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - && \
    apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" && \
    apt-get update && \
    apt-get install -y terraform && \
    rm -rf /var/lib/apt/lists/*

# Verify installation
RUN terraform version
```

## Packaging Runbooks

You can package a collection of verified runbooks directly into a container image. This is useful for:
- Creating approved runbook collections
- Distributing runbooks without external volume mounts
- Ensuring runbook version consistency
- Creating immutable runbook execution environments

### Basic Runbook Packaging

Create a Dockerfile that packages runbooks:

```dockerfile
FROM ghcr.io/agile-learning-institute/stage0_runbook_api:latest

# Create directory for runbooks
RUN mkdir -p /opt/stage0/runbooks

# Copy runbooks folder into the container
# Assumes runbooks are in ./runbooks/ relative to build context
COPY runbooks/ /opt/stage0/runbooks/

# Set working directory to runbooks location for convenience
WORKDIR /opt/stage0/runbooks
```

Build and use:

```bash
# Build the image with runbooks
docker build -f Dockerfile.with-runbooks -t my-runbooks:latest .

# Run a packaged runbook
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e GITHUB_TOKEN=$GITHUB_TOKEN \
    my-runbooks:latest \
    runbook execute --runbook /opt/stage0/runbooks/my-runbook.md
```

### Packaging with Tools

Combine tool extensions with runbook packaging:

```dockerfile
FROM ghcr.io/agile-learning-institute/stage0_runbook_api:extended

# Create directory for runbooks
RUN mkdir -p /opt/stage0/runbooks

# Copy runbooks
COPY runbooks/ /opt/stage0/runbooks/

# Set working directory
WORKDIR /opt/stage0/runbooks
```

This gives you:
- Docker CLI and GitHub CLI (from extended base)
- Your packaged runbooks
- All in one immutable image

### Using Packaged Runbooks in Docker Compose

When using packaged runbooks, you don't need volume mounts:

```yaml
services:
  api:
    image: my-runbooks:latest
    environment:
      RUNBOOKS_DIR: /opt/stage0/runbooks
    command: runbook serve --runbooks-dir /opt/stage0/runbooks --port 8083
    # No volume mount needed - runbooks are in the image
```

## Custom Dockerfiles

The Stage0 Runbook API repository includes example Dockerfiles in the `samples/` directory:

### Dockerfile.extended

Extends the base image with Docker CLI and GitHub CLI. Useful for runbooks that need to interact with container registries and GitHub.

**Location**: `samples/Dockerfile.extended`

**Usage**:
```bash
docker build -f samples/Dockerfile.extended -t my-stage0-runner:extended .
```

### Dockerfile.with-runbooks

Packages a collection of runbooks into the container. Useful for creating immutable runbook execution environments.

**Location**: `samples/Dockerfile.with-runbooks`

**Usage**:
```bash
# Create runbooks directory
mkdir -p runbooks
cp my-runbook1.md my-runbook2.md runbooks/

# Build image
docker build -f samples/Dockerfile.with-runbooks -t my-runbooks:latest .
```

### Dockerfile.extended-with-runbooks

Combines both approaches: tools (Docker CLI, GitHub CLI) and packaged runbooks.

**Location**: `samples/Dockerfile.extended-with-runbooks`

**Usage**:
```bash
docker build -f samples/Dockerfile.extended-with-runbooks -t my-runbooks:extended .
```

## Production Deployment Guide

This guide covers deploying the stage0_runbook_api to production environments.

### Prerequisites

- Docker and Docker Compose (or Kubernetes)
- Reverse proxy (nginx, Traefik, etc.) for TLS termination
- Identity provider configured for JWT token issuance
- Secret management system (for storing JWT secrets)
- Monitoring and logging infrastructure

### Deployment Options

#### Option 1: Docker Compose (Single Instance)

Best for: Small to medium deployments, single-server setups

**docker-compose.prod.yaml**:
```yaml
services:
  api:
    image: ghcr.io/agile-learning-institute/stage0_runbook_api:latest
    restart: always
    ports:
      - "127.0.0.1:8083:8083"  # Only expose to localhost, use reverse proxy
    environment:
      # Required Configuration
      API_PORT: 8083
      RUNBOOKS_DIR: /workspace/runbooks
      ENABLE_LOGIN: "false"  # MUST be false in production
      JWT_SECRET: "${JWT_SECRET}"  # From secrets manager
      JWT_ISSUER: "your-identity-provider"
      JWT_AUDIENCE: "runbook-api-production"
      
      # Recommended Configuration
      LOGGING_LEVEL: "WARNING"
      SCRIPT_TIMEOUT_SECONDS: "600"
      MAX_OUTPUT_SIZE_BYTES: "10485760"
      RATE_LIMIT_ENABLED: "true"
      RATE_LIMIT_PER_MINUTE: "60"
      RATE_LIMIT_EXECUTE_PER_MINUTE: "10"
      RATE_LIMIT_STORAGE_BACKEND: "memory"  # Use "redis" for multi-instance
      
      # Optional: Redis for distributed rate limiting
      # REDIS_URL: "redis://redis:6379/0"
    volumes:
      - ./runbooks:/workspace/runbooks:ro  # Read-only mount
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8083/metrics"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # Optional: Redis for distributed rate limiting
  # redis:
  #   image: redis:7-alpine
  #   restart: always
  #   volumes:
  #     - redis-data:/data
  #   command: redis-server --appendonly yes

# volumes:
#   redis-data:
```

**Deployment Steps**:
1. Create runbooks directory: `mkdir -p runbooks`
2. Copy runbooks to the directory
3. Set environment variables (use secrets manager):
   ```bash
   export JWT_SECRET=$(openssl rand -hex 32)
   export JWT_ISSUER="your-idp"
   export JWT_AUDIENCE="runbook-api"
   ```
4. Start services: `docker-compose -f docker-compose.prod.yaml up -d`
5. Verify health: `curl http://localhost:8083/metrics`

#### Option 2: Docker Compose with Load Balancer (Multi-Instance)

Best for: High availability, horizontal scaling

**docker-compose.prod.yaml**:
```yaml
services:
  api:
    image: ghcr.io/agile-learning-institute/stage0_runbook_api:latest
    restart: always
    deploy:
      replicas: 3  # Run 3 instances
      resources:
        limits:
          cpus: '2'
          memory: 2G
    environment:
      API_PORT: 8083
      RUNBOOKS_DIR: /workspace/runbooks
      ENABLE_LOGIN: "false"
      JWT_SECRET: "${JWT_SECRET}"
      JWT_ISSUER: "your-identity-provider"
      JWT_AUDIENCE: "runbook-api-production"
      RATE_LIMIT_ENABLED: "true"
      RATE_LIMIT_STORAGE_BACKEND: "redis"  # Required for multi-instance
      REDIS_URL: "redis://redis:6379/0"
    volumes:
      - ./runbooks:/workspace/runbooks:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8083/metrics"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    restart: always
    volumes:
      - redis-data:/data
    command: redis-server --appendonly yes
    deploy:
      resources:
        limits:
          memory: 512M

  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "443:443"
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro  # TLS certificates
    depends_on:
      - api

volumes:
  redis-data:
```

**nginx.conf** (reverse proxy configuration):
```nginx
upstream api_backend {
    least_conn;
    server api:8083 max_fails=3 fail_timeout=30s;
    # Add more instances if using multiple containers
}

server {
    listen 80;
    server_name runbook-api.example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name runbook-api.example.com;

    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        proxy_pass http://api_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 600s;  # Match script timeout
    }

    # Metrics endpoint (restrict access)
    location /metrics {
        allow 10.0.0.0/8;  # Internal network only
        deny all;
        proxy_pass http://api_backend;
    }
}
```

#### Option 3: Kubernetes Deployment

Best for: Cloud-native deployments, orchestrated environments

**k8s/deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stage0-runbook-api
  namespace: runbooks
spec:
  replicas: 3
  selector:
    matchLabels:
      app: stage0-runbook-api
  template:
    metadata:
      labels:
        app: stage0-runbook-api
    spec:
      containers:
      - name: api
        image: ghcr.io/agile-learning-institute/stage0_runbook_api:latest
        ports:
        - containerPort: 8083
        env:
        - name: API_PORT
          value: "8083"
        - name: RUNBOOKS_DIR
          value: "/workspace/runbooks"
        - name: ENABLE_LOGIN
          value: "false"
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: runbook-secrets
              key: jwt-secret
        - name: JWT_ISSUER
          value: "your-identity-provider"
        - name: JWT_AUDIENCE
          value: "runbook-api-production"
        - name: RATE_LIMIT_ENABLED
          value: "true"
        - name: RATE_LIMIT_STORAGE_BACKEND
          value: "redis"
        - name: REDIS_URL
          value: "redis://redis-service:6379/0"
        volumeMounts:
        - name: runbooks
          mountPath: /workspace/runbooks
          readOnly: true
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2"
        livenessProbe:
          httpGet:
            path: /metrics
            port: 8083
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /metrics
            port: 8083
          initialDelaySeconds: 10
          periodSeconds: 10
      volumes:
      - name: runbooks
        configMap:
          name: runbooks-config
---
apiVersion: v1
kind: Service
metadata:
  name: stage0-runbook-api
  namespace: runbooks
spec:
  selector:
    app: stage0-runbook-api
  ports:
  - port: 80
    targetPort: 8083
  type: ClusterIP
```

### Configuration Reference

#### Required Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `JWT_SECRET` | Strong secret for JWT signing (MUST change from default) | `openssl rand -hex 32` |
| `JWT_ISSUER` | Expected JWT issuer claim | `your-identity-provider` |
| `JWT_AUDIENCE` | Expected JWT audience claim | `runbook-api-production` |
| `ENABLE_LOGIN` | MUST be `false` in production | `false` |

#### Recommended Configuration

| Variable | Default | Production Recommendation |
|----------|---------|---------------------------|
| `LOGGING_LEVEL` | `INFO` | `WARNING` or `ERROR` |
| `RATE_LIMIT_ENABLED` | `true` | `true` |
| `RATE_LIMIT_PER_MINUTE` | `60` | Adjust based on expected load |
| `RATE_LIMIT_EXECUTE_PER_MINUTE` | `10` | Adjust based on capacity |
| `RATE_LIMIT_STORAGE_BACKEND` | `memory` | `redis` for multi-instance |
| `SCRIPT_TIMEOUT_SECONDS` | `600` | Adjust based on runbook needs |
| `MAX_OUTPUT_SIZE_BYTES` | `10485760` | Adjust based on requirements |

#### Multi-Instance Configuration

For deployments with multiple API instances:
- **MUST** use `RATE_LIMIT_STORAGE_BACKEND=redis`
- **MUST** configure `REDIS_URL` pointing to a Redis instance
- **SHOULD** use shared storage for runbooks (read-only)
- **SHOULD** configure load balancer with health checks

### Monitoring Setup

#### Prometheus Metrics

The API exposes Prometheus metrics at `/metrics`. Configure Prometheus to scrape:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'stage0-runbook-api'
    scrape_interval: 15s
    static_configs:
      - targets: ['api:8083']
    metrics_path: '/metrics'
    # Optional: Add authentication
    # bearer_token: 'your-token'
```

**Key Metrics to Monitor**:
- `flask_http_request_total` - Total HTTP requests by method, status, endpoint
- `flask_http_request_duration_seconds` - Request duration histogram
- `flask_exceptions_total` - Exception counts by type
- `gunicorn_workers` - Number of worker processes
- `gunicorn_requests_total` - Total requests processed

#### Grafana Dashboard

Create a Grafana dashboard with panels for:
- Request rate (requests/second)
- Error rate (4xx, 5xx responses)
- Response time (p50, p95, p99)
- Active workers
- Rate limit hits
- Script execution duration

#### Alerting Rules

**Prometheus Alert Rules** (`alerts.yml`):
```yaml
groups:
  - name: stage0_runbook_api
    rules:
      - alert: HighErrorRate
        expr: rate(flask_http_request_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        annotations:
          summary: "High error rate detected"
          
      - alert: HighResponseTime
        expr: histogram_quantile(0.95, flask_http_request_duration_seconds_bucket) > 2
        for: 5m
        annotations:
          summary: "95th percentile response time > 2s"
          
      - alert: ServiceDown
        expr: up{job="stage0-runbook-api"} == 0
        for: 1m
        annotations:
          summary: "API service is down"
          
      - alert: HighRateLimitHits
        expr: rate(flask_http_request_total{status="429"}[5m]) > 10
        for: 5m
        annotations:
          summary: "High rate limit hits detected"
```

#### Log Aggregation

**Recommended Setup**:
- Use Docker logging driver or log forwarder (Fluentd, Fluent Bit)
- Send logs to centralized system (ELK, Loki, CloudWatch, etc.)
- Parse structured logs for:
  - Authentication failures
  - RBAC failures
  - Script execution failures
  - Rate limit hits

**Log Patterns to Monitor**:
- `RBAC failure` - Unauthorized access attempts
- `Script execution timed out` - Resource exhaustion
- `Invalid environment variable name` - Input validation failures
- `Rate limit exceeded` - DoS attempts

#### Health Checks

**Endpoint**: `GET /metrics` or `GET /api/runbooks`

**Health Check Script**:
```bash
#!/bin/bash
# healthcheck.sh
API_URL="${API_URL:-http://localhost:8083}"

# Check metrics endpoint
if curl -f -s "${API_URL}/metrics" > /dev/null; then
    echo "OK: Metrics endpoint healthy"
    exit 0
else
    echo "FAIL: Metrics endpoint unhealthy"
    exit 1
fi
```

### Load Balancing

When deploying multiple instances:

1. **Use a load balancer** (nginx, Traefik, AWS ALB, etc.)
2. **Configure health checks** to remove unhealthy instances
3. **Use session affinity** if needed (though API is stateless)
4. **Distribute rate limiting** using Redis backend
5. **Monitor per-instance metrics** to detect issues

### Backup and Recovery

**Runbooks**:
- Runbooks are stored in the `RUNBOOKS_DIR` directory
- **Backup regularly** using your standard backup procedures
- Consider version control (Git) for runbooks
- Test restore procedures

**History**:
- Execution history is stored in runbook files
- History is appended, so backups capture incremental changes
- Consider moving to database storage for high-volume deployments

### Performance Tuning

**Gunicorn Workers**:
- Default: 2 workers
- Recommended: `(2 × CPU cores) + 1`
- Adjust based on I/O vs CPU-bound workload

**Resource Limits**:
- Set appropriate CPU and memory limits
- Monitor actual usage and adjust
- Leave headroom for traffic spikes

**Rate Limiting**:
- Start with defaults (60 req/min, 10 exec/min)
- Monitor rate limit hits
- Adjust based on actual usage patterns

## Production Configuration

### Environment Variables

#### API Service

| Variable | Default | Description |
|----------|---------|-------------|
| `API_PORT` | `8083` | Port for the API server |
| `RUNBOOKS_DIR` | `./samples/runbooks` | Directory containing runbooks |
| `ENABLE_LOGIN` | `false` | Enable development login endpoint |
| `LOGGING_LEVEL` | `INFO` | Python logging level |
| `JWT_SECRET` | `dev-secret-change-me` | JWT signing secret (MUST be changed in production) |
| `JWT_ALGORITHM` | `HS256` | JWT algorithm |
| `JWT_ISSUER` | `dev-idp` | JWT issuer claim |
| `JWT_AUDIENCE` | `dev-api` | JWT audience claim |
| `JWT_TTL_MINUTES` | `480` | JWT token lifetime in minutes |

**Production Recommendations**:
- Set `ENABLE_LOGIN=false` to disable development login
- Use a strong, randomly generated `JWT_SECRET`
- Configure `JWT_ISSUER` and `JWT_AUDIENCE` to match your identity provider
- Set `LOGGING_LEVEL=WARNING` or `ERROR` to reduce log volume

#### SPA Service

| Variable | Default | Description |
|----------|---------|-------------|
| `API_HOST` | `api` | Hostname of the API server |
| `API_PORT` | `8083` | Port of the API server |

### Security Considerations

1. **JWT Configuration**: Never use default JWT secrets in production
2. **Network Security**: Use reverse proxy with TLS termination
3. **Access Control**: Configure proper RBAC with Required Claims in runbooks
4. **Volume Mounts**: Use read-only mounts for runbooks when possible
5. **Resource Limits**: Set appropriate CPU and memory limits

### Example Production docker-compose.yaml

```yaml
services:
  api:
    image: ghcr.io/agile-learning-institute/stage0_runbook_api:latest
    restart: always
    ports:
      - "127.0.0.1:8083:8083"  # Only expose to localhost
    environment:
      API_PORT: 8083
      RUNBOOKS_DIR: /workspace/runbooks
      ENABLE_LOGIN: "false"
      LOGGING_LEVEL: "WARNING"
      JWT_SECRET: "${JWT_SECRET}"  # From environment or secrets manager
      JWT_ISSUER: "your-idp"
      JWT_AUDIENCE: "runbook-api"
    volumes:
      - ./runbooks:/workspace/runbooks:ro
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8083/api/runbooks"]
      interval: 30s
      timeout: 10s
      retries: 3

  spa:
    image: ghcr.io/agile-learning-institute/stage0_runbook_spa:latest
    restart: always
    ports:
      - "127.0.0.1:8084:80"  # Only expose to localhost
    environment:
      API_HOST: api
      API_PORT: 8083
    depends_on:
      api:
        condition: service_healthy
```

## Monitoring and Metrics

### Prometheus Metrics

The API exposes Prometheus metrics at `/metrics`:

```bash
curl http://localhost:8083/metrics
```

Standard metrics include:
- HTTP request counts by method, status, and endpoint
- Request duration histograms
- Active connections
- Worker process information

### Health Checks

Health check endpoint: `GET /api/runbooks`

Returns 200 if the service is healthy, otherwise returns an error.

### Logging

Logs are written to stdout/stderr and can be collected by your logging infrastructure. Log format:

```
YYYY-MM-DD HH:MM:SS - LEVEL - logger_name - message
```

Recommended log aggregation:
- Docker logging driver
- Fluentd/Fluent Bit
- ELK stack
- CloudWatch/Stackdriver

## Authentication and Authorization

### Development Mode

When `ENABLE_LOGIN=true`, a development login endpoint is available at `/dev-login`:

```bash
curl -X POST http://localhost:8083/dev-login \
  -H "Content-Type: application/json" \
  -d '{"subject": "dev-user", "roles": ["developer", "admin"]}'
```

**Never enable this in production!**

### Production Authentication

1. Configure your identity provider to issue JWTs with:
   - `iss` (issuer) matching `JWT_ISSUER`
   - `aud` (audience) matching `JWT_AUDIENCE`
   - `roles` claim with user roles

2. Users authenticate through your identity provider

3. The SPA includes the JWT in the `Authorization: Bearer <token>` header

4. The API validates the JWT and extracts claims

### Role-Based Access Control (RBAC)

Runbooks can specify required claims in the "Required Claims" section:

```yaml
# Required Claims
```yaml
roles: developer, admin, devops
```
```

When a user attempts to execute or validate a runbook:
1. The API extracts required claims from the runbook
2. Validates that the user's token contains the required claims
3. If validation fails, returns 403 Forbidden and logs the attempt to the runbook history
4. If validation succeeds, proceeds with execution

### Example Required Claims

```yaml
# Required Claims
```yaml
roles: developer, admin
environment: production
team: platform-engineering
```
```

The token must have:
- `roles` containing at least one of: `developer` or `admin`
- `environment` equal to `production`
- `team` equal to `platform-engineering`

## Troubleshooting

### API Container Won't Start

**Check logs**:
```bash
docker logs stage0_runbook_api
```

**Common issues**:
- Port already in use: Change `API_PORT` or stop conflicting service
- Invalid `RUNBOOKS_DIR`: Ensure directory exists and is readable
- Permission denied: Check volume mount permissions

### Runbooks Not Appearing

**Verify volume mount**:
```bash
docker exec stage0_runbook_api ls -la /workspace/runbooks
```

**Check API response**:
```bash
curl http://localhost:8083/api/runbooks
```

### Authentication Failures

**Check JWT configuration**:
- Verify `JWT_SECRET` matches between API and identity provider
- Verify `JWT_ISSUER` and `JWT_AUDIENCE` are correct
- Check token expiration

**Validate token**:
```bash
# Decode JWT (without verification)
echo "YOUR_JWT_TOKEN" | cut -d. -f2 | base64 -d | jq
```

### Execution Failures

**Check runbook history**:
- Execution history is appended to the runbook file
- Includes stdout, stderr, return code, and timestamps
- RBAC failures are also logged to history

**Common execution errors**:
- Missing environment variables: Check "Environment Requirements" section
- Missing files: Check "File System Requirements" section
- Permission denied: Check file permissions in volume mounts
- Tool not found: Extend image to include required tools

### Performance Issues

**Monitor metrics**:
```bash
curl http://localhost:8083/metrics | grep http_request
```

**Adjust workers**:
The default Gunicorn configuration uses 2 workers. Adjust in Dockerfile:

```dockerfile
CMD exec gunicorn --bind 0.0.0.0:${API_PORT} --workers 4 --worker-class gevent src.server:app
```

**Resource limits**:
Set appropriate CPU and memory limits in docker-compose.yaml.

## Additional Resources

- [API Repository](https://github.com/agile-learning-institute/stage0_runbook_api)
- [SPA Repository](https://github.com/agile-learning-institute/stage0_runbook_spa)
- [Runbook Format Specification](https://github.com/agile-learning-institute/stage0_runbook_api/blob/main/RUNBOOK.md)
- [API Explorer](http://localhost:8083/docs/explorer.html) (when API is running)

