FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo

ENV PATH=/opt/cargo/bin:/usr/local/go/bin:$PATH \
    GOPATH=/root/go

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ca-certificates build-essential \
    && rm -rf /var/lib/apt/lists/*

# Python（apt 走官方源，pip 走清华镜像）
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python-is-python3 \
    && rm -rf /var/lib/apt/lists/* \
    && printf '[global]\nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple\n' > /etc/pip.conf \
    && python --version && pip --version

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

# Go（二进制走官方源）
ARG GO_VERSION=1.24.2
RUN curl -fsSL "https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tgz \
    && tar -C /usr/local -xzf /tmp/go.tgz \
    && rm /tmp/go.tgz \
    && go version \
    && go env -w GOPROXY=https://goproxy.cn,direct \
    && go env -w GOSUMDB=off

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

# pnpm（走已配置的 npm 国内源）
RUN npm install -g pnpm@latest \
    && pnpm --version

# pnpm 依赖源国内化
RUN pnpm config set registry https://registry.npmmirror.com

# Agent CLI（走已配置的 npm 国内源）
RUN npm install -g @tencent-ai/codebuddy-code@latest @openai/codex@latest @deepseek-ai/dsh@latest

WORKDIR /workspace