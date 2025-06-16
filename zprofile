eval "$(oh-my-posh init zsh)"

eval "$(oh-my-posh init zsh --config ~/src-local/.config/oh-my-posh/themes/everforest.omp.json)"

# https://superuser.com/questions/585003/searching-through-history-with-up-and-down-arrow-in-zsh
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search # Up
bindkey "^[[B" down-line-or-beginning-search # Down

## -- autocompletions
# https://stackoverflow.com/questions/24513873/git-tab-completion-not-working-in-zsh-on-mac
# https://medium.com/@dannysmith/little-thing-2-speeding-up-zsh-f1860390f92
autoload -Uz compinit
for dump in ~/.zcompdump(N.mh+24); do
  compinit
done
compinit -C

export PATH=~/anaconda3/bin:$PATH