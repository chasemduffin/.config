Edit .zshrc to the following:

```
source ~/.config/zshrc
```

# Installing brew packages
xargs -L1 brew install < <(awk '/^# casks$/{c=1; next} /^#/{next} NF {print (c ? "cask:" : "") $0}' brew-packages.txt | sed 's/^cask:/--cask /')
