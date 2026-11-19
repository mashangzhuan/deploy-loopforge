#!/usr/bin/env bash
set -euo pipefail

ALLOWED_AGENTS="codebuddy codex claude-code dsh opencode"
ALLOWED_TOOLCHAINS="python golang rust node pnpm"
DEFAULT_AGENTS="codebuddy codex claude-code dsh"
DEFAULT_TOOLCHAINS="python golang rust node pnpm"

AGENTS_CLI="$DEFAULT_AGENTS"
DEV_TOOLCHAINS="$DEFAULT_TOOLCHAINS"
POSITIONAL=()
PAT_ARG=""
REPO_ARG=""
CLASSIC_PAT_ARG=""
LANG_CODE="${DEPLOY_LANG:-zh}"
LANG_SET=0
AGENTS_SET=0
TOOLCHAINS_SET=0
INTERACTIVE=0

if [ -t 0 ] || [ "${DEPLOY_INTERACTIVE:-}" = "1" ]; then
  INTERACTIVE=1
fi

if [ "$LANG_CODE" != "en" ]; then
  LANG_CODE="zh"
fi

declare -A MSG_ZH=(
  [usage_line]="用法: %s [选项] [<仓库 PAT> <用户名/仓库名>]"
  [options]="选项:"
  [opt_agents]="  --agents-cli \"...\"      镜像内置的 Agent CLI，空格或逗号分隔，默认 \"%s\""
  [opt_toolchains]="  --dev-toolchains \"...\"  镜像内置的开发工具链，空格或逗号分隔，默认 \"%s\""
  [opt_pat]="  --pat <token>            仓库 PAT，Fine-grained 或 Classic 均可"
  [opt_repo]="  --repo <用户名/仓库名>   GitHub 构建仓库"
  [opt_classic]="  --classic-pat <token>    GHCR Classic PAT，等价环境变量 CLASSIC_PAT"
  [opt_force]="  -f, --force              忽略缓存，强制触发 workflow 并重新拉取镜像"
  [opt_lang]="  --lang <zh|en>           输出语言，默认 zh"
  [opt_help]="  -h, --help               显示帮助"
  [agents_supported]="支持的 Agent CLI: %s（claude 为 claude-code 的别名）"
  [toolchains_supported]="支持的开发工具链: %s"
  [perm_title]="仓库 PAT 权限要求:"
  [perm_fine]="  Fine-grained: Contents、Workflows、Actions 的 Read and write"
  [perm_classic]="  Classic:      repo、workflow"
  [perm_ghcr]="GHCR Classic PAT 只需要 read:packages。"
  [too_many_positional]="位置参数过多。"
  [missing_required]="缺少仓库 PAT、仓库名或 GHCR Classic PAT。"
  [unknown_option]="未知参数: %s"
  [missing_value]="缺少 %s 的值"
  [invalid_agent]="不支持的 Agent CLI: %s（支持: %s）"
  [invalid_toolchain]="不支持的开发工具链: %s（支持: %s）"
  [hint_agents_node]="提示: Agent CLI 依赖 Node.js，已自动加入 node 工具链。"
  [hint_pnpm_node]="提示: pnpm 依赖 Node.js，已自动加入 node 工具链。"
  [summary_agents]="Agent CLI: %s"
  [summary_toolchains]="开发工具链: %s"
  [none]="无"
  [dep_missing]="缺少依赖: %s"
  [git_remote_missing]="git 不支持 HTTPS 克隆（缺少 git-remote-https）"
  [git_remote_installing]="正在尝试自动安装 git-http 支持..."
  [git_remote_installed]="git-http 安装成功"
  [git_remote_install_failed]="自动安装失败，请手动安装 git-http 后重试"
  [lang_question]="请选择语言 / Choose language: 1) 中文 2) English [1]: "
  [lang_invalid]="无效的选择。 / Invalid choice."
  [lang_unsupported]="不支持的语言: %s（可选 zh|en）"
  [prompt_agents]="Agent CLI（留空使用默认 \"%s\"）: "
  [prompt_toolchains]="开发工具链（留空使用默认 \"%s\"）: "
  [prompt_pat]="仓库 PAT（输入不回显）: "
  [prompt_repo]="GitHub 仓库（用户名/仓库名）: "
  [prompt_classic]="GHCR Classic PAT（输入不回显，留空使用 CLASSIC_PAT）: "
  [step1]=">>> [1/9] 验证 GitHub 仓库访问..."
  [repo_access_failed]="仓库访问失败 (HTTP %s)，请检查仓库名称和 PAT 权限。"
  [step2]=">>> [2/9] 推送 Dockerfile 和 workflow 到仓库..."
  [upload_ok]="  %s 上传成功"
  [upload_failed]="上传 %s 失败 (HTTP %s)"
  [generated_dockerfile]="  已生成 sandbox/Dockerfile"
  [workflow_missing]="未找到 .github/workflows/loopforge-sandbox.yml，且未设置 WORKFLOW_CONTENT。"
  [files_pushed]="  文件推送完成，等待 GitHub 处理..."
  [step3]=">>> [3/9] 触发 GitHub Actions 构建..."
  [upload_skipped]="%s 内容未变化，跳过上传"
  [dispatch_skipped]="Dockerfile 与 workflow 均未变化，跳过 workflow 触发"
  [dispatch_failed]="触发 workflow 失败 (HTTP %s)"
  [step4]=">>> [4/9] 等待 GitHub Actions 构建完成..."
  [query_failed]="查询 Actions 状态失败 (HTTP %s)"
  [build_success]="  镜像构建成功: %s"
  [build_failed]="  镜像构建失败，结论: %s"
  [check_run]="  请查看: %s"
  [build_timeout]="等待构建超时，请手动检查 Actions: %s"
  [step5]=">>> [5/9] 登录 GHCR 并检查镜像更新..."
  [step6]=">>> [6/9] 准备 LoopForge 官方仓库..."
  [image_up_to_date]="本地镜像已是最新，跳过拉取。"
  [image_outdated]="检测到新镜像，开始拉取..."
  [image_no_local]="本地未找到镜像，开始拉取..."
  [force_repull]="--force 模式：跳过 digest 对比，强制重新拉取镜像"
  [step7]=">>> [7/9] 检查 compose.yaml 中的镜像和沙箱配置..."
  [step7_note]="请根据当前版本确认自定义镜像的接入方式；镜像已拉取不代表已被 LoopForge 使用。"
  [step8]=">>> [8/9] 安装并启动 LoopForge..."
  [step9]=">>> [9/9] 检查平台容器状态..."
  [access_url]="LoopForge 访问地址: http://<服务器IP>:8090"
  [image_pulled]="自定义镜像已拉取: %s"
  [sandbox_check_title]="创建对话或运行 SOP 后，可执行以下命令检查实际沙箱镜像："
)

