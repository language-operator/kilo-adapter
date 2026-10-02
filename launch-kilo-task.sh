#!/bin/sh
# What a task-mode agent runs (AGENT_EXECUTION_MODE=task). The base runs this to
# completion and exits with its code, which becomes the run's phase: 0 is
# Succeeded, anything else is Failed.
#
# The prompt is the agent's instructions, written to $KILO_CONFIG_DIR/task.md by
# `coding-runtime seed`; the model, provider, MCP servers and standing context
# come from kilo.jsonc beside it, exactly as for the TUI. It goes in on stdin
# rather than as an argument, so long instructions cannot hit the per-argument
# size limit.
#
# --auto approves every permission not explicitly denied: there is nobody to
# answer a prompt in a task run, and an unanswered one would hang until
# activeDeadlineSeconds. --format json makes the pod log one event per line.
#
# Exit codes are kilo's own: 0 when the run completes, 1 on an error (a bad
# model name, an unreachable gateway). A run killed by SIGTERM from
# activeDeadlineSeconds is reported by the base as 128 + signal.
set -eu

task="$KILO_CONFIG_DIR/task.md"
if [ ! -s "$task" ]; then
    echo "launch-kilo-task: $task is empty — a task-mode agent needs spec.instructions" >&2
    exit 1
fi

exec kilo run --auto --format json < "$task"
