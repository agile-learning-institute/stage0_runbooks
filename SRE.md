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

### Creating Custom Extended Images

For examples of how to extend the base image with additional tools (AWS CLI, Terraform, etc.), see the [Template Repository](https://github.com/agile-learning-institute/stage0_runbook_template). Sample Dockerfiles are provided in the `samples/` directory:

- `Dockerfile.basic` - Basic runbook packaging
- `Dockerfile.aws` - AWS CLI extension example
- `Dockerfile.terraform` - Terraform extension example
- `Dockerfile.extended` - Multiple tools extension example

See the [Template README](https://github.com/agile-learning-institute/stage0_runbook_template/blob/main/README.md#customizing-your-dockerfile) for details.

## Packaging Runbooks

You can package a collection of verified runbooks directly into a container image. This is useful for creating approved runbook collections, distributing runbooks without external volume mounts, ensuring version consistency, and creating immutable runbook execution environments.

For detailed examples and sample Dockerfiles, see the [Template Repository](https://github.com/agile-learning-institute/stage0_runbook_template). The `samples/` directory includes:

- **[Dockerfile.basic](https://github.com/agile-learning-institute/stage0_runbook_template/blob/main/samples/Dockerfile.basic)** - Basic runbook packaging
- **[Dockerfile.aws](https://github.com/agile-learning-institute/stage0_runbook_template/blob/main/samples/Dockerfile.aws)** - AWS CLI + runbooks
- **[Dockerfile.terraform](https://github.com/agile-learning-institute/stage0_runbook_template/blob/main/samples/Dockerfile.terraform)** - Terraform + runbooks
- **[Dockerfile.extended](https://github.com/agile-learning-institute/stage0_runbook_template/blob/main/samples/Dockerfile.extended)** - Multiple tools + runbooks

All sample Dockerfiles include runbook packaging. See the [Template README](https://github.com/agile-learning-institute/stage0_runbook_template/blob/main/README.md#packaging-runbooks) for details on packaging runbooks and using them with docker-compose.

## Production Deployment Guide

This guide covers deploying the stage0_runbook_api to production environments.

### Prerequisites

- Docker and Docker Compose (or Kubernetes)
- Reverse proxy (nginx, Traefik, etc.) for TLS termination
- Identity provider configured for JWT token issuance
- Secret management system (for storing JWT secrets)
- Monitoring and logging infrastructure

### Deployment Options

Sample deployment configurations are provided in the `samples/` directory:

#### Option 1: Docker Compose (Single Instance)

Best for: Small to medium deployments, single-server setups

See [samples/docker-compose.prod.single.yaml](samples/docker-compose.prod.single.yaml) for a complete single-instance production configuration.

**Quick Start**:
1. Create runbooks directory: `mkdir -p runbooks`
2. Copy runbooks to the directory
3. Set environment variables (use secrets manager):
   ```bash
   export JWT_SECRET=$(openssl rand -hex 32)
   export JWT_ISSUER="your-idp"
   export JWT_AUDIENCE="runbook-api"
   ```
4. Start services: `docker-compose -f samples/docker-compose.prod.single.yaml up -d`
5. Verify health: `curl http://localhost:8083/metrics`

#### Option 2: Docker Compose with Load Balancer (Multi-Instance)

Best for: High availability, horizontal scaling

See [samples/docker-compose.prod.multi.yaml](samples/docker-compose.prod.multi.yaml) for multi-instance configuration with Redis and nginx load balancer. The required [nginx.conf](samples/nginx.conf) is also provided.

**Requirements**:
- Redis for distributed rate limiting (`RATE_LIMIT_STORAGE_BACKEND=redis`)
- nginx reverse proxy with TLS certificates
- Shared storage for runbooks (read-only)

#### Option 3: Kubernetes Deployment

Best for: Cloud-native deployments, orchestrated environments

See [samples/k8s/deployment.yaml](samples/k8s/deployment.yaml) for a complete Kubernetes deployment configuration with Service, health checks, and resource limits.

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

Sample monitoring configurations are provided in the `samples/` directory:

#### Prometheus Metrics

The API exposes Prometheus metrics at `/metrics`. See [samples/prometheus.yml](samples/prometheus.yml) for Prometheus scrape configuration.

**Key Metrics to Monitor**:
- `flask_http_request_total` - Total HTTP requests by method, status, endpoint
- `flask_http_request_duration_seconds` - Request duration histogram
- `flask_exceptions_total` - Exception counts by type
- `gunicorn_workers` - Number of worker processes
- `gunicorn_requests_total` - Total requests processed

#### Grafana Dashboard

A sample Grafana dashboard configuration is available at [samples/grafana-dashboard.json](samples/grafana-dashboard.json). It includes panels for:
- Request rate (requests/second)
- Error rate (4xx, 5xx responses)
- Response time (p95)
- Active workers
- Rate limit hits

#### Alerting Rules

See [samples/prometheus-alerts.yml](samples/prometheus-alerts.yml) for Prometheus alerting rules including:
- High error rate detection
- High response time alerts
- Service down detection
- Rate limit hit monitoring

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

**Endpoints**: `GET /metrics` or `GET /api/runbooks`

A health check script is available at [samples/healthcheck.sh](samples/healthcheck.sh) for automated health monitoring.

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

### Example Production Configuration

See [samples/docker-compose.prod.single.yaml](samples/docker-compose.prod.single.yaml) for a complete production docker-compose configuration including both API and SPA services.

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
roles: developer, admin, devops
```

When a user attempts to execute or validate a runbook:
1. The API extracts required claims from the runbook
2. Validates that the user's token contains the required claims
3. If validation fails, returns 403 Forbidden and logs the attempt to the runbook history
4. If validation succeeds, proceeds with execution

### Example Required Claims

```yaml
# Required Claims
roles: developer, admin
environment: production
team: platform-engineering
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

