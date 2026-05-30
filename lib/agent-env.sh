#!/usr/bin/env bash
# Environment preparation for long-lived agent child processes.
#
# `shimmer agent` is itself a mise task, but the pi/sessions process it launches
# is a user-facing agent runtime. Task-scoped mise state should not leak into
# that runtime, while identity-bearing environment must remain intact.

shimmer_mise_data_dir() {
  if [ -n "${MISE_DATA_DIR:-}" ]; then
    printf '%s\n' "$MISE_DATA_DIR"
  elif [ -n "${XDG_DATA_HOME:-}" ]; then
    printf '%s\n' "$XDG_DATA_HOME/mise"
  elif [ -n "${HOME:-}" ]; then
    printf '%s\n' "$HOME/.local/share/mise"
  fi
}

shimmer_scrub_caller_pwd_env() {
  local name
  while IFS= read -r name; do
    case "$name" in
      CALLER_PWD|*_CALLER_PWD) unset "$name" ;;
    esac
  done < <(compgen -e)
}

shimmer_scrub_mise_task_env() {
  local name
  while IFS= read -r name; do
    case "$name" in
      # These describe the mise task currently launching the agent. Leaving them
      # set makes later direct tool/test invocations believe they still run from
      # shimmer's task root.
      MISE_CONFIG_ROOT|MISE_ORIGINAL_CWD|MISE_PROJECT_ROOT|MISE_TASK_*|usage_*) unset "$name" ;;
    esac
  done < <(compgen -e)
}

shimmer_mise_install_tool() {
  local entry="$1"
  local installs="$2"
  local rest

  case "$entry" in
    "$installs"/*/*)
      rest="${entry#"$installs"/}"
      printf '%s\n' "${rest%%/*}"
      ;;
  esac
}

shimmer_mise_install_version() {
  local entry="$1"
  local installs="$2"
  local rest tool version

  case "$entry" in
    "$installs"/*/*)
      rest="${entry#"$installs"/}"
      tool="${rest%%/*}"
      rest="${rest#"$tool"/}"
      version="${rest%%/*}"
      printf '%s\n' "$version"
      ;;
  esac
}

shimmer_selected_mise_install_version() {
  local tool="$1"
  local installs="$2"
  shift 2

  local entry entry_tool version
  while [ "$#" -gt 0 ]; do
    entry="$1"
    shift
    if ! entry_tool="$(shimmer_mise_install_tool "$entry" "$installs")"; then
      entry_tool=""
    fi
    [ "$entry_tool" = "$tool" ] || continue
    if ! version="$(shimmer_mise_install_version "$entry" "$installs")"; then
      version=""
    fi
    printf '%s\n' "$version"
  done | tail -1
}

# Collapse stale mise install PATH entries by tool name, keeping every entry for
# the last-seen version of each tool. This preserves ordinary inherited PATH
# entries and same-version multi-path tools (for example Elixir's bin plus
# .mix/escripts), while letting a later home-specific mise env overlay beat stale
# shimmer-launch tool dirs such as shiv-sessions/0.4.1 when shiv-sessions/0.4.3
# is also present later in PATH.
shimmer_prune_mise_install_path_duplicates() {
  local data_dir installs path_rest entry
  if ! data_dir="$(shimmer_mise_data_dir)"; then
    data_dir=""
  fi
  [ -n "$data_dir" ] || return 0

  installs="$data_dir/installs"
  path_rest="${PATH:-}:"
  local entries=()

  while [ -n "$path_rest" ]; do
    entry="${path_rest%%:*}"
    path_rest="${path_rest#*:}"
    entries+=("$entry")
  done

  local kept=() i tool version selected_version new_path
  for ((i = 0; i < ${#entries[@]}; i++)); do
    entry="${entries[$i]}"
    if ! tool="$(shimmer_mise_install_tool "$entry" "$installs")"; then
      tool=""
    fi

    if [ -n "$tool" ]; then
      if ! version="$(shimmer_mise_install_version "$entry" "$installs")"; then
        version=""
      fi
      if ! selected_version="$(shimmer_selected_mise_install_version "$tool" "$installs" "${entries[@]}")"; then
        selected_version=""
      fi
      [ "$version" != "$selected_version" ] && continue
    fi

    kept+=("$entry")
  done

  new_path=""
  for entry in ${kept[@]+"${kept[@]}"}; do
    if [ -z "$new_path" ]; then
      new_path="$entry"
    else
      new_path="$new_path:$entry"
    fi
  done
  export PATH="$new_path"
}

shimmer_prepare_agent_child_env() {
  shimmer_scrub_caller_pwd_env
  shimmer_scrub_mise_task_env
  shimmer_prune_mise_install_path_duplicates
}
