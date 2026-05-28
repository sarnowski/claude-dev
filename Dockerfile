FROM ubuntu:24.04

ARG USER_UID=1000
ARG USER_GID=1000
ARG USERNAME=dev
# GID of the host's docker socket group. claude-update detects this from
# /var/run/docker.sock on the host and overrides this default. Adding the
# dev user to a group with this GID means `docker` works inside the
# container without sudo. 999 is the common Linux default for the docker
# group; the build arg overrides it when the host differs.
ARG DOCKER_GID=999

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Europe/Berlin \
    DISABLE_AUTOUPDATER=1 \
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
    CA_CERTIFICATES_PATH=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# =============================================================================
# Layer ordering: stable at the top, volatile at the bottom. Adding new
# convenience tools should usually mean editing the "Volatile zone" near the
# end so the heavy upper layers (cloud CLIs, language runtimes, SDKMAN/JDK)
# stay cached.
# =============================================================================

# --- Bootstrap apt (minimum required for every step below) -------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg lsb-release apt-transport-https \
      git openssh-client \
      bash zsh \
      build-essential gcc g++ make pkg-config \
      python3 python3-pip python3-venv python3-dev pipx \
      sudo locales tzdata \
      unzip zip xz-utils \
 && rm -rf /var/lib/apt/lists/*

# --- Trust any extra CA certificates staged by bin/claude-update -------------
# claude-update mirrors host /usr/local/share/ca-certificates/*.crt into
# ./ca-certificates/ so corporate TLS-intercepting proxies remain trusted
# during the rest of this build and at runtime. The directory always contains
# at least a .keep placeholder, so this step is a no-op when no host CAs exist.
COPY ca-certificates/ /usr/local/share/ca-certificates/
RUN update-ca-certificates

# --- Create the dev user (matches host UID/GID) ------------------------------
RUN if getent group "${USER_GID}" >/dev/null; then \
      groupmod -n "${USERNAME}" "$(getent group ${USER_GID} | cut -d: -f1)"; \
    else \
      groupadd --gid "${USER_GID}" "${USERNAME}"; \
    fi \
 && if id -u "${USER_UID}" >/dev/null 2>&1; then \
      usermod -l "${USERNAME}" -d "/home/${USERNAME}" -m "$(id -un ${USER_UID})"; \
    else \
      useradd --uid "${USER_UID}" --gid "${USER_GID}" --shell /bin/bash \
              --create-home "${USERNAME}"; \
    fi \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME} \
 && if [ "${DOCKER_GID}" -gt 0 ]; then \
      if getent group "${DOCKER_GID}" >/dev/null; then \
        usermod -aG "$(getent group ${DOCKER_GID} | cut -d: -f1)" "${USERNAME}"; \
      else \
        groupadd --gid "${DOCKER_GID}" docker-host \
          && usermod -aG docker-host "${USERNAME}"; \
      fi; \
    fi

# --- Heavy, stable apt-repo CLIs ---------------------------------------------
# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# Docker CLI + buildx + compose plugin
RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
 && chmod a+r /etc/apt/keyrings/docker.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
      > /etc/apt/sources.list.d/docker.list \
 && apt-get update && apt-get install -y --no-install-recommends \
      docker-ce-cli docker-buildx-plugin docker-compose-plugin \
 && rm -rf /var/lib/apt/lists/*

# Azure CLI
RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
 && chmod a+r /etc/apt/keyrings/microsoft.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/azure-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends azure-cli \
 && rm -rf /var/lib/apt/lists/*

# AKS-matched kubectl + kubelogin (needs Azure CLI installed above)
RUN az aks install-cli \
      --install-location /usr/local/bin/kubectl \
      --kubelogin-install-location /usr/local/bin/kubelogin

# --- Language runtimes (root-installed) --------------------------------------
# Erlang + Elixir
RUN apt-get update && apt-get install -y --no-install-recommends \
      erlang elixir \
 && rm -rf /var/lib/apt/lists/*

# Go — Ubuntu 24.04 ships golang-1.24 (current upstream stable)
RUN apt-get update && apt-get install -y --no-install-recommends golang-1.24 \
 && rm -rf /var/lib/apt/lists/*
ENV PATH="/usr/lib/go-1.24/bin:${PATH}"

# Node.js 22 LTS via NodeSource. Ubuntu's default `nodejs` is 18 which is EOL
# (April 2025), so we cannot rely on the distro package. pnpm / typescript /
# ts-node / typescript-language-server are stable globals;
# @anthropic-ai/claude-code lives in the volatile zone because it ships often.
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g pnpm typescript ts-node typescript-language-server

# Clojure CLI (clj). Needs a JDK at runtime (provided by SDKMAN below); the
# installer itself does not.
RUN curl -fsSL https://github.com/clojure/brew-install/releases/latest/download/posix-install.sh \
      -o /tmp/clj-install.sh \
 && chmod +x /tmp/clj-install.sh && /tmp/clj-install.sh && rm /tmp/clj-install.sh

# --- Per-user toolchains: uv, rustup, mix, SDKMAN ----------------------------
USER ${USERNAME}
ENV HOME=/home/${USERNAME}
WORKDIR /home/${USERNAME}

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --default-toolchain stable --profile minimal
RUN mix local.hex --force && mix local.rebar --force

ENV PATH="/home/${USERNAME}/.local/bin:/home/${USERNAME}/.bun/bin:/home/${USERNAME}/.cargo/bin:${PATH}" \
    BUN_INSTALL="/home/${USERNAME}/.bun"

# SDKMAN! manages JDK / Maven / other JVM tool versions inside the container.
# Its installer appends sdkman-init.sh sourcing to ~/.bashrc and ~/.zshrc so
# the `sdk` command is available in interactive shells (claude-shell). For
# non-interactive launches (`claude`), JAVA_HOME / Maven PATH are baked into
# the image ENV below so they are reachable without sourcing the init script.
RUN curl -fsSL https://get.sdkman.io | bash \
 && bash -c 'set -e; \
      source "$HOME/.sdkman/bin/sdkman-init.sh"; \
      JAVA_ID=$(sdk list java | grep -oE "25(\.[0-9]+)+(-[a-z]+)?-open" | sort -V | tail -1); \
      [ -n "$JAVA_ID" ] || { echo "no OpenJDK 25 build available in sdkman" >&2; exit 1; }; \
      yes | sdk install java "$JAVA_ID"; \
      sdk default java "$JAVA_ID"; \
      yes | sdk install maven'

ENV SDKMAN_DIR="/home/${USERNAME}/.sdkman" \
    JAVA_HOME="/home/${USERNAME}/.sdkman/candidates/java/current"
ENV PATH="${JAVA_HOME}/bin:/home/${USERNAME}/.sdkman/candidates/maven/current/bin:${PATH}"

# --- Trust the staged CA certificates inside the JVM keystore ----------------
# update-ca-certificates only refreshes the system PEM bundle; the JVM keeps
# its own cacerts store and does not read /etc/ssl/certs. Import every staged
# CA so JVM-based tooling (Maven, Gradle, Java HTTP clients) trusts the same
# corporate roots as everything else. No-op when only the .keep placeholder
# is present.
RUN for cert in /usr/local/share/ca-certificates/*.crt; do \
      [ -f "$cert" ] || continue; \
      alias="claude-dev-$(basename "$cert" .crt)"; \
      keytool -importcert -noprompt -trustcacerts \
        -keystore "$JAVA_HOME/lib/security/cacerts" \
        -storepass changeit \
        -alias "$alias" \
        -file "$cert"; \
    done

# =============================================================================
# Volatile zone — most-frequently-edited steps live below. Edits here only
# invalidate the bottom of the cache, not the language runtimes / SDKMAN
# layers above.
# =============================================================================
USER root
ENV HOME=/root

# Terraform (HashiCorp apt repo, tracks stable)
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg \
      | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/hashicorp.list \
 && apt-get update && apt-get install -y --no-install-recommends terraform \
 && rm -rf /var/lib/apt/lists/*

# terraform-docs (static GitHub release binary)
ARG TERRAFORM_DOCS_VERSION=0.19.0
RUN ARCH="$(dpkg --print-architecture)" \
 && curl -fsSL "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-${ARCH}.tar.gz" \
      -o /tmp/terraform-docs.tgz \
 && tar -C /tmp -xzf /tmp/terraform-docs.tgz terraform-docs \
 && install -m 0755 /tmp/terraform-docs /usr/local/bin/terraform-docs \
 && rm -f /tmp/terraform-docs.tgz /tmp/terraform-docs

# grpcurl (static GitHub release binary — no official Debian package)
ARG GRPCURL_VERSION=1.9.3
RUN case "$(dpkg --print-architecture)" in \
      amd64) ARCH=x86_64 ;; \
      arm64) ARCH=arm64 ;; \
      *) echo "unsupported arch for grpcurl" >&2; exit 1 ;; \
    esac \
 && curl -fsSL "https://github.com/fullstorydev/grpcurl/releases/download/v${GRPCURL_VERSION}/grpcurl_${GRPCURL_VERSION}_linux_${ARCH}.tar.gz" \
      -o /tmp/grpcurl.tgz \
 && tar -C /tmp -xzf /tmp/grpcurl.tgz grpcurl \
 && install -m 0755 /tmp/grpcurl /usr/local/bin/grpcurl \
 && rm -f /tmp/grpcurl.tgz /tmp/grpcurl

# Kotlin LSP (standalone JetBrains build). Distributed via JetBrains' CDN, not
# GitHub releases; requires JDK 25, which SDKMAN installed above. The launcher
# at /usr/local/bin/kotlin-lsp matches the symlink name the upstream README
# suggests, so Claude Code's LSP integration finds it on PATH.
ARG KOTLIN_LSP_VERSION=262.4739.0
RUN case "$(dpkg --print-architecture)" in \
      amd64) SUFFIX="" ;; \
      arm64) SUFFIX="-aarch64" ;; \
      *) echo "unsupported arch for kotlin-lsp" >&2; exit 1 ;; \
    esac \
 && curl -fsSL "https://download-cdn.jetbrains.com/kotlin-lsp/${KOTLIN_LSP_VERSION}/kotlin-server-${KOTLIN_LSP_VERSION}${SUFFIX}.tar.gz" \
      -o /tmp/kotlin-lsp.tgz \
 && curl -fsSL "https://download-cdn.jetbrains.com/kotlin-lsp/${KOTLIN_LSP_VERSION}/kotlin-server-${KOTLIN_LSP_VERSION}${SUFFIX}.tar.gz.sha256" \
      -o /tmp/kotlin-lsp.tgz.sha256 \
 && (cd /tmp && awk '{print $1"  kotlin-lsp.tgz"}' kotlin-lsp.tgz.sha256 | sha256sum -c -) \
 && mkdir -p /opt/kotlin-lsp \
 && tar -C /opt/kotlin-lsp --strip-components=1 -xzf /tmp/kotlin-lsp.tgz \
 && ln -s /opt/kotlin-lsp/bin/intellij-server /usr/local/bin/kotlin-lsp \
 && rm -f /tmp/kotlin-lsp.tgz /tmp/kotlin-lsp.tgz.sha256

# Convenience CLI tools — this is the layer most likely to grow. Add new
# debian-packaged dev tools here.
RUN apt-get update && apt-get install -y --no-install-recommends \
      tmux \
      ripgrep \
      fd-find \
      jq \
      yq \
      less \
      file \
      tree \
      sqlite3 \
      dnsutils \
      iproute2 \
      iputils-ping \
      lsof \
      vim \
      postgresql-client \
      redis-tools \
      rlwrap \
      pre-commit \
      kubectx \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd \
 && rm -rf /var/lib/apt/lists/*

# Claude Code itself — Anthropic ships updates frequently, so it sits in its
# own layer so bumping the version only invalidates this one step.
# CLAUDE_CODE_CACHE_BUST is set by bin/claude-update to the current epoch so
# this layer is rebuilt every time, guaranteeing the newest claude-code.
ARG CLAUDE_CODE_CACHE_BUST=0
RUN echo "claude-code cache-bust: ${CLAUDE_CODE_CACHE_BUST}" \
 && npm install -g @anthropic-ai/claude-code

# --- Final user setup --------------------------------------------------------
USER ${USERNAME}
ENV HOME=/home/${USERNAME}

# Ensure ~/.claude exists with the right owner; the actual shared config
# (CLAUDE.md, settings.json, agents/, commands/, skills/, hooks/) is bind-mounted
# at runtime from the repo's claude-config/ by bin/_claude-run, so edits made
# inside a session land directly in the repo working tree.
# Also drop the marker that suppresses Ubuntu's "To run a command as
# administrator..." hint from /etc/bash.bashrc — the dev user is in the
# sudo group, so claude-shell would print it on every interactive start.
RUN mkdir -p /home/${USERNAME}/.claude \
 && touch /home/${USERNAME}/.sudo_as_admin_successful

WORKDIR /workspace
CMD ["bash"]
