# coustomed environment variable
export CRYPTOGRAPHY_OPENSSL_NO_LEGACY=1
#export PATH="$PATH:/opt/miniconda3/condabin/"
export INODE="/home/zxf/iNode/Linux/iNodeManager/iNodeSetup/iNodeClient"
export LIBINPUT_ACCEL_PROFILE=flat
export LIBINPUT_NATURAL_SCROLL_ENABLED=1
export PATH="$PATH:/home/zxf/cplay"
# 私有设置（内网主机 / 别名等），存放在 ~/.config/dotfiles-private/，不入公开仓库
[ -r "$HOME/.config/dotfiles-private/env.sh" ] && . "$HOME/.config/dotfiles-private/env.sh"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export PATH="$PATH:/opt/cuda/bin"
export LD_LIBRARY_PATH="$PATH:/opt/cuda/lib"
export PATH="/usr/lib/ccache/bin:$PATH"

export AM_HOME=/home/zxf/workspace/Project/Learn/ics-pa/abstract-machine

export NEMU_HOME=/home/zxf/workspace/Project/Learn/ics-pa/nemu