declare -A MSG_EN=(
  [usage_line]="Usage: %s [options] [<repo token> <owner/repo>]"
  [options]="Options:"
  [opt_agents]="  --agents-cli \"...\"      Agent CLIs baked into the image (default \"%s\")"
  [opt_toolchains]="  --dev-toolchains \"...\"  Dev toolchains baked into the image (default \"%s\")"
  [opt_pat]="  --pat <token>           Repository PAT, fine-grained or classic"
  [opt_repo]="  --repo <owner/repo>     GitHub repository used for the build"
  [opt_classic]="  --classic-pat <token>   GHCR classic PAT (same as CLASSIC_PAT env)"
  [opt_force]="  -f, --force              ignore caches, always dispatch workflow and re-pull image"
  [opt_lang]="  --lang <zh|en>          Output language, default zh"
  [opt_help]="  -h, --help              Show this help"
  [agents_supported]="Supported Agent CLIs: %s (claude is an alias of claude-code)"
  [toolchains_supported]="Supported toolchains: %s"
  [perm_title]="Repository PAT scopes:"
  [perm_fine]="  Fine-grained: Contents, Workflows and Actions read/write"
  [perm_classic]="  Classic:      repo, workflow"
  [perm_ghcr]="The GHCR classic PAT only needs read:packages."
  [too_many_positional]="Too many positional arguments."
  [missing_required]="Missing repository PAT, repository name or GHCR classic PAT."
  [unknown_option]="Unknown option: %s"
  [missing_value]="Missing value for %s"
  [invalid_agent]="Unsupported Agent CLI: %s (supported: %s)"
  [invalid_toolchain]="Unsupported toolchain: %s (supported: %s)"
  [hint_agents_node]="Note: Agent CLIs need Node.js; node was added to the toolchains."
  [hint_pnpm_node]="Note: pnpm needs Node.js; node was added to the toolchains."
  [summary_agents]="Agent CLIs: %s"
  [summary_toolchains]="Toolchains: %s"
  [none]="none"
  [dep_missing]="Missing dependency: %s"
  [git_remote_missing]="git does not support HTTPS cloning (missing git-remote-https)"
  [git_remote_installing]="Attempting to install git-http support..."
  [git_remote_installed]="git-http installed successfully"
  [git_remote_install_failed]="Auto-install failed. Please install git-http manually and retry."
  [lang_question]="Please choose language / 请选择语言: 1) 中文 2) English [1]: "
  [lang_invalid]="Invalid choice. / 无效的选择。"
  [lang_unsupported]="Unsupported language: %s (zh|en)"
  [prompt_agents]="Agent CLIs (empty for default \"%s\"): "
  [prompt_toolchains]="Dev toolchains (empty for default \"%s\"): "
  [prompt_pat]="Repository PAT (input hidden): "
  [prompt_repo]="GitHub repository (owner/repo): "
  [prompt_classic]="GHCR classic PAT (hidden; empty uses CLASSIC_PAT): "
  [step1]=">>> [1/9] Verifying GitHub repository access..."
  [repo_access_failed]="Repository access failed (HTTP %s). Check the repository name and PAT scopes."
  [step2]=">>> [2/9] Uploading Dockerfile and workflow..."
  [upload_ok]="  %s uploaded"
  [upload_failed]="Failed to upload %s (HTTP %s)"
  [generated_dockerfile]="  Generated sandbox/Dockerfile"
  [workflow_missing]="Missing .github/workflows/loopforge-sandbox.yml and WORKFLOW_CONTENT is not set."
  [files_pushed]="  Files pushed, waiting for GitHub to process them..."
  [step3]=">>> [3/9] Triggering GitHub Actions build..."
  [upload_skipped]="%s unchanged, skipping upload"
  [dispatch_skipped]="Both Dockerfile and workflow are unchanged, skipping workflow dispatch"
  [dispatch_failed]="Failed to trigger the workflow (HTTP %s)"
  [step4]=">>> [4/9] Waiting for the GitHub Actions build..."
  [query_failed]="Failed to query Actions status (HTTP %s)"
  [build_success]="  Image built successfully: %s"
  [build_failed]="  Image build failed, conclusion: %s"
  [check_run]="  See: %s"
  [build_timeout]="Timed out waiting for the build; check Actions manually: %s"
  [step5]=">>> [5/9] Logging in to GHCR and checking for image updates..."
  [step6]=">>> [6/9] Preparing the upstream LoopForge repository..."
  [image_up_to_date]="Local image is already up to date, skipping pull."
  [image_outdated]="New image detected, pulling..."
  [image_no_local]="Image not found locally, pulling..."
  [force_repull]="--force mode: skipping digest check, re-pulling image."
  [step7]=">>> [7/9] Checking image and sandbox settings in compose.yaml..."
  [step7_note]="Confirm how this version consumes a custom image; pulling it does not mean LoopForge uses it."
  [step8]=">>> [8/9] Installing and starting LoopForge..."
  [step9]=">>> [9/9] Checking platform container status..."
  [access_url]="LoopForge is available at: http://<server-ip>:8090"
  [image_pulled]="Custom image pulled: %s"
  [sandbox_check_title]="After starting a conversation or SOP run, inspect the real sandbox image with:"
)

