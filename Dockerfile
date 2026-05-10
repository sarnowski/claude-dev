FROM ubuntu:24.04

ARG USER_UID=1000
ARG USER_GID=1000
ARG USERNAME=dev

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Europe/Berlin \
    DISABLE_AUTOUPDATER=1

# --- core OS + build tools ----------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg lsb-release apt-transport-https \
      git openssh-client \
      bash zsh tmux \
      ripgrep fd-find jq yq \
      less file unzip zip xz-utils \
      build-essential gcc g++ make pkg-config \
      python3 python3-pip python3-venv python3-dev pipx \
      sudo locales tzdata \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd \
 && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# --- Docker CLI + compose plugin ---------------------------------------------
RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
 && chmod a+r /etc/apt/keyrings/docker.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
      > /etc/apt/sources.list.d/docker.list \
 && apt-get update && apt-get install -y --no-install-recommends \
      docker-ce-cli docker-buildx-plugin docker-compose-plugin \
 && rm -rf /var/lib/apt/lists/*

# --- HashiCorp (Terraform) ---------------------------------------------------
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg \
      | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/hashicorp.list \
 && apt-get update && apt-get install -y --no-install-recommends terraform \
 && rm -rf /var/lib/apt/lists/*

# --- kubectl + helm ----------------------------------------------------------
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key \
      | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" \
      > /etc/apt/sources.list.d/kubernetes.list \
 && apt-get update && apt-get install -y --no-install-recommends kubectl \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# --- gcloud CLI --------------------------------------------------------------
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      > /etc/apt/sources.list.d/google-cloud-sdk.list \
 && apt-get update && apt-get install -y --no-install-recommends google-cloud-cli \
 && rm -rf /var/lib/apt/lists/*

# --- Azure CLI ---------------------------------------------------------------
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
 && chmod a+r /etc/apt/keyrings/microsoft.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/azure-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends azure-cli \
 && rm -rf /var/lib/apt/lists/*

# --- AWS CLI v2 (arch-aware) -------------------------------------------------
RUN ARCH="$(uname -m)"; case "$ARCH" in \
      x86_64) AWS_ARCH=x86_64 ;; \
      aarch64) AWS_ARCH=aarch64 ;; \
      *) echo "unsupported arch: $ARCH" && exit 1 ;; \
    esac \
 && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o /tmp/awscli.zip \
 && unzip -q /tmp/awscli.zip -d /tmp \
 && /tmp/aws/install \
 && rm -rf /tmp/aws /tmp/awscli.zip

# --- OpenJDK + Maven + Clojure ----------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      openjdk-21-jdk-headless maven \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL https://github.com/clojure/brew-install/releases/latest/download/posix-install.sh \
      -o /tmp/clj-install.sh \
 && chmod +x /tmp/clj-install.sh && /tmp/clj-install.sh && rm /tmp/clj-install.sh

# --- Erlang + Elixir (Ubuntu repos) ------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      erlang elixir \
 && rm -rf /var/lib/apt/lists/*

# --- Go (arch-aware, latest stable) -----------------------------------------
ARG GO_VERSION=1.23.4
RUN ARCH="$(dpkg --print-architecture)" \
 && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" -o /tmp/go.tgz \
 && tar -C /usr/local -xzf /tmp/go.tgz && rm /tmp/go.tgz
ENV PATH="/usr/local/go/bin:${PATH}"

# --- Node.js + pnpm + TypeScript + Claude Code -------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g pnpm typescript ts-node @anthropic-ai/claude-code

# --- Convenience CLI tools (frequently reached for during dev/agent work) ----
RUN apt-get update && apt-get install -y --no-install-recommends \
      tree \
      sqlite3 \
      dnsutils \
      iputils-ping \
      vim \
      postgresql-client \
      redis-tools \
      rlwrap \
    && rm -rf /var/lib/apt/lists/*

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
 && groupadd -f -g 1 docker-host \
 && usermod -aG docker-host "${USERNAME}"

 # --- Per-user toolchains: uv, bun, rustup ------------------------------------
 USER ${USERNAME}
 ENV HOME=/home/${USERNAME}
 WORKDIR /home/${USERNAME}

 RUN curl -LsSf https://astral.sh/uv/install.sh | sh
 RUN curl -fsSL https://bun.sh/install | bash
 RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
       | sh -s -- -y --default-toolchain stable --profile minimal

 # Mix archives (hex package manager + rebar3 for Erlang deps).
 RUN mix local.hex --force && mix local.rebar --force

 ENV PATH="/home/${USERNAME}/.local/bin:/home/${USERNAME}/.bun/bin:/home/${USERNAME}/.cargo/bin:${PATH}" \
     BUN_INSTALL="/home/${USERNAME}/.bun"

# Ensure ~/.claude exists with the right owner; the actual shared config
# (CLAUDE.md, settings.json, agents/, commands/, skills/, hooks/) is bind-mounted
# at runtime from the repo's claude-config/ by bin/_claude-run, so edits made
# inside a session land directly in the repo working tree.
RUN mkdir -p /home/${USERNAME}/.claude

WORKDIR /workspace
CMD ["bash"]
