# LoopForge 沙箱部署脚本

[English](README_EN.md) | 中文

在 Linux 服务器上一键完成：生成自定义沙箱镜像 → 通过 GitHub Actions 构建并推送到 GHCR → 拉取镜像 → 克隆并启动 LoopForge 平台。

## 功能

- **按需生成 Dockerfile**：通过参数选择镜像内置的 Agent CLI 和开发工具链，不再依赖固定模板
- **工具链官方源 + 依赖国内镜像**：apt、Go、Rust、Node.js 等运行时从官方源下载；npm/pnpm、pip、Cargo、GOPROXY 等语言级依赖按所选语言配置国内镜像
- **自动构建**：将 Dockerfile 和 workflow 推送到指定 GitHub 仓库，触发 Actions 构建并推送 `ghcr.io/<owner>/<repo>/loopforge-sandbox:latest`
- **自动部署**：使用 Classic PAT 拉取镜像，克隆官方 LoopForge 仓库并执行 `start.sh`
- **中英双语**：所有提示、日志和报错均支持中文与英文
- **自动修复 git HTTPS**：检测到 `git-remote-https` 缺失时，自动通过 `opkg`/`apt`/`yum`/`apk` 安装 `git-http`

## 前提条件

- Linux 服务器（Bash 环境），已安装：`git`、`docker`（含 `docker compose` 插件）、`curl`、`jq`、`sudo`
- 一个用于构建镜像的 GitHub 仓库，默认分支为 `main`，且已启用 GitHub Actions
- 两个 Token：

| Token | 类型与权限 | 用途 |
|---|---|---|
| 仓库 PAT | Fine-grained：Contents、Workflows、Actions 的 Read and write；或 Classic：`repo`、`workflow` | 上传 Dockerfile/workflow、触发并查询 Actions |
| GHCR PAT | Classic：`read:packages` | 登录 GHCR 拉取私有镜像 |

> Actions 中推送镜像使用内置的 `GITHUB_TOKEN`，无需手动创建或配置。

## 快速开始

交互式运行，按提示输入语言、Agent CLI、工具链和 Token：

```bash
chmod +x deploy.sh
./deploy.sh
```

非交互运行：

```bash
CLASSIC_PAT=ghp_xxx ./deploy.sh \
  --agents-cli "codebuddy codex dsh" \
  --dev-toolchains "python golang node pnpm" \
  --pat github_pat_xxx \
  --repo "owner/repo"
```

也支持位置参数：

```bash
CLASSIC_PAT=ghp_xxx ./deploy.sh <仓库 PAT> <owner/repo>
```

## 参数

| 参数 | 说明 | 默认值 |
|---|---|---|
| `--agents-cli "..."` | 镜像内置的 Agent CLI，空格或逗号分隔 | `codebuddy codex claude-code dsh` |
| `--dev-toolchains "..."` | 镜像内置的开发工具链，空格或逗号分隔 | `python golang rust node pnpm` |
| `--pat <token>` | 仓库 PAT，Fine-grained 或 Classic 均可 | 无（必填） |
| `--repo <owner/repo>` | 用于构建的 GitHub 仓库 | 无（必填） |
| `--classic-pat <token>` | GHCR Classic PAT | 无（必填） |
| `--lang <zh\|en>` | 输出语言 | `zh` |
| `-h, --help` | 显示帮助 | — |

可选 Agent CLI：`codebuddy`、`codex`、`claude-code`（别名 `claude`）、`dsh`、`opencode`

可选工具链：`python`、`golang`、`rust`、`node`、`pnpm`

选择 Agent CLI 或 `pnpm` 时会自动补充 `node`。

## 环境变量

| 变量 | 说明 |
|---|---|
| `CLASSIC_PAT` | GHCR Classic PAT，等价于 `--classic-pat` |
| `DEPLOY_LANG` | 输出语言，`zh` 或 `en` |
| `DOCKERFILE_CONTENT` | 覆盖自动生成的 Dockerfile 内容 |
| `WORKFLOW_CONTENT` | 覆盖上传的 workflow 内容 |
| `LOOPFORGE_DIR` | LoopForge 克隆目录，默认 `/opt/loopforge` |
| `MIRROR` | 传给 `start.sh` 的镜像加速地址 |
| `DEPLOY_INTERACTIVE` | 设为 `1` 时强制进入交互模式（用于测试） |

## 执行流程

1. 校验参数和依赖
2. 验证仓库访问权限
3. 生成 Dockerfile 并连同 workflow 上传到仓库
4. 触发 GitHub Actions 构建并轮询结果
5. 使用 Classic PAT 登录 GHCR 并拉取镜像
6. 克隆官方 LoopForge 仓库
7. 检查 `compose.yaml` 中的镜像与沙箱配置
8. 安装并启动 LoopForge
9. 输出容器状态与访问地址（`http://<服务器IP>:8090`）

## 注意

- 脚本会拉取自定义镜像，但**不会自动修改** `compose.yaml` 让平台使用它；具体的接入方式需按当前 LoopForge 版本确认。
- 不要把 Token 写入脚本、`.npmrc`、Dockerfile 或提交到 Git 仓库。
- 组织仓库登录 GHCR 若报 `unauthorized`，可将 `docker login` 的用户名改为个人 GitHub 用户名。
