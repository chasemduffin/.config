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
    if [[ $exit_code -ne 0 ]] && grep -q "the SSO session has expired" "$stderr_file"; then
        echo "🔄 Detected expired SSO session. Logging in..." >&2
        
        if aws sso login --profile gnr8-workspace; then
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
