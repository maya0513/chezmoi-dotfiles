# ~/chezmoi-dotfiles/justfile

set shell := ["bash", "-euc"]

# `just` だけで一覧を表示
default:
    @just --list


# ---------------------------------------------------------------------------
# Upgrade
# ---------------------------------------------------------------------------

# APT、Snap、mise、Godot、Blender、Nixを順番に更新
upgrade:
    sudo apt update && sudo apt upgrade -y && sudo snap refresh && mise self-update -y && mise upgrade && just godot && just godot-doctor && just b3d && just b3d-doctor && nix flake update && just nix-switch


# ---------------------------------------------------------------------------
# Nix
# ---------------------------------------------------------------------------

# Nix flake をフォーマット
nix-fmt:
    nix fmt

# Nix flake の評価・checksを確認
nix-check:
    nix flake check --impure path:.

# result symlink は作らない
# Nix の base-env を実際にビルドする
nix-build:
    nix build --impure path:.#default --no-link

# build が成功してから既存 base-env を入れ替える。
# 現在の Nix flake をユーザープロファイルへ反映
nix-switch: nix-check nix-build
    nix profile remove chezmoi-dotfiles 2>/dev/null || true
    nix profile add --impure path:.#default

# 現在の Nix flake をユーザープロファイルへ同期
nix-sync: nix-switch

# Git で dotfiles repo を pull して Nix 環境を同期
nix-pull:
    git pull --ff-only
    just nix-sync

# 現在の Nix profile を表示
nix-profile:
    nix profile list

# 直前の Nix profile に戻す
nix-rollback:
    nix profile rollback

# Nix store全体の未参照pathを削除せず確認
nix-gc-check:
    nix store gc --dry-run

# Nix store全体の未参照pathを削除（profile履歴は保持）
nix-gc:
    nix store gc


# ---------------------------------------------------------------------------
# Applications
# ---------------------------------------------------------------------------

# Godot の最新版、または指定バージョンをインストールして有効化
godot version="latest":
    version="$(./godot/install.sh "{{version}}")"; ./godot/use.sh "$version"

# Godot をインストール（有効化はしない）
godot-install version="latest":
    ./godot/install.sh "{{version}}"

# インストール済み Godot の有効バージョンを切り替え
godot-use version:
    ./godot/use.sh "{{version}}"

# 非アクティブな Godot をアンインストール
godot-uninstall version:
    ./godot/uninstall.sh "{{version}}"

# 有効な Godot のバージョンを表示
godot-current:
    ./godot/current.sh

# インストール済み Godot の一覧を表示
godot-list:
    ./godot/list.sh

# Godot のローカル構成を変更せず診断
godot-doctor:
    ./godot/doctor.sh

# Blender の最新版、または指定バージョンをインストールして有効化
b3d version="latest":
    version="$(./blender/install.sh "{{version}}")"; ./blender/use.sh "$version"

# Blender をインストール（有効化はしない）
b3d-install version="latest":
    ./blender/install.sh "{{version}}"

# インストール済み Blender の有効バージョンを切り替え
b3d-use version:
    ./blender/use.sh "{{version}}"

# 非アクティブな Blender をアンインストール
b3d-uninstall version:
    ./blender/uninstall.sh "{{version}}"

# 有効な Blender のバージョンを表示
b3d-current:
    ./blender/current.sh

# インストール済み Blender の一覧を表示
b3d-list:
    ./blender/list.sh

# Blender のローカル構成を変更せず診断
b3d-doctor:
    ./blender/doctor.sh


# ---------------------------------------------------------------------------
# chezmoi
# ---------------------------------------------------------------------------

# chezmoi の適用前差分を表示
chz-diff:
    chezmoi diff

# chezmoi 管理下の dotfiles を $HOME に反映
chz-apply:
    chezmoi apply

# chezmoi 管理対象の状態を表示
chz-status:
    chezmoi status

# 例:
#   just chz-add ~/.gitconfig
# ファイルを chezmoi 管理下へ追加
chz-add path:
    chezmoi add "{{path}}"

# 例:
#   just chz-edit ~/.zshrc
# chezmoi 管理ファイルを編集
chz-edit path:
    chezmoi edit "{{path}}"

# 現在の chezmoi 管理下の dotfiles を $HOME へ同期
chz-sync: chz-apply

# Git で dotfiles repo を pull して chezmoi 管理下の dotfiles を同期
chz-pull:
    git pull --ff-only
    just chz-sync


# ---------------------------------------------------------------------------
# Git
# ---------------------------------------------------------------------------

# Git repo 自体の状態を表示
git-status:
    git status --short
