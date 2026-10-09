export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=http://127.0.0.1:7890

export AM_HOME=/home/zxf/workspace/Project/Learn/ics-pa/abstract-machine

export NEMU_HOME=/home/zxf/workspace/Project/Learn/ics-pa/nemu
export CRYPTOGRAPHY_OPENSSL_NO_LEGACY=1
set -g fish_greeting

if status is-interactive
    starship init fish | source
end

# List Directory
alias l='eza -lh  --icons=auto' # long list
alias ls='eza -1   --icons=auto' # short list
alias ll='eza -lha --icons=auto --sort=name --group-directories-first' # long list all
alias ld='eza -lhD --icons=auto' # long list dirs
alias lt='eza --icons=auto --tree' # list folder as tree

# Handy change dir shortcuts
abbr .. 'cd ..'
abbr ... 'cd ../..'
abbr .3 'cd ../../..'
abbr .4 'cd ../../../..'
abbr .5 'cd ../../../../..'

# Always mkdir a path (this doesn't inhibit functionality to make a single dir)
abbr mkdir 'mkdir -p'

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
function condainit
    if test -f /opt/miniconda3/bin/conda
        eval /opt/miniconda3/bin/conda "shell.fish" "hook" $argv | source
    else
        if test -f "/opt/miniconda3/etc/fish/conf.d/conda.fish"
            . "/opt/miniconda3/etc/fish/conf.d/conda.fish"
        else
            set -x PATH "/opt/miniconda3/bin" $PATH
        end
    end
end
# <<< conda initialize <<<




fish_add_path /home/zxf/.local/bin

# opencode
fish_add_path /home/zxf/.opencode/bin

# cargo / rust
fish_add_path $HOME/.cargo/bin

# Composio CLI
set --export COMPOSIO_INSTALL_DIR "/home/zxf/.composio"
set --export PATH $COMPOSIO_INSTALL_DIR $PATH

# CUDA
set -xg PATH $PATH /opt/cuda/bin
set -xg INCLUDE_PATH $INCLUDE_PATH /opt/cuda/include
set -xg LD_LIBRARY_PATH $LD_LIBRARY_PATH /opt/cuda/lib64
set -xg CUDA_HOME /opt/cuda