msg() {
  local key="$1"
  shift
  if [ "$LANG_CODE" = "en" ]; then
    printf "${MSG_EN[$key]:-$key}" "$@"
  else
    printf "${MSG_ZH[$key]:-$key}" "$@"
  fi
}

usage() {
  echo "$(msg usage_line "$0")"
  echo ""
  echo "$(msg options)"
  echo "$(msg opt_agents "$DEFAULT_AGENTS")"
  echo "$(msg opt_toolchains "$DEFAULT_TOOLCHAINS")"
  echo "$(msg opt_pat)"
  echo "$(msg opt_repo)"
  echo "$(msg opt_classic)"
  echo "$(msg opt_lang)"
  echo "$(msg opt_help)"
  echo ""
  echo "$(msg agents_supported "$ALLOWED_AGENTS")"
  echo "$(msg toolchains_supported "$ALLOWED_TOOLCHAINS")"
  echo ""
  echo "$(msg perm_title)"
  echo "$(msg perm_fine)"
  echo "$(msg perm_classic)"
  echo "$(msg perm_ghcr)"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --agents-cli)
      [ "$#" -ge 2 ] || { msg missing_value "--agents-cli"; echo; exit 1; }
      AGENTS_CLI="$2"; AGENTS_SET=1; shift 2 ;;
    --dev-toolchains)
      [ "$#" -ge 2 ] || { msg missing_value "--dev-toolchains"; echo; exit 1; }
      DEV_TOOLCHAINS="$2"; TOOLCHAINS_SET=1; shift 2 ;;
    --pat)
      [ "$#" -ge 2 ] || { msg missing_value "--pat"; echo; exit 1; }
      PAT_ARG="$2"; shift 2 ;;
    --repo)
      [ "$#" -ge 2 ] || { msg missing_value "--repo"; echo; exit 1; }
      REPO_ARG="$2"; shift 2 ;;
    --classic-pat)
      [ "$#" -ge 2 ] || { msg missing_value "--classic-pat"; echo; exit 1; }
      CLASSIC_PAT_ARG="$2"; shift 2 ;;
    -f|--force)
      FORCE=1; shift ;;
    --lang)
      [ "$#" -ge 2 ] || { msg missing_value "--lang"; echo; exit 1; }
      case "${2,,}" in
        zh|cn|chinese) LANG_CODE="zh" ;;
        en|english) LANG_CODE="en" ;;
        *) msg lang_unsupported "$2"; echo; exit 1 ;;
      esac
      LANG_SET=1; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) msg unknown_option "$1"; echo; usage; exit 1 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

