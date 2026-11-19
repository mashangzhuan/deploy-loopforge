FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

ENV RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static \
    RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup \
    RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo

ENV PATH=/opt/cargo/bin:/usr/local/go/bin:$PATH \
    GOPATH=/root/go

# Debian APT 国内镜像
RUN sed -i 's|deb.debian.org|mirrors.ustc.edu.cn|g; s|security.debian.org|mirrors.ustc.edu.cn|g' \
    /etc/apt/sources.list.d/debian.sources 2>/dev/null || \
    sed -i 's|deb.debian.org|mirrors.ustc.edu.cn|g; s|security.debian.org|mirrors.ustc.edu.cn|g' \
    /etc/apt/sources.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ca-certificates build-essential \
    && rm -rf /var/lib/apt/lists/*

# Python（apt 走中科大镜像，pip 走清华镜像）
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python-is-python3 \
    && rm -rf /var/lib/apt/lists/* \
    && printf '[global]\nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple\n' > /etc/pip.conf \
    && python --version && pip --version

# Rust（rustup 走中科大镜像）
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path \
    && rustc --version && cargo --version

# Cargo 依赖源国内化
RUN mkdir -p $CARGO_HOME && cat > $CARGO_HOME/config.toml <<'EOF'
[source.crates-io]
replace-with = 'ustc'

[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
EOF

# Go（二进制走中科大镜像）
ARG GO_VERSION=1.24.2
RUN curl -fsSL "https://mirrors.ustc.edu.cn/golang/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tgz \
    && tar -C /usr/local -xzf /tmp/go.tgz \
    && rm /tmp/go.tgz \
    && go version \
    && go env -w GOPROXY=https://goproxy.cn,direct \
    && go env -w GOSUMDB=off

# Node.js（NodeSource 走清华镜像）
RUN apt-get update && apt-get install -y --no-install-recommends gnupg \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/nodesource/dist_20.x/nodesource.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://mirrors.tuna.tsinghua.edu.cn/nodesource/deb_20.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y --no-install-recommends nodejs \
    && node -v && npm -v \
    && rm -rf /var/lib/apt/lists/*

RUN npm config set registry https://registry.npmmirror.com

# pnpm（走已配置的 npm 国内源）
RUN npm install -g pnpm@latest \
    && pnpm --version

# pnpm 依赖源国内化
RUN pnpm config set registry https://registry.npmmirror.com

# Agent CLI（走已配置的 npm 国内源）
RUN npm install -g @tencent-ai/codebuddy-code@latest @openai/codex@latest @anthropic-ai/claude-code@latest @deepseek-ai/dsh@latest

WORKDIR /workspace
