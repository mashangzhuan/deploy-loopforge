# LoopForge Sandbox Deployment Script

[中文](README.md) | English

One command on a Linux server: generate a custom sandbox image → build and push it to GHCR via GitHub Actions → pull the image → clone and start the LoopForge platform.

## Features

- **On-demand Dockerfile generation**: choose the Agent CLIs and dev toolchains baked into the image instead of relying on a fixed template
- **China-based mirrors**: apt via USTC, Node.js via Tsinghua, npm/pnpm via npmmirror, pip via Tsinghua, Cargo/Go via USTC and goproxy.cn
- **Automated build**: push the Dockerfile and workflow to a GitHub repository, trigger Actions, and push `ghcr.io/<owner>/<repo>/loopforge-sandbox:latest`
- **Automated deployment**: log in to GHCR with a classic PAT, clone the official LoopForge repository and run `start.sh`
- **Bilingual**: all prompts, logs and errors are available in Chinese and English

## Prerequisites

- A Linux server (Bash) with `git`, `docker` (including the `docker compose` plugin), `curl`, `jq` and `sudo`
- A GitHub repository used for the image build, with `main` as its default branch and GitHub Actions enabled
- Two tokens:

| Token | Type and scopes | Purpose |
|---|---|---|
| Repository PAT | Fine-grained: Contents, Workflows and Actions read/write; or classic: `repo`, `workflow` | Upload the Dockerfile/workflow, trigger and query Actions |
| GHCR PAT | Classic: `read:packages` | Log in to GHCR and pull the private image |

> The build pushes the image with the built-in `GITHUB_TOKEN`; you do not need to create or configure it manually.

## Quick start

Run interactively and follow the prompts for language, Agent CLIs, toolchains and tokens:

```bash
chmod +x deploy.sh
./deploy.sh
```

Non-interactive usage:

```bash
CLASSIC_PAT=ghp_xxx ./deploy.sh \
  --agents-cli "codebuddy codex dsh" \
  --dev-toolchains "python golang node pnpm" \
  --pat github_pat_xxx \
  --repo "owner/repo"
```

Positional arguments are also supported:

```bash
CLASSIC_PAT=ghp_xxx ./deploy.sh <repo PAT> <owner/repo>
```

## Options

| Option | Description | Default |
|---|---|---|
| `--agents-cli "..."` | Agent CLIs baked into the image, space or comma separated | `codebuddy codex claude-code dsh` |
| `--dev-toolchains "..."` | Dev toolchains baked into the image, space or comma separated | `python golang rust node pnpm` |
| `--pat <token>` | Repository PAT, fine-grained or classic | Required |
| `--repo <owner/repo>` | GitHub repository used for the build | Required |
| `--classic-pat <token>` | GHCR classic PAT | Required |
| `--lang <zh\|en>` | Output language | `zh` |
| `-h, --help` | Show help | — |

Agent CLIs: `codebuddy`, `codex`, `claude-code` (alias `claude`), `dsh`, `opencode`

Toolchains: `python`, `golang`, `rust`, `node`, `pnpm`

Selecting any Agent CLI or `pnpm` automatically adds `node`.

## Environment variables

| Variable | Description |
|---|---|
| `CLASSIC_PAT` | GHCR classic PAT, same as `--classic-pat` |
| `DEPLOY_LANG` | Output language, `zh` or `en` |
| `DOCKERFILE_CONTENT` | Override the generated Dockerfile content |
| `WORKFLOW_CONTENT` | Override the workflow content to upload |
| `LOOPFORGE_DIR` | LoopForge clone directory, default `/opt/loopforge` |
| `MIRROR` | Mirror URL passed to `start.sh` |
| `DEPLOY_INTERACTIVE` | Set to `1` to force interactive mode (for testing) |

## Workflow

1. Validate arguments and dependencies
2. Verify repository access
3. Generate the Dockerfile and upload it together with the workflow
4. Trigger the GitHub Actions build and poll for the result
5. Log in to GHCR with the classic PAT and pull the image
6. Clone the official LoopForge repository
7. Inspect image and sandbox settings in `compose.yaml`
8. Install and start LoopForge
9. Print container status and the access URL (`http://<server-ip>:8090`)

## Notes

- The script pulls the custom image but **does not modify** `compose.yaml` to make the platform use it; confirm the integration approach for your LoopForge version.
- Never write tokens into the script, `.npmrc`, Dockerfiles or Git history.
- If GHCR login fails with `unauthorized` for an organization repository, change the `docker login` username to your personal GitHub username.
