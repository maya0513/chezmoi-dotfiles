# Godot バージョン管理

Godot の公式 GitHub Releases から Linux x86_64 版を取得し、バージョン別に `/opt` へ
インストールする。Godot 本体は Nix、APT、chezmoi では管理しない。

## 配置

```text
/opt/godot/
├── <version>/
│   ├── godot
│   └── .managed-by-chezmoi-dotfiles
└── current -> <version>

/usr/local/bin/godot -> /opt/godot/current/godot
```

`current` と `/usr/local/bin/godot` はシステム全体で共有される。Godot 自身が使用する
`~/.local/share/godot` のユーザーデータには触れない。

## スクリプト

| ファイル | 役割 |
| --- | --- |
| `install.sh` | release の取得、SHA-512検証、`/opt/godot/<version>` への配置 |
| `use.sh` | インストール済みバージョンへの切り替え |
| `uninstall.sh` | 非アクティブな管理対象バージョンの削除 |
| `current.sh` | 現在有効なバージョンの表示 |
| `list.sh` | インストール済みバージョンの一覧表示 |
| `doctor.sh` | ローカル構成の読み取り専用診断 |
| `config.sh` | 配置先、実行ファイル名、バージョン形式の内部定義 |

共通のライフサイクル処理は `../lib/app-manager.sh`、共通の診断処理は
`../lib/app-doctor.sh` を使用する。

## 基本操作

### インストールして有効化

```bash
# 最新安定版
just godot

# 指定バージョン
just godot 4.7.2
```

指定バージョンが既にインストール済みの場合は、ダウンロードせず切り替えだけを行う。

### インストールのみ

現在有効なバージョンは変更しない。

```bash
just godot-install
just godot-install 4.7.2
```

### バージョンの切り替え

```bash
just godot-use 4.7.2
```

対象がこのスクリプトによってインストール済みの場合だけ切り替える。

### 現在のバージョンと一覧

```bash
just godot-current
just godot-list
```

有効なバージョンがない場合、`godot-current` は `none` を表示する。一覧では有効版に
`(current)`、管理マーカーがないバージョン形式のディレクトリに `(unmanaged)` を表示する。

### 構成の診断

```bash
just godot-doctor
```

Linux x86_64環境、必要なコマンド、インストール済みバージョン、管理マーカー、`current`、
`/usr/local/bin/godot`、PATH上で選択される実行ファイル、`godot --version`の一致、一時配置の
残骸を検査する。診断は読み取り専用で、パッケージの導入、symlinkの修復、残骸の削除は
行わない。

通常はエラーがある場合だけ終了コード`1`を返す。警告も失敗として扱いたい場合は直接
次のように実行する。

```bash
./godot/doctor.sh --strict
```

引数が不正な場合は終了コード`2`を返す。ネットワークアクセスと最新版確認は行わない。

### アンインストール

```bash
just godot-uninstall 4.7.1
```

現在有効なバージョンは削除できない。先に別バージョンへ切り替える。また、
`.managed-by-chezmoi-dotfiles` の内容が一致しない管理外ディレクトリは削除しない。

## 直接実行

```bash
./godot/install.sh [VERSION]
./godot/use.sh VERSION
./godot/uninstall.sh VERSION
./godot/current.sh
./godot/list.sh
./godot/doctor.sh [--strict]
```

`install.sh` は `X.Y.Z`、`X.Y.Z-stable`、`latest` を受け付ける。省略時は `latest`。
実際に解決した `X.Y.Z` を標準出力へ返し、進捗とエラーは標準エラーへ出す。

## 取得と検証

- repository: `godotengine/godot`
- 最新版解決: GitHub Releases API の latest release
- archive: `Godot_v<version>-stable_linux.x86_64.zip`
- checksum: 同じ release の `SHA512-SUMS.txt`

checksum が一致しない場合や、想定した実行ファイルが archive にない場合は `/opt` へ
配置しない。一時ファイルは `/tmp` に作成し、終了時に削除する。

## 権限と依存コマンド

ダウンロード、検証、展開は一般ユーザー権限で行う。`sudo` は事前の権限確認、`/opt` への
公開、symlink切り替え、アンインストールにだけ使用する。スクリプト全体を `sudo` で
実行する必要はない。

必要なコマンド:

- Bash
- `sudo`
- GNU coreutils
- `curl`
- `jq`
- `unzip`
- `sha512sum`
- `awk`
- `find`
- `sort`

対象環境は Linux x86_64。複数のGodot管理コマンドを同時実行することは想定しない。