normalize_list() {
  local item result=""
  for item in ${1//,/ }; do
    result="${result:+$result }${item,,}"
  done
  printf '%s' "$result"
}

has_item() {
  case " $1 " in
    *" $2 "*) return 0 ;;
    *) return 1 ;;
  esac
}

# 交互式收集参数
if [ "$INTERACTIVE" -eq 1 ] && [ "$LANG_SET" -eq 0 ]; then
  while true; do
    read -r -p "$(msg lang_question)" lang_in || true
    case "${lang_in,,}" in
      ""|1|zh|中文) LANG_CODE="zh"; break ;;
      2|en|english) LANG_CODE="en"; break ;;
      *) msg lang_invalid; echo ;;
    esac
  done
fi

if [ "$INTERACTIVE" -eq 1 ]; then
  if [ "$AGENTS_SET" -eq 0 ]; then
    read -r -p "$(msg prompt_agents "$DEFAULT_AGENTS")" input || true
    if [ -n "${input:-}" ]; then
      AGENTS_CLI="$input"
    fi
  fi
  if [ "$TOOLCHAINS_SET" -eq 0 ]; then
    read -r -p "$(msg prompt_toolchains "$DEFAULT_TOOLCHAINS")" input || true
    if [ -n "${input:-}" ]; then
      DEV_TOOLCHAINS="$input"
    fi
  fi
fi

if [ "${#POSITIONAL[@]}" -gt 2 ]; then
  msg too_many_positional
  echo
  usage
  exit 1
fi

GITHUB_PAT="${PAT_ARG:-${POSITIONAL[0]:-}}"
REPO="${REPO_ARG:-${POSITIONAL[1]:-}}"
CLASSIC_PAT="${CLASSIC_PAT_ARG:-${CLASSIC_PAT:-}}"

