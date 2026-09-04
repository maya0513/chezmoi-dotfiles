# ~/chezmoi-dotfiles/justfile

set shell := ["bash", "-euc"]

# `just` だけで一覧を表示
default:
    @just --list


# ---------------------------------------------------------------------------
# Nix
# ---------------------------------------------------------------------------

# flake.nix をフォーマット
fmt:
    nix fmt

# flake の評価・checksを確認
check:
    nix flake check

# base-env を実際にビルドする
# result symlink は作らない
build:
    nix build .#default --no-link

# 現在の flake をユーザープロファイルへ反映
#
# build が成功してから既存 base-env を入れ替える。
switch: check build
    nix profile remove chezmoi 2>/dev/null || true
    nix profile add .#default

# nixpkgs の lock を更新してから反映
upgrade:
    nix flake update
    just switch

# 現在の Nix profile を表示
profile:
    nix profile list

# 直前の Nix profile に戻す
rollback:
    nix profile rollback


# ---------------------------------------------------------------------------
# chezmoi
# ---------------------------------------------------------------------------

# 適用前の差分を見る
diff:
    chezmoi diff

# dotfiles を $HOME に反映
apply:
    chezmoi apply

# chezmoi 管理対象の状態を見る
status:
    chezmoi status

# ファイルを chezmoi 管理下へ追加
# 例:
#   just add ~/.gitconfig
add path:
    chezmoi add "{{path}}"

# chezmoi 管理ファイルを編集
# 例:
#   just edit ~/.zshrc
edit path:
    chezmoi edit "{{path}}"


# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

# Nix → chezmoi の順で現在のローカル設定をすべて反映
sync: switch
    chezmoi apply

# dotfiles repo を pull した後、
# Nix環境 → dotfiles の順で反映
pull:
    git pull --ff-only
    just sync

# repo 自体の状態
git-status:
    git status --short
