# Stage0 Runbook System

<img src="./runbook.png" alt="Runbook" width="30%">

A simple way to organize your automation scripts, manage quality, and make them easy to find and use across your DevOps team. Document manual processes, automated scripts, or mix both—all in version-controlled markdown files. Implemented as a [micro-service api](https://github.com/agile-learning-institute/stage0_runbook_api), with a [single-page web app](https://github.com/agile-learning-institute/stage0_runbook_spa) UI and soon to be a [MCP Server](https://github.com/agile-learning-institute/stage0_runbook_api/issues/6) so you can integrate managed automations into LLM work flows.

## Quick Look Around

Want to see it in action? Download [docker-compose.yaml](./docker-compose.yaml) and run:

```bash
docker compose up -d
```

Then open [http://localhost:8084](http://localhost:8084) in your browser. There are a couple example runbooks to explore. When you're done looking around, you can shutdown the service with 

```bash
docker compose down
```

## What Are Runbooks?

Runbooks are markdown files that organize your operational procedures. Each runbook can contain:
- **Documentation** - What it does and when to use it
- **Scripts** - Your automation code (bash, Python, etc.)
- **Requirements** - Environment variables, files, or permissions needed
- **History** - Automatic log of who ran it and when

You can write runbooks for fully automated scripts, document manual procedures, or combine both—the runbook just provides structure and makes everything easy to find and securely execute.

## Quick Start

1. **Create a runbook repository** from the [template](https://github.com/agile-learning-institute/stage0_runbook_template)

2. **Add your runbooks** as markdown files in the `runbooks/` directory

3. **Package and deploy** using the included Dockerfile and docker-compose.yaml

That's it. See [SRE.md](./SRE.md) for customization options like adding CLI tools (AWS, GitHub, etc.) to your container.

## Need More Details?

- **Technical setup and customization**: [SRE.md](./SRE.md)
- **Runbook format specification**: [Runbook Format](https://github.com/agile-learning-institute/stage0_runbook_api/blob/main/RUNBOOK.md)
- **API documentation**: http://localhost:8083/docs/explorer.html (when running)

## License

See [LICENSE](./LICENSE) file for license information.
