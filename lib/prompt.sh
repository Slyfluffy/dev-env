#!/usr/bin/env bash
# shellcheck disable=SC2034

configure_bash_prompt() {
  local bashrc="${HOME}/.bashrc"
  local temporary_file bashrc_mode bashrc_uid bashrc_gid
  local acl_file='' attr_file=''

  # The marker makes repeated runs idempotent and avoids duplicating PS1 code.
  if "$DRY_RUN"; then
    log "would configure ${bashrc} with the colored Git-aware prompt"
    return
  fi

  [[ ! -L "$bashrc" ]] || die "refusing to modify symlinked ${bashrc}"
  touch "$bashrc"
  read -r bashrc_mode bashrc_uid bashrc_gid < <(stat -c '%a %u %g' "$bashrc")
  if grep -Fq "$PROMPT_START" "$bashrc"; then
    log "Bash prompt already configured in ${bashrc}"
    return
  fi

  temporary_file=$(mktemp "${bashrc}.XXXXXX")
  PROMPT_TEMP_FILE=$temporary_file
  if command -v getfacl >/dev/null 2>&1 &&
    command -v setfacl >/dev/null 2>&1; then
    acl_file="$TEMP_DIR/bashrc.acl"
    getfacl --absolute-names "$bashrc" >"$acl_file"
  fi
  if command -v getfattr >/dev/null 2>&1 &&
    command -v setfattr >/dev/null 2>&1 &&
    getfattr --absolute-names --dump "$bashrc" >"$TEMP_DIR/bashrc.attrs" 2>/dev/null; then
    attr_file="$TEMP_DIR/bashrc.attrs"
  fi
  cat "$bashrc" >"$temporary_file"
  cat >>"$temporary_file" <<'EOF'

# >>> dev-env prompt >>>
_dev_env_prompt() {
    local reset='\[\e[0m\]'
    local user_color path_color branch_color branch

    if (( EUID == 0 )); then
        user_color='\[\e[31m\]'
        path_color='\[\e[31m\]'
    else
        user_color='\[\e[32m\]'
        path_color='\[\e[34m\]'
    fi

    branch_color='\[\e[33m\]'
    branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
    PS1="${user_color}\u@\h${reset}:${path_color}\w${reset}"
    PS1+='\$'
    [[ -n "$branch" ]] && PS1+=" ${branch_color}[${branch}]${reset}"
    PS1+=" "
}
PROMPT_COMMAND="_dev_env_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
# <<< dev-env prompt <<<
EOF
  chmod "$bashrc_mode" "$temporary_file"
  chown "$bashrc_uid:$bashrc_gid" "$temporary_file"
  mv -f "$temporary_file" "$bashrc"
  if [[ -n "$acl_file" ]]; then
    setfacl --restore="$acl_file" "$bashrc"
  fi
  if [[ -n "$attr_file" ]]; then
    setfattr --restore="$attr_file"
  fi
  PROMPT_TEMP_FILE=
  log "configured ${bashrc}"
}
