# minimal-dots

> 我的 Arch Linux 极简配置备份 — **Hyprland · quickshell · nvim · tmux · pi**
>
> *Minimal, text-only dotfiles for Arch Linux + Hyprland. No binaries, no secrets.*

**178 个文本文件 · 约 640 KB · 0 个二进制 · 0 个密钥**

---

## 这是什么

一份"机器挂了能 5 分钟复活"的配置备份。**只存文本配置**，不存缓存、不存插件本体、不存密钥。

**它解决什么**：重装系统后不用一个个回忆"当年 hyprland.conf 里那行是啥"。
**它不解决什么**：不是系统镜像。软件包靠 `pkglist*.txt` 重装，插件靠各自的包管理器重装。

## 里面有什么

| 分类 | 内容 | 文件数 |
|---|---|---|
| **窗口管理** | `.config/hypr/`（`hyprland.lua` / `hyprland.conf` / `hyprlock.conf`） | 8 |
| **状态栏** | `.config/quickshell/`（QML 写的顶栏：workspace / cpu / 内存 / 托盘 / 电源菜单） | 23 |
| **桌面配套** | `waybar` · `rofi`(23) · `dunst`(32) · `wofi` · `wlogout` · `mako` · `swaylock` · `fuzzel` · `hyde` | 70 |
| **终端** | `kitty` · `fish` · `btop` · `cava` · `fastfetch` · `starship` · `.zshrc` · `.p10k.zsh` · `.bashrc` | 16 |
| **编辑器** | `.config/nvim/`（`init.lua` + `lua/` + `lazy-lock.json`）· `.vimrc` · `coc-settings.json` | 21 |
| **tmux** | `.tmux.conf`（`C-a` 前缀、vi 复制模式、catppuccin） | 1 |
| **脚本** | `.scripts/`（截图 / 锁屏 / 焦点 / 功耗）· `.local/bin/` | 8 |
| **pi** | `.pi/agent/`（agents / extensions / skills / settings） | 20 |
| **包清单** | `.config/pkglist.txt`（375 个官方包）· `pkglist-aur.txt`（160 个 AUR 包） | 2 |

> 显示器名 `eDP-1` / `HDMI-A-1`、光标 `Bibata-Modern-Classic`、键盘 `caps:swapescape`
> —— 这些是机器相关的，搬到别的机器上要自己改。

## 为什么是 bare repo，而不是 stow / chezmoi

```
$HOME  ←  work-tree
~/.dotfiles  ←  git-dir（bare）
```

配置文件**待在原地不动**：没有软链接、没有 `~` 外的仓库、没有"装个工具才能用"的前置依赖。
代价是 `.config/nvim` 和 `.config/quickshell` 里各自还有一个 `.git`（上游仓库），
`git add` 会把它们当 submodule 而**静默跳过**，所以备份脚本用
`hash-object -w` + `update-index --index-info` 直写索引绕过。

---

## 新机器上恢复

> ⚠️ **这一段请抄到手机/邮箱/密码管理器。**
> 脚本和数据都在会坏的那台机器里，只有你脑子外的副本靠得住。

```bash
# 1) 装 git
sudo pacman -S --needed git

# 2) 克隆 bare 仓库（公开仓库，这一步不需要任何凭据）
git clone --bare https://github.com/bfishT/minimal-dots.git "$HOME/.dotfiles"
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config core.bare false
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config core.worktree "$HOME"
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config status.showUntrackedFiles no

# 3) 还原配置（注意：不要写成 `checkout -f -- .`，那样会 pathspec 报错）
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" checkout -f

# 4) 之后 dotrestore / dotsave 就已经就位了
dotrestore -n    # 预演，看看会覆盖什么
```

要往这个仓库 **push** 才需要 SSH key：

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
# 放回 id_ed25519，然后：
chmod 600 ~/.ssh/id_ed25519
ssh -T git@github.com          # 应显示 Hi bfishT!
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" remote set-url origin \
    git@github.com:bfishT/minimal-dots.git
```

### 恢复后还要做的

1. **API key**：`cp ~/.pi/agent/models.example.json ~/.pi/agent/models.json`，填回各 provider 的 `apiKey`；`auth.json` 不进仓库，用 pi 的 `/login` 重新登录
2. **私有值**：重建 `~/.config/dotfiles-private/env.sh`（见下方"私有值"一节）
3. **git 身份**：`git config --global user.name <名字>` + `git config --global user.email <邮箱>`
4. **软件包**：`sudo pacman -S --needed - < ~/.config/pkglist.txt`，AUR 用 `yay -S --needed - < ~/.config/pkglist-aur.txt`
5. **nvim 插件**：`nvim` 里执行 `:Lazy restore`
6. **tmux 插件**：启动 tmux 后按 `prefix + I`（prefix 是 `C-a`）
7. **kitty 主题库**（上游仓库，未备份）：
   `git clone --depth=1 https://github.com/kovidgoyal/kitty-themes ~/.config/kitty/kitty-themes`
8. **字体/光标**：`bibata-cursor-theme`、`ttf-jetbrains-mono-nerd`、`noto-fonts-cjk` 等
9. **HyDE 主题**（`~/.config/hyde/themes` 206MB，未备份）：重新跑其安装器

---

## 日常使用

