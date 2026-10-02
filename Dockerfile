# -----------------------------------------------------------------------------
# Kilo adapter.
#
# The OS layer, the web terminal, tini, and the /etc/agent/config.yaml ETL all
# live in coding-runtime. What is left here is the Kilo CLI plus the
# files that describe it to the base: a manifest, an emitter, and two
# launchers (the interactive TUI, and a task-mode run).
#
# The base is pinned by tag *and* digest. Never :latest, and never a `main`
# build — metadata-action stamps those with the version literal `main`, which no
# `requires.codingRuntime` range can satisfy, so every boot would warn about a
# version mismatch that is not real.
# -----------------------------------------------------------------------------
ARG BASE=ghcr.io/language-operator/coding-runtime:0.1.6@sha256:318a540d9d062689d3ed6c0de34fb353ff076bb16c5770bcf296398c6e5a5412
ARG KILO_VERSION=7.8.3

FROM ${BASE}
ARG KILO_VERSION

# Kilo CLI (TUI). The npm package fetches the platform-native binary on
# install. Pinned — do not track `latest`, so runtime behaviour is reproducible.
USER root
RUN npm install -g --no-audit --no-fund "@kilocode/cli@${KILO_VERSION}" \
    && npm cache clean --force

# runtime.json  — what this adapter is: config dir, serving surface, tmux launch.
# emit.mjs      — normalized operator config -> kilo.jsonc.
# launch-kilo      — what tmux runs inside the terminal.
# launch-kilo-task — what a task-mode run executes, to completion.
COPY runtime.json /etc/coding-runtime/runtime.json
COPY emit.mjs /opt/adapter/emit.mjs
COPY --chmod=755 launch-kilo.sh /usr/local/bin/launch-kilo
COPY --chmod=755 launch-kilo-task.sh /usr/local/bin/launch-kilo-task

# The operator pins the agent container to uid 1000 with no override, and the
# base already has a matching passwd entry. Do not create a user here.
USER node
