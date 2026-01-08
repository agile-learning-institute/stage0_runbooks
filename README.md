# Stage0 Runbook System

A production-ready platform for creating, managing, and executing runbooks as code. The Stage0 Runbook System provides a web-based interface for your SRE team to automate operational procedures while maintaining full audit trails and access controls.

## What is Stage0 Runbooks?

Stage0 Runbooks transforms manual operational procedures into executable, version-controlled runbooks. Your team can:

- **Automate repetitive tasks** - Convert manual procedures into executable scripts
- **Maintain consistency** - Standardize operations across your organization
- **Track execution history** - Every runbook execution is automatically logged with full audit trails
- **Enforce access controls** - Role-based access control ensures only authorized personnel can execute sensitive runbooks
- **Version control operations** - Runbooks are markdown files that integrate with your existing Git workflows

### Key Benefits

✅ **Reduce human error** - Automated execution eliminates manual mistakes  
✅ **Improve compliance** - Complete audit trails for every operation  
✅ **Accelerate onboarding** - New team members can execute complex procedures immediately  
✅ **Standardize operations** - Consistent execution across environments  
✅ **Enable self-service** - Teams can safely execute approved runbooks independently  

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Network access to download container images from GitHub Container Registry

### Getting Started in 5 Minutes

1. **Download the docker-compose.yaml file**

   ```bash
   curl -O https://raw.githubusercontent.com/agile-learning-institute/stage0_runbooks/main/docker-compose.yaml
   ```

   Or clone the repository:
   ```bash
   git clone https://github.com/agile-learning-institute/stage0_runbooks.git
   cd stage0_runbooks
   ```

2. **Create a directory for your runbooks**

   ```bash
   mkdir -p runbooks
   ```

3. **Add your first runbook** (or use the example below)

   Create a file `runbooks/example.md`:
   ```markdown
   # Example Runbook

   # Documentation
   This is an example runbook that demonstrates the basic functionality.

   # Environment Requirements
   ```yaml
   MESSAGE: A message to display
   ```

   # File System Requirements
   ```yaml
   Input:
   Output:
   ```

   # Required Claims
   ```yaml
   roles: developer, admin
   ```

   # Script
   ```sh
   #! /bin/zsh
   echo "Running example runbook"
   echo "Message: ${MESSAGE:-not set}"
   ```

   # History
   ```

4. **Start the services**

   ```bash
   docker-compose up -d
   ```

5. **Access the web interface**

   Open your browser to: **http://localhost:8084**

   The API is available at: **http://localhost:8083**

### Stopping the Services

```bash
docker-compose down
```

## Using the Web Interface

Once the services are running:

1. Navigate to **http://localhost:8084** in your browser
2. You'll see a list of all available runbooks
3. Click on a runbook to view its details
4. Click "Execute" to run the runbook
5. The system will prompt for required environment variables
6. Execution results are displayed immediately
7. Execution history is automatically appended to the runbook

### Authentication

For development and testing, authentication is enabled by default. You can:

- Use the `/dev-login` endpoint to obtain a JWT token for API access
- In the web interface, authentication is handled automatically
- For production deployments, configure your identity provider (see [SRE.md](./SRE.md))

## What Are Runbooks?

Runbooks are markdown files that describe operational procedures. Each runbook contains:

- **Documentation** - Description of what the runbook does
- **Environment Requirements** - Variables that must be set before execution
- **File System Requirements** - Files or directories that must exist
- **Required Claims** - Access control requirements (roles, permissions)
- **Script** - The executable shell script that performs the operation
- **History** - Automatic log of all executions with timestamps and outputs

### Example Use Cases

- **Deployment procedures** - Automate application deployments
- **Database migrations** - Execute schema changes safely
- **Infrastructure provisioning** - Create resources consistently
- **Incident response** - Execute remediation procedures quickly
- **Compliance tasks** - Document and automate audit procedures
- **Backup and restore** - Standardize data protection procedures

## Architecture

The Stage0 Runbook System consists of two main components:

1. **API Server** (`stage0_runbook_api`) - RESTful API for runbook operations
   - Validates and executes runbooks
   - Manages access control and authentication
   - Provides metrics and health endpoints
   - Runs on port 8083

2. **Web Interface** (`stage0_runbook_spa`) - Modern single-page application
   - User-friendly interface for browsing and executing runbooks
   - Real-time execution monitoring
   - Markdown rendering for runbook documentation
   - Runs on port 8084

Both services run as Docker containers and can be easily integrated into your existing infrastructure.

## Configuration

### Environment Variables

The docker-compose.yaml file can be customized with the following environment variables:

**API Service:**
- `API_PORT` - Port for the API server (default: 8083)
- `RUNBOOKS_DIR` - Directory containing runbooks (default: /workspace/runbooks)
- `ENABLE_LOGIN` - Enable development login endpoint (default: "true")
- `LOGGING_LEVEL` - Logging level (default: "INFO")

**SPA Service:**
- `API_HOST` - Hostname of the API server (default: api)
- `API_PORT` - Port of the API server (default: 8083)

### Volume Mounts

The default configuration mounts `./runbooks` to `/workspace/runbooks` in the API container. This allows you to:

- Store runbooks on your host machine
- Version control runbooks with Git
- Edit runbooks directly (they are read-only in the container)

To use a different location, modify the volume mount in docker-compose.yaml:

```yaml
volumes:
  - /path/to/your/runbooks:/workspace/runbooks:ro
```

## Production Deployment

For production deployments, consider:

- **Security**: Disable `ENABLE_LOGIN` and configure proper JWT authentication
- **Persistence**: Use a volume mount or persistent storage for runbooks
- **Networking**: Configure reverse proxy and TLS termination
- **Monitoring**: Enable Prometheus metrics scraping from `/metrics`
- **Scaling**: Run multiple API instances behind a load balancer

See [SRE.md](./SRE.md) for detailed technical guidance on production deployments and customization.

## Support and Documentation

- **Technical Documentation**: See [SRE.md](./SRE.md) for detailed technical information
- **API Documentation**: Available at http://localhost:8083/docs/explorer.html when the API is running
- **Runbook Format**: See the [Runbook Format Specification](https://github.com/agile-learning-institute/stage0_runbook_api/blob/main/RUNBOOK.md)

## License

See [LICENSE](./LICENSE) file for license information.