```bash
dsave                  # 核心命令：扫白名单 → 三道安全检查 → commit → push
dsave -n               # 先看会备份什么（dry-run）
dsave -m "改了窗口间隙"  # 自定义提交信息
dsave --no-push        # 只本地提交
dsave --list           # 打印白名单根路径

dot status             # 白名单内哪些文件改动了（不显示未跟踪文件）
dot log --oneline      # 备份历史
dot diff               # 具体改了啥

dotrestore -n          # 预演恢复：列出会被覆盖的文件
dotrestore -y          # 就地恢复（覆盖前自动备份旧文件）
```

`dot` 是别名：`git --git-dir=$HOME/.dotfiles --work-tree=$HOME`（在 `.zshrc` 里）。

就地恢复时，`$HOME` 里被覆盖的旧文件会先存到
`~/.dotfiles-restore-backup-<时间戳>/`，随时可回滚。

## 三道安全检查

公开仓库最怕手滑把 key 推上去，所以 `dsave` 每次提交前都会拦：

| 检查 | 拦什么 | 命中后 |
|---|---|---|
| **A. 路径** | `auth.json` · `models.json` · `.ssh/` · `.codex/` · `.cc-switch/` · `.git-credentials` · `.netrc` · `id_rsa` … | 取消全部暂存并退出 |
| **B. 密钥** | `sk-…` · `ghp_…` · `github_pat_…` · `AKIA…` · `AIza…` · `xox…` · PEM 私钥头（`BEGIN … PRIVATE KEY`） | 取消全部暂存并退出 |
| **C. 体积** | 暂存内容合计 > 50 MB | 取消全部暂存并退出 |

外加 `~/.dotfiles/info/exclude` 一层排除清单兜底。

> 已实测：植入 `auth.json` / 伪造 `sk-…` / 塞 60MB 文件，三种情况都被拦下并回滚。
>
> ⚠️ 注意：守卫只能防"以后"的失误。**一旦密钥真的 push 过，删文件是不够的**——
> 必须立刻轮换密钥 + `git filter-repo` 清洗历史。

## 不入库的东西

| 类别 | 例子 | 为什么 |
|---|---|---|
| **密钥/凭据** | `.pi/agent/{auth.json,sessions/}` · `.ssh/` · `.gnupg/` · `.git-credentials` · `.codex/` · `.cc-switch/` | 公开仓库 |
| **克隆来的仓库** | `kitty-themes/` · `.config/{nvim,quickshell}/.git` · `.pi/agent/git/` | `git clone` 即可还原 |
| **大体积资源** | `.icons`(1.2G) · `.config/hyde/themes`(206M) · `.themes`(53M) · `~/.config/{QQ,SPlayer,LarkShell,google-chrome,...}` | 与配置无关 |
| **二进制** | `.local/bin/ketch`(20M) · `waybar-splayer`(编译产物) | 装回来的 |
| **缓存/日志** | `*.log` `*.bak` `*.old` `*.zwc` `.bash_history` `__pycache__` | 噪声 |

## 私有值：`~/.config/dotfiles-private/env.sh`

内网主机名、用户名、SSH 别名这类"公开出去不太合适"的值，全部集中在一个**未跟踪**文件里，
由 `.bashrc`、`.scripts/lock-all.sh`、`.local/bin/pushclipboard` 主动 source：

```bash
alias pac="ssh <user>@<host>"          # 内网 SSH 快捷别名
export CLIPBOARD_TARGET="user@host"    # pushclipboard 默认目标
export LOCK_HOST="user@host"           # lock-all.sh 联动锁屏（为空则只锁本机）
```

仓库里的三个文件都写成了"**有就 source、没有就降级**"的形式，所以缺了它不会报错。

## 密钥处理：`models.example.json`

`~/.pi/agent/models.json` 里有真实 API key，**永久排除**。仓库只存脱敏模板：

```bash
# 重建模板（改了 provider 列表后）
sed 's/"apiKey": "sk-[^"]*"/"apiKey": ""/' \
    ~/.pi/agent/models.json > ~/.pi/agent/models.example.json
dsave -m "update models template"
```

## 目录结构

```
$HOME/
├── .github/README.md          ← 你正在看的这个文件
├── .zshrc .bashrc .p10k.zsh .tmux.conf .vimrc .gitconfig
├── .config/
│   ├── hypr/                  Hyprland + hyprlock（.lua 是新版配置）
│   ├── quickshell/            QML 状态栏
│   ├── waybar/ rofi/ dunst/ wofi/ fuzzel/ wlogout/ mako/ swaylock/ hyde/
│   ├── nvim/                  init.lua + lua/ + lazy-lock.json
│   ├── kitty/ btop/ cava/ fastfetch/ fish/ ketch/
│   └── pkglist.txt pkglist-aur.txt
├── .scripts/                  截图 / 锁屏 / 焦点 / 功耗
├── .local/bin/                dotsave · dotrestore · pushclipboard
└── .pi/agent/                 AGENTS.md · agents/ · extensions/ · skills/
```

## 需要离线保管（git 管不了）

| 项目 | 建议 |
|---|---|
| `~/.ssh/id_ed25519` | 手机 / U 盘 / 密码管理器 —— 丢了就 push 不了 |
| GPG 私钥、GitHub PAT | 密码管理器 |
| **本 README 的"新机器恢复"一节** | 手机备忘录 / 邮件草稿 |
| `~/.config/dotfiles-private/env.sh` 内容 | 密码管理器 |

## License

个人配置文件，随便看、随便抄。
没有附正式 License，所以按默认"保留所有权利"处理 —— 如果你要复用，开个 issue 说一声就行。
