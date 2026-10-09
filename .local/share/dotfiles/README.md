# dotfiles — Arch Linux + Hyprland + nvim + pi

`$HOME` 直接作为 git work-tree 的配置备份（文件不搬动、不用软链接）。

- 备份仓库：`~/.dotfiles`（bare + `core.worktree=$HOME`）
- 远端：`git@github.com:bfishT/minimal-dots.git`（**公开仓库**）
- 备份命令：`dotsave`（= `~/.local/bin/dotsave`）
- 恢复命令：`dotrestore`（= `~/.local/bin/dotrestore`）
- 别名（在 `~/.zshrc`）：`dot` / `dsave` / `drestore`

---

## 0. ⚠️ 这台机器没了怎么办 —— 请把本节抄到手机/邮箱！

上面的脚本和数据都在坏掉的机器里，所以**必须**记住下面这几条：

```bash
# 1) 装 git
sudo pacman -S --needed git

# 2) 放回 SSH 私钥（在离线备份里），并修权限
mkdir -p ~/.ssh && chmod 700 ~/.ssh
# 把 id_ed25519 放进去
chmod 600 ~/.ssh/id_ed25519

# 3) 克隆 bare 仓库（把 bfishT/minimal-dots 换成你的）
git clone --bare git@github.com:bfishT/minimal-dots.git "$HOME/.dotfiles"
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config core.bare false
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config core.worktree "$HOME"
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config status.showUntrackedFiles no

# 4) 还原配置（注意：不要带 `-- .`）
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" checkout -f

# 5) 之后 dotrestore / dotsave 就有了，可继续用
dotrestore
```

HTTPS 替代方案（没带 SSH key 时）：
`git clone --bare https://github.com/bfishT/minimal-dots.git "$HOME/.dotfiles"`

> 备份仓库**不包含**：SSH 私钥、GPG key、API key、`~/.ssh/config`、
> 浏览器 profile、字体/图标主题、nvim/tmux 插件本体、HyDE 主题库。
> 这些要么重新登录生成，要么需要离线保管（见第 5 节）。

---

## 1. 日常用法

```bash
dsave                 # 备份：扫描白名单 -> 三道安全检查 -> commit -> push
dsave -m "改了什么"    # 自定义提交信息
dsave --no-push       # 只本地提交
dsave -n              # dry-run，只列出会备份的文件
dsave --list          # 打印白名单根路径

dot status            # 看有哪些白名单内文件被改动（不显示未跟踪文件）
dot log --oneline -20 # 看备份历史
dot diff              # 看具体改了啥

dotrestore -n         # 预演恢复（列出会被覆盖的文件）
dotrestore -y         # 就地恢复（会覆盖 $HOME 里的同名文件）
```

恢复时若有文件被覆盖，旧文件会先备份到
`~/.dotfiles-restore-backup-<时间戳>/`。

---

## 2. dotsave 的三道安全检查（公开仓库的安全阀）

| 检查 | 内容 | 命中后 |
|---|---|---|
| A. 路径 | 暂存区不能出现 `auth.json` / `models.json` / `.ssh/` / `.codex/` / `.cc-switch/` / `.git-credentials` 等 | 取消全部暂存并退出 |
| B. 密钥 | 暂存内容里不能出现 `sk-…` / `ghp_…` / `github_pat_…` / `AKIA…` / `BEGIN PRIVATE KEY` | 取消全部暂存并退出 |
| C. 体积 | 暂存内容合计 > 50MB | 取消全部暂存并退出 |

另外 `~/.dotfiles/info/exclude` 里还有一层排除清单，防止手滑 `dot add -A`。

---

## 2.5 私有值：`~/.config/dotfiles-private/env.sh`

内网主机名 / 用户名 / SSH 别名这类不适合公开的值，全部集中在这一个**未跟踪**文件里，
由 `.bashrc`、`.scripts/lock-all.sh`、`.local/bin/pushclipboard` 主动 source：

```bash
alias pac="ssh <user>@<host>"          # 原 .bashrc 里的内网别名
export CLIPBOARD_TARGET="user@host"   # pushclipboard 默认目标
export LOCK_HOST="user@host"          # lock-all.sh 联动锁屏主机（为空则只锁本机）
```

> 注意：这个文件 **不在仓库里**。新机器上需要重建（内容从密码管理器/备忘取）。
> 仓库里的 `.bashrc` / `lock-all.sh` / `pushclipboard` 都已改成
> “有就 source、没有就降级”的写法，所以缺了它不会报错。

---

## 3. 白名单范围

**在库内**（约 180 个文本文件，< 2MB）：

- shell：`.zshrc` `.bashrc` `.p10k.zsh` `.tmux.conf` `.vimrc` `.gitconfig`
- 桌面：`.config/{hypr,quickshell,waybar,mako,swaylock,dunst,wlogout,wofi,rofi}`、
  `.config/fuzzel/fuzzel.ini`、`.config/hyde/hyde.conf`
- 终端：`.config/{kitty/kitty.conf,kitty/theme.conf,fish,btop,cava}`、
  `.config/fastfetch/config.jsonc`、`.config/starship.toml`