if [ "$INTERACTIVE" -eq 1 ]; then
  if [ -z "$GITHUB_PAT" ]; then
    read -r -s -p "$(msg prompt_pat)" GITHUB_PAT || true
    echo
  fi
  if [ -z "$REPO" ]; then
    read -r -p "$(msg prompt_repo)" REPO || true
  fi
  if [ -z "$CLASSIC_PAT" ]; then
    read -r -s -p "$(msg prompt_classic)" CLASSIC_PAT || true
    echo
  fi
fi

if [ -z "$GITHUB_PAT" ] || [ -z "$REPO" ] || [ -z "$CLASSIC_PAT" ]; then
  msg missing_required
  echo
  usage
  exit 1
fi

AGENTS_CLI="$(normalize_list "$AGENTS_CLI")"
DEV_TOOLCHAINS="$(normalize_list "$DEV_TOOLCHAINS")"

# 别名：claude 等同于 claude-code
AGENTS_CLI="$(
  result=""
  for item in $AGENTS_CLI; do
    case "$item" in
      claude) item="claude-code" ;;
    esac
    result="${result:+$result }$item"
  done
  printf '%s' "$result"
)"

for item in $AGENTS_CLI; do
  if ! has_item "$ALLOWED_AGENTS" "$item"; then
    msg invalid_agent "$item" "$ALLOWED_AGENTS"
    echo
    exit 1
  fi
done

for item in $DEV_TOOLCHAINS; do
  if ! has_item "$ALLOWED_TOOLCHAINS" "$item"; then
    msg invalid_toolchain "$item" "$ALLOWED_TOOLCHAINS"
    echo
    exit 1
  fi
done

if [ -n "$AGENTS_CLI" ] && ! has_item "$DEV_TOOLCHAINS" node; then
  DEV_TOOLCHAINS="$(normalize_list "$DEV_TOOLCHAINS node")"
  msg hint_agents_node
  echo
fi

if has_item "$DEV_TOOLCHAINS" pnpm && ! has_item "$DEV_TOOLCHAINS" node; then
  DEV_TOOLCHAINS="$(normalize_list "$DEV_TOOLCHAINS node")"
  msg hint_pnpm_node
  echo
fi

GITHUB_API="https://api.github.com"
OWNER="${REPO%%/*}"
IMAGE_NAME="ghcr.io/${REPO}/loopforge-sandbox:latest"
LOOPFORGE_DIR="${LOOPFORGE_DIR:-/opt/loopforge}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

msg summary_agents "${AGENTS_CLI:-$(msg none)}"
echo
msg summary_toolchains "${DEV_TOOLCHAINS:-$(msg none)}"
echo

# 步骤 0：参数与依赖检查
for cmd in git docker curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    msg dep_missing "$cmd"
    echo
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  msg dep_missing "docker compose"
  echo
  exit 1
fi

# 步骤 0.5：检测并修复 git HTTPS 支持
ensure_git_remote_https() {
  local exec_path
  exec_path="$(git --exec-path)"
  if [ -x "${exec_path}/git-remote-https" ] || [ -x "${exec_path}/git-remote-http" ]; then
    return 0
  fi

  msg git_remote_missing
  echo
  msg git_remote_installing
  echo

  if command -v opkg >/dev/null 2>&1; then
    if sudo opkg update && sudo opkg install git-http; then
      msg git_remote_installed
      echo
      return 0
    fi
  elif command -v apt-get >/dev/null 2>&1; then
    if sudo apt-get update && sudo apt-get install -y --reinstall git; then
      msg git_remote_installed
      echo
      return 0
    fi
  elif command -v yum >/dev/null 2>&1; then
    if sudo yum install -y git; then
      msg git_remote_installed
      echo
      return 0
    fi
  elif command -v apk >/dev/null 2>&1; then
    if sudo apk add git; then
      msg git_remote_installed
      echo
      return 0
    fi
  fi

  msg git_remote_install_failed
  echo
  exit 1
}
ensure_git_remote_https

