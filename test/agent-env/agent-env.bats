#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load ../helpers
  source "$SHIMMER_DIR/lib/agent-env.sh"
}

@test "agent env: preserves identity while scrubbing task-scoped env" {
  export GIT_AUTHOR_NAME="c0da"
  export GIT_AUTHOR_EMAIL="c0da@ricon.family"
  export AGENT_IDENTITY="You are c0da."
  export GH_TOKEN="ghp_identity_token"
  export CALLER_PWD="/stale/caller"
  export SHIMMER_CALLER_PWD="/stale/shimmer"
  export OTHER_CALLER_PWD="/stale/other"
  export MISE_CONFIG_ROOT="/stale/shimmer"
  export MISE_ORIGINAL_CWD="/stale/original"
  export MISE_PROJECT_ROOT="/stale/project"
  export MISE_TASK_NAME="agent"
  export MISE_TASK_FILE="/stale/task"

  shimmer_prepare_agent_child_env

  [ "${GIT_AUTHOR_NAME}" = "c0da" ]
  [ "${GIT_AUTHOR_EMAIL}" = "c0da@ricon.family" ]
  [ "${AGENT_IDENTITY}" = "You are c0da." ]
  [ "${GH_TOKEN}" = "ghp_identity_token" ]
  [ -z "${CALLER_PWD-}" ]
  [ -z "${SHIMMER_CALLER_PWD-}" ]
  [ -z "${OTHER_CALLER_PWD-}" ]
  [ -z "${MISE_CONFIG_ROOT-}" ] # codebase:ignore mcr-scope — test asserts scrubbed env
  [ -z "${MISE_ORIGINAL_CWD-}" ]
  [ -z "${MISE_PROJECT_ROOT-}" ]
  [ -z "${MISE_TASK_NAME-}" ]
  [ -z "${MISE_TASK_FILE-}" ]
}

@test "agent env: prunes stale duplicate mise install dirs by tool key" {
  export HOME="$BATS_TEST_TMPDIR/home"
  local installs="$HOME/.local/share/mise/installs"
  local old_sessions="$installs/shiv-sessions/0.4.1/bin"
  local new_sessions="$installs/shiv-sessions/0.4.3/bin"
  local old_threads="$installs/shiv-threads/0.2.1/bin"
  local new_threads="$installs/shiv-threads/0.3.0/bin"

  export PATH="/usr/bin:/bin:$old_sessions:/custom/bin:$new_sessions:$old_threads:$new_threads:/tail/bin"

  shimmer_prune_mise_install_path_duplicates

  [[ ":$PATH:" != *":$old_sessions:"* ]]
  [[ ":$PATH:" != *":$old_threads:"* ]]
  [[ ":$PATH:" == *":$new_sessions:"* ]]
  [[ ":$PATH:" == *":$new_threads:"* ]]
  [[ ":$PATH:" == *":/custom/bin:"* ]]
  [[ ":$PATH:" == *":/tail/bin:"* ]]
}

@test "agent env: keeps non-duplicate mise install dirs" {
  export HOME="$BATS_TEST_TMPDIR/home"
  local installs="$HOME/.local/share/mise/installs"
  local only_sessions="$installs/shiv-sessions/0.4.3/bin"
  local only_notes="$installs/shiv-notes/0.8.8/bin"

  export PATH="$only_sessions:/usr/bin:/bin:$only_notes"

  shimmer_prune_mise_install_path_duplicates

  [[ ":$PATH:" == *":$only_sessions:"* ]]
  [[ ":$PATH:" == *":$only_notes:"* ]]
  [[ ":$PATH:" == *":/usr/bin:"* ]]
}

@test "agent env: preserves multiple entries for the selected mise install version" {
  export HOME="$BATS_TEST_TMPDIR/home"
  local installs="$HOME/.local/share/mise/installs"
  local old_elixir="$installs/elixir/1.18/bin"
  local new_elixir_bin="$installs/elixir/1.19/bin"
  local new_elixir_mix="$installs/elixir/1.19/.mix/escripts"

  export PATH="$old_elixir:/usr/bin:/bin:$new_elixir_bin:$new_elixir_mix"

  shimmer_prune_mise_install_path_duplicates

  [[ ":$PATH:" != *":$old_elixir:"* ]]
  [[ ":$PATH:" == *":$new_elixir_bin:"* ]]
  [[ ":$PATH:" == *":$new_elixir_mix:"* ]]
}
