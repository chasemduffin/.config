eval "$(oh-my-posh init zsh)"

eval "$(oh-my-posh init zsh --config ~/src-local/.config/oh-my-posh/themes/everforest.omp.json)"

# https://superuser.com/questions/585003/searching-through-history-with-up-and-down-arrow-in-zsh
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

#arrow key binds
bindkey "^[[A" up-line-or-beginning-search # Up
bindkey "^[[B" down-line-or-beginning-search # Down
bindkey "^[[1;3C" forward-word # Forward
bindkey "^[[1;3D" backward-word # Backward


## -- autocompletions
# https://stackoverflow.com/questions/24513873/git-tab-completion-not-working-in-zsh-on-mac
# https://medium.com/@dannysmith/little-thing-2-speeding-up-zsh-f1860390f92
autoload -Uz compinit
for dump in ~/.zcompdump(N.mh+24); do
  compinit
done
compinit -C

export PATH=~/anaconda3/bin:$PATH

export FZF_COMPLETION_OPTS="'--border --tiebreak=chunk"export PATH="$HOME/.tgenv/bin:$PATH"
export TENV_AUTO_INSTALL=true
export TERRAGRUNT_TFPATH=terraform

# History Options
HISTFILE=~/.zsh_history
HISTSIZE=999999999
SAVEHIST=$HISTSIZE
setopt INC_APPEND_HISTORY # Appends history incrementally as commands are finished
setopt SHARE_HISTORY      # Shares history across multiple Zsh sessions
setopt EXTENDED_HISTORY   # Adds timestamps to history entries


# CLI auto catch
# Faster wrapper - streams output normally, only checks stderr for SSO errors
_aws_sso_auto_login_wrapper() {
    local cmd_name="$1"
    shift
    
    local stderr_file=$(mktemp)
    
    # Run command normally, but capture ONLY stderr to check for SSO error
    # stdout flows through normally (fast!)
    command "$cmd_name" "$@" 2> >(tee "$stderr_file" >&2)
    local exit_code=$?

    # Only check the file if command failed
    local sso_expired_patterns=(
        "the SSO session has expired"
        "The SSO session associated with this profile has expired"
    )
    if [[ $exit_code -ne 0 ]] && grep -qE "$(printf '%s|' "${sso_expired_patterns[@]}" | sed 's/|$//')" "$stderr_file"; then
        local profile=""
        local args=("$@")
        for i in {1..${#args[@]}}; do
            if [[ "${args[$i]}" == "--profile" ]]; then
                profile="${args[$((i+1))]}"
                break
            elif [[ "${args[$i]}" == --profile=* ]]; then
                profile="${args[$i]#--profile=}"
                break
            fi
        done
        profile="${profile:-${AWS_PROFILE:-}}"

        local login_args=()
        if [[ -n "$profile" ]]; then
            login_args=(--profile "$profile")
        fi

        echo "🔄 Detected expired SSO session${profile:+ for profile '$profile'}. Logging in..." >&2

        if aws sso login "${login_args[@]}"; then
            echo "✅ Login successful. Retrying command..." >&2
            rm "$stderr_file"
            command "$cmd_name" "$@"
            return $?
        fi
    fi

    rm "$stderr_file"
    return $exit_code
}

# Apply to AWS-related commands
for cmd in terragrunt terraform aws; do
    eval "function $cmd() { _aws_sso_auto_login_wrapper $cmd \"\$@\"; }"
done

# Find which configured AWS account owns an S3 bucket.
findbucket() {
  if [[ $# -ne 1 ]]; then
    print -u2 'Usage: findbucket BUCKET_NAME'
    return 2
  fi

  local bucket="$1" profile count account

  while IFS= read -r profile; do
    count=$(aws s3api list-buckets --profile "$profile" \
      --query "Buckets[?Name=='${bucket}'] | length(@)" --output text 2>/dev/null) || continue
    [[ "$count" == 1 ]] || continue

    account=$(aws sts get-caller-identity --profile "$profile" \
      --query Account --output text 2>/dev/null) || continue
    [[ -n "$account" ]] || continue
    print -r -- "$account"
    return 0
  done < <(aws configure list-profiles 2>/dev/null)

  print -u2 "No matching bucket found in accessible SSO profiles: $bucket"
  return 1
}