# 步骤 1：验证 PAT 和仓库访问
msg step1
echo
http_code=$(curl -s -o /tmp/loopforge_repo_resp.json -w "%{http_code}" \
  -H "Authorization: token $GITHUB_PAT" \
  -H "Accept: application/vnd.github+json" \
  "$GITHUB_API/repos/$REPO")
if [ "$http_code" != "200" ]; then
  msg repo_access_failed "$http_code"
  echo
  cat /tmp/loopforge_repo_resp.json
  exit 1
fi

# 步骤 2：自动上传 Dockerfile 和 workflow
msg step2
echo
DOCKERFILE_PATH="sandbox/Dockerfile"
WORKFLOW_PATH=".github/workflows/loopforge-sandbox.yml"

upload_file_to_github() {
  local file_path="$1"
  local content="$2"
  local commit_message="$3"

  # 计算本地 blob SHA（与 GitHub Contents API 返回的 sha 格式一致）
  local local_sha
  local_sha=$(printf 'blob %d\0%s' "${#content}" "$content" | sha1sum | cut -d' ' -f1)

  # 获取远端当前文件的 sha 和内容 base64
  local remote_json remote_sha remote_b64
  remote_json=$(curl -s \
    -H "Authorization: token $GITHUB_PAT" \
    -H "Accept: application/vnd.github+json" \
    "$GITHUB_API/repos/$REPO/contents/$file_path")
  remote_sha=$(printf '%s' "$remote_json" | jq -r '.sha // empty')
  remote_b64=$(printf '%s' "$remote_json" | jq -r '.content // empty')

  # 远端文件存在，对比内容：本地 blob SHA vs 远端 blob SHA（FORCE=1 时跳过对比）
  if [ -z "${FORCE:-}" ] && [ -n "$remote_sha" ] && [ "$local_sha" = "$remote_sha" ]; then
    msg upload_skipped "$file_path"
    echo
    return 2  # 2 = 跳过，无变化
  fi

  # 远端文件不存在，或内容不同 → 上传
  local encoded_content
  encoded_content=$(printf '%s' "$content" | base64 -w 0)

  local body
  if [ -n "$remote_sha" ]; then
    body=$(jq -n \
      --arg msg "$commit_message" \
      --arg content "$encoded_content" \
      --arg sha "$remote_sha" \
      '{message: $msg, content: $content, sha: $sha}')
  else
    body=$(jq -n \
      --arg msg "$commit_message" \
      --arg content "$encoded_content" \
      '{message: $msg, content: $content}')
  fi

  local http_code
  http_code=$(curl -s -o /tmp/upload_resp.json -w "%{http_code}" \
    -X PUT \
    -H "Authorization: token $GITHUB_PAT" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "$GITHUB_API/repos/$REPO/contents/$file_path")

  if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
    msg upload_failed "$file_path" "$http_code"
    echo
    cat /tmp/upload_resp.json
    return 1
  fi

  msg upload_ok "$file_path"
  echo
  return 0
}