- 编辑器：`.config/nvim/{init.lua,lua/,lazy-lock.json,.vim/coc-settings.json}`
- 脚本：`.scripts/`、`.local/bin/{dotsave,dotrestore,pushclipboard}`
- pi：`.pi/agent/{AGENTS.md,settings.json,keybindings.conf,keybindings.json,`
  `models.example.json,agents/,extensions/,skills/}`
- 杂项：`.config/{user-dirs.dirs,mimeapps.list,ketch}`、
  `.config/{pkglist.txt,pkglist-aur.txt}`（包清单）

**不在库内、但需要本机存在的东西**（丢了不致命）：

- `~/.config/git/config` —— git 提交身份（name/email）。
  公开仓库不想暴露邮箱，所以身份放在这个未跟踪文件里，
  `~/.gitconfig` 只留 proxy / lfs / core.editor。
  新机器上执行：`git config --global user.name <你的名字>` +
  `git config --global user.email <你的邮箱>`
- `~/.config/dotfiles-private/env.sh` —— 内网主机、SSH 别名等私有值（见第 2.5 节）

**明确不在库内**：

- 密钥/凭据：`.pi/agent/{auth.json,models.json,sessions/,git/}`、`.ssh/`、`.gnupg/`、
  `.git-credentials`、`.codex/`、`.cc-switch/`、`.local/share/opencode/`
- 克隆来的仓库：`kitty-themes/`、`.config/nvim/.git`、`.config/quickshell/.git`、
  `.pi/agent/git/`、`.config/fuzzel/fuzzel/`
- 大体积资源：`.icons`(1.2G)、`.themes`(53M)、`.config/hyde/themes`(206M)、
  `~/.config/{QQ,SPlayer,LarkShell,google-chrome,Code,...}`、各类缓存
- 二进制：`.local/bin/ketch`(20M)、`.config/waybar/scripts/waybar-splayer`
- 日志/临时/备份：`*.log` `*.bak` `*.old` `*.zwc` `.bash_history` 等

---

## 4. 密钥处理：`models.json`

`~/.pi/agent/models.json` 里有真实 API key，**永久排除**。仓库里只存脱敏模板：

```bash
# 新机器上
cp ~/.pi/agent/models.example.json ~/.pi/agent/models.json
$EDITOR ~/.pi/agent/models.json      # 填回各 provider 的 "apiKey"
```

重建模板（改了 provider 列表后）：

```bash
sed 's/"apiKey": "sk-[^"]*"/"apiKey": ""/' \
    ~/.pi/agent/models.json > ~/.pi/agent/models.example.json
dsave -m "update models template"
```
`auth.json` 也不在仓库里 → 新机器上在 pi 里重新 `/login`。

### 已知的这些 key 还散落在（都未入库，但别乱传）

- `~/.pi/agent/models.json`
- `~/.pi/agent/sessions/*.jsonl`（10 个历史会话）
- `~/.codex/auth.json`
- `~/.cc-switch/cc-switch.db` + `~/.cc-switch/backups/*.db`
- `~/.local/share/opencode/opencode.db`

> 公开仓库一旦 push 过密钥，删文件是不够的，必须**轮换密钥** +
> `git filter-repo` 清历史。所以 push 前务必让 dotsave 的检查通过。

---

## 5. 需要单独离线保管的东西

这些丢了会很麻烦，git 备份管不了：

| 项目 | 建议 |
|---|---|
| `~/.ssh/id_ed25519`（GitHub 推送靠它） | 手机 / U 盘 / 密码管理器 |
| GPG 私钥、`~/.git-credentials` 的 token | 密码管理器 |
| 本节这份 README（第 0 节恢复步骤） | 手机备忘录 / 邮件草稿 |
| 浏览器 profile / 书签 | 浏览器自带同步 |

---

## 6. 恢复后还要做的

见 `dotrestore` 结束时的输出，摘要：

1. `cp models.example.json models.json` 并填 key（`auth.json` 用 pi 的 `/login`）
2. 重建私有值文件 `~/.config/dotfiles-private/env.sh`（见第 2.5 节）
3. 设置 git 身份（仓库里没存邮箱）：
   `git config --global user.name <名字>` + `git config --global user.email <邮箱>`
4. `sudo pacman -S --needed - < ~/.config/pkglist.txt`
   `yay -S --needed - < ~/.config/pkglist-aur.txt`
5. nvim 里 `:Lazy restore`
6. tmux 里 `prefix + I`（prefix = `C-a`）
7. `git clone --depth=1 https://github.com/kovidgoyal/kitty-themes ~/.config/kitty/kitty-themes`
8. 装字体/光标：`bibata-cursor-theme`、`ttf-jetbrains-mono-nerd` 等
9. 重装 HyDE（若用它的主题/wallbash）

---

## 7. 包清单（已在库内）

```bash
pacman -Qqe > ~/.config/pkglist.txt       # 显式安装的官方包（375 个）
pacman -Qqm > ~/.config/pkglist-aur.txt   # AUR 包（160 个）
dsave -m "update pkglist"
```

重装时 `pacman -S --needed - < ~/.config/pkglist.txt` 可以省几小时。
装了新包想刷新清单，就再跑上面这两条 + `dsave`。

## 8. 可选：第二副本

```bash
dot bundle create ~/backups/dotfiles.bundle --all
# 再把 bundle 拷到服务器/网盘，例如：
# scp ~/backups/dotfiles.bundle node1:~/
```
