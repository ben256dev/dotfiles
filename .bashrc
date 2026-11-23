# ~/.bashrc: executed by bash(1) for non-login shells.

# Prepend a directory to PATH if it exists and isn't already there, so nested
# shells (tmux, subshells) don't pile up duplicates.
path_prepend() {
    if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
        PATH="$1:$PATH"
    fi
}

# User-installed tools (v, uv tools, ...), needed in non-interactive shells too.
path_prepend "$HOME/.local/bin"

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Keep terminal colors enabled even when a parent process exports NO_COLOR.
unset NO_COLOR

# History: skip duplicates and lines starting with a space; append, don't overwrite.
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=50000
HISTFILESIZE=100000

shopt -s checkwinsize  # keep LINES/COLUMNS updated after each command
shopt -s globstar      # ** matches across directories

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;92m\]\u@\h\[\033[00m\]:\[\033[01;94m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
esac

# Colored ls/grep. Default colors, but bright blue directories and bright
# green executables.
if [ -x /usr/bin/dircolors ]; then
    eval "$(dircolors -b)"
    LS_COLORS="${LS_COLORS%:}:di=01;94:ex=01;92"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Machine-specific aliases that don't belong in the repo
if [ -f ~/.local_aliases ]; then
    . ~/.local_aliases
fi

path_prepend "$HOME/bin"
path_prepend "$HOME/.bin"

path_prepend "$HOME/.cargo/bin"

# annoying ass firefox warnings
alias firefox='G_MESSAGES_DEBUG=crit firefox 2>/dev/null'
path_prepend "$HOME/flutter/bin"

# fnm (Node version manager)
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
    path_prepend "$FNM_PATH"
    eval "$(fnm env)"
fi

# fzf
if [ -f /usr/share/doc/fzf/examples/key-bindings.bash.gz ]; then
    source <(zcat /usr/share/doc/fzf/examples/key-bindings.bash.gz)
elif [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
    source /usr/share/doc/fzf/examples/key-bindings.bash
fi

if [ -f /usr/share/doc/fzf/examples/completion.bash.gz ]; then
    source <(zcat /usr/share/doc/fzf/examples/completion.bash.gz)
elif [ -f /usr/share/doc/fzf/examples/completion.bash ]; then
    source /usr/share/doc/fzf/examples/completion.bash
elif [ -f /usr/share/bash-completion/completions/fzf ]; then
    source /usr/share/bash-completion/completions/fzf
fi

# No nvim at the prompt, as there's no vim: use v, which opens files in it
# (and won't open .env files). Scripts, v itself and git (core.editor) still
# run nvim, and so does command nvim.
nvim() {
    printf 'nvim: use v (or command nvim)\n' >&2
    return 127
}

# v ! pins terminal lines, and v !- (v ! -) or v !-3 should work too, but
# bash reads !- as history: an error, or !-3 quietly becomes the command
# three back. So Enter, on v's lines, first turns history expansion off
# (set +H), and the next prompt turns it back on. The line stays as typed.
#
# v ! lines (a ! among v's first words: v !-, v ~!, v -12 !; or v -v), in
# tmux, Enter runs itself, without readline's newline:
# copy mode opens with the screen as it was, and v puts the newline in
# after the lines are picked (V_NEWLINE). Enter is a macro, this function
# then \C-x\C-^, which it binds to accept-line, or for those lines to a
# no-op, the line already run.
if [[ $- == *i* ]]; then
    __v_enter() {
        bind '"\C-x\C-^": accept-line'
        [[ $READLINE_LINE =~ ^[[:space:]]*v[[:space:]] ]] || return 0
        if [ -n "${TMUX:-}" ] &&
            [[ $READLINE_LINE =~ ^[[:space:]]*v([[:space:]]+[-~0-9]+)*[[:space:]]+([-~0-9]*!|-v([[:space:]]|$)|--visual([[:space:]]|$)) ]]; then
            local line=$READLINE_LINE prompt=${PS1@P}
            history -s -- "$line"
            READLINE_LINE='' READLINE_POINT=0
            # Bash wipes the line before running this: put it back, without
            # PS1's \[ \] markers (\001 \002 once expanded).
            prompt=${prompt//$'\001'/}
            printf '%s%s' "${prompt//$'\002'/}" "$line"
            (export V_NEWLINE=1; eval "$line")
            bind '"\C-x\C-^": redraw-current-line'
            return 0
        fi
        set +H
        __v_history_was_off=1
    }
    __v_history_on() {
        [ -z "${__v_history_was_off:-}" ] || set -H
        unset __v_history_was_off
    }
    PROMPT_COMMAND+=(__v_history_on)
    bind -x '"\C-x\C-]": __v_enter'
    bind '"\C-x\C-^": accept-line'
    bind '"\C-m": "\C-x\C-]\C-x\C-^"'
fi
