# Refresh the local OpenAI key cache from 1Password at most once per week.

_load_api_keys() {
  local secrets_file="$HOME/.zsh_secrets"
  local max_age_days=7

  if [[ -f "$secrets_file" ]]; then
    local file_age=$(( ($(date +%s) - $(stat -f %m "$secrets_file")) / 86400 ))
    if (( file_age < max_age_days )); then
      source "$secrets_file"
      return
    fi
  fi

  if ! command -v op >/dev/null 2>&1 || ! op whoami >/dev/null 2>&1; then
    [[ -f "$secrets_file" ]] && source "$secrets_file"
    return
  fi

  print "[API Keys] refreshing OPENAI_API_KEY from 1Password…"
  local openai_key
  openai_key="$(op read op://Personal/ChatGPT.nvim/password --no-newline)"
  print -r -- "export OPENAI_API_KEY=\"$openai_key\"" > "$secrets_file"
  chmod 600 "$secrets_file"
  source "$secrets_file"
}