generate_dockerfile() {
  cat <<'DOCKER_EOF'
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo

ENV PATH=/opt/cargo/bin:/usr/local/go/bin:$PATH \
    GOPATH=/root/go

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ca-certificates build-essential \
    && rm -rf /var/lib/apt/lists/*
DOCKER_EOF

  if has_item "$DEV_TOOLCHAINS" python; then
    cat <<'DOCKER_EOF'

# Python（apt 走官方源，pip 走清华镜像）
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python-is-python3 \
    && rm -rf /var/lib/apt/lists/* \
    && printf '[global]\nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple\n' > /etc/pip.conf \
    && python --version && pip --version
DOCKER_EOF
  fi

  if has_item "$DEV_TOOLCHAINS" rust; then
    cat <<'DOCKER_EOF'

# Rust（rustup 走官方源）
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path \
    && rustc --version && cargo --version

# Cargo 依赖源国内化
RUN mkdir -p $CARGO_HOME && cat > $CARGO_HOME/config.toml <<'EOF'
[source.crates-io]
replace-with = 'ustc'

[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
EOF
DOCKER_EOF
  fi

  if has_item "$DEV_TOOLCHAINS" golang; then
    cat <<'DOCKER_EOF'

# Go（二进制走官方源）
ARG GO_VERSION=1.24.2
RUN curl -fsSL "https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tgz \
    && tar -C /usr/local -xzf /tmp/go.tgz \
    && rm /tmp/go.tgz \
    && go version \
    && go env -w GOPROXY=https://goproxy.cn,direct \
    && go env -w GOSUMDB=off
DOCKER_EOF
  fi

  if has_item "$DEV_TOOLCHAINS" node; then
    cat <<'DOCKER_EOF'

# Node.js（NodeSource 走官方源）
RUN apt-get update && apt-get install -y --no-install-recommends gnupg \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y --no-install-recommends nodejs \
    && node -v && npm -v \
    && rm -rf /var/lib/apt/lists/*

RUN npm config set registry https://registry.npmmirror.com
DOCKER_EOF
  fi

  if has_item "$DEV_TOOLCHAINS" pnpm; then
    cat <<'DOCKER_EOF'

# pnpm（走已配置的 npm 国内源）
RUN npm install -g pnpm@latest \
    && pnpm --version

# pnpm 依赖源国内化
RUN pnpm config set registry https://registry.npmmirror.com
DOCKER_EOF
  fi

  if [ -n "$AGENTS_CLI" ]; then
    local item pkg pkgs=""
    for item in $AGENTS_CLI; do
      case "$item" in
        codebuddy) pkg="@tencent-ai/codebuddy-code@latest" ;;
        codex) pkg="@openai/codex@latest" ;;
        claude-code) pkg="@anthropic-ai/claude-code@latest" ;;
        dsh) pkg="@deepseek-ai/dsh@latest" ;;
        opencode) pkg="opencode-ai@latest" ;;
        *) pkg="" ;;
      esac
      pkgs="${pkgs:+$pkgs }$pkg"
    done
    cat <<DOCKER_EOF

# Agent CLI（走已配置的 npm 国内源）
RUN npm install -g $pkgs
DOCKER_EOF
  fi

  cat <<'DOCKER_EOF'

WORKDIR /workspace
DOCKER_EOF
}

DOCKERFILE_CONTENT="${DOCKERFILE_CONTENT:-}"
if [ -z "$DOCKERFILE_CONTENT" ]; then
  mkdir -p "${SCRIPT_DIR}/sandbox"
  generate_dockerfile > "${SCRIPT_DIR}/sandbox/Dockerfile"
  DOCKERFILE_CONTENT=$(cat "${SCRIPT_DIR}/sandbox/Dockerfile")
  msg generated_dockerfile
  echo
fi

NEEDS_BUILD=false
[ -n "${FORCE:-}" ] && NEEDS_BUILD=true

if upload_file_to_github "$DOCKERFILE_PATH" "$DOCKERFILE_CONTENT" \
  "chore: upload LoopForge sandbox Dockerfile [skip ci]"; then
  NEEDS_BUILD=true
fi

WORKFLOW_CONTENT="${WORKFLOW_CONTENT:-}"
if [ -z "$WORKFLOW_CONTENT" ]; then
  if [ -f "${SCRIPT_DIR}/.github/workflows/loopforge-sandbox.yml" ]; then
    WORKFLOW_CONTENT=$(cat "${SCRIPT_DIR}/.github/workflows/loopforge-sandbox.yml")
  else
    msg workflow_missing
    echo
    exit 1
  fi
fi

if upload_file_to_github "$WORKFLOW_PATH" "$WORKFLOW_CONTENT" \
  "chore: upload LoopForge sandbox workflow [skip ci]"; then
  NEEDS_BUILD=true
fi

if [ "$NEEDS_BUILD" = false ]; then
  msg dispatch_skipped
  echo
else
  msg files_pushed
  echo
  sleep 3
fi

# 步骤 3 & 4：触发 workflow 并等待构建
if [ "$NEEDS_BUILD" = true ]; then
  msg step3
  echo
  http_code=$(curl -s -o /tmp/loopforge_dispatch_resp.json -w "%{http_code}" \
    -X POST \
    -H "Authorization: token $GITHUB_PAT" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: application/json" \
    -d '{"ref":"main"}' \
    "$GITHUB_API/repos/$REPO/actions/workflows/loopforge-sandbox.yml/dispatches")
  if [ "$http_code" != "204" ]; then
    msg dispatch_failed "$http_code"
    echo
    cat /tmp/loopforge_dispatch_resp.json
    exit 1
  fi

  # 步骤 4：轮询构建结果，每 2 分钟一次，最多 60 次
  msg step4
  echo
  run_url=""
  for ((i = 1; i <= 60; i++)); do
    http_code=$(curl -s -o /tmp/loopforge_runs_resp.json -w "%{http_code}" \
      -H "Authorization: token $GITHUB_PAT" \
      -H "Accept: application/vnd.github+json" \
      "$GITHUB_API/repos/$REPO/actions/runs?event=workflow_dispatch&per_page=1")
    if [ "$http_code" != "200" ]; then
      msg query_failed "$http_code"
      echo
      cat /tmp/loopforge_runs_resp.json
      exit 1
    fi

    status=$(jq -r '.workflow_runs[0].status // empty' /tmp/loopforge_runs_resp.json)
    conclusion=$(jq -r '.workflow_runs[0].conclusion // empty' /tmp/loopforge_runs_resp.json)
    run_url=$(jq -r '.workflow_runs[0].html_url // empty' /tmp/loopforge_runs_resp.json)

    if [ "$status" = "completed" ]; then
      if [ "$conclusion" = "success" ]; then
        msg build_success "$run_url"
        echo
        break
      fi
      msg build_failed "${conclusion:-unknown}"
      echo
      msg check_run "$run_url"
      echo
      exit 1
    fi

    if [ "$i" -eq 60 ]; then
      msg build_timeout "$run_url"
      echo
      exit 1
    fi
    sleep 120
  done
fi

# 步骤 5：使用 Classic PAT 登录 GHCR，对比 digest 后按需拉取镜像
msg step5
echo
echo "$CLASSIC_PAT" | docker login ghcr.io -u "$OWNER" --password-stdin

skip_pull=false
if [ -n "${FORCE:-}" ]; then
  msg force_repull
  echo
elif docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  local_digest=$(docker image inspect "$IMAGE_NAME" \
    --format '{{range .RepoDigests}}{{println .}}{{end}}' 2>/dev/null \
    | grep "@sha256:" | head -1 | sed 's/.*@//')
  remote_digest=$(docker buildx imagetools inspect "$IMAGE_NAME" \
    --format '{{.Manifest.Digest}}' 2>/dev/null || echo "")
  if [ -n "$local_digest" ] && [ -n "$remote_digest" ] && [ "$local_digest" = "$remote_digest" ]; then
    skip_pull=true
    msg image_up_to_date
    echo
  else
    msg image_outdated
    echo
  fi
else
  msg image_no_local
  echo
fi

if [ "$skip_pull" = false ]; then
  docker pull "$IMAGE_NAME"
fi

# 步骤 6：克隆 LoopForge
msg step6
echo
if [ ! -d "$LOOPFORGE_DIR/.git" ]; then
  sudo git clone https://github.com/Tencent/LoopForge.git "$LOOPFORGE_DIR"
  sudo chown -R "$(id -u):$(id -g)" "$LOOPFORGE_DIR"
fi
cd "$LOOPFORGE_DIR"

# 步骤 7：只检查配置入口，不盲目替换平台或沙箱镜像
msg step7
echo
grep -nE 'image:|sandbox|SANDBOX|docker.sock' compose.yaml || true
msg step7_note
echo

# 步骤 8：安装并启动 LoopForge
msg step8
echo
export LOOPFORGE_YES=1
export MIRROR="${MIRROR:-}"
./start.sh

# 步骤 9：验证并输出访问信息
msg step9
echo
docker ps --filter "name=loopforge" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
echo ""
msg access_url
echo
msg image_pulled "$IMAGE_NAME"
echo
msg sandbox_check_title
echo
echo "docker ps --format 'table {{.Names}}\t{{.Image}}' | grep -i sandbox"
