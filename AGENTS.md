# リポジトリ作業ガイド

## 構成

このリポジトリは、Nix flakeによる基本CLI環境と、chezmoiによるホームディレクトリ設定を管理する。

- `flake.nix`と`flake.lock`: Nixパッケージ環境
- `justfile`: 定型操作
- `home/`: chezmoi管理ファイル（`.chezmoiroot`で指定）

## 作業ルール

作業前に`git status --short --branch`、`just chz-status`、`just chz-diff`で現状を確認する。

- レシピは`just --list`で確認し、分類名には`nix`、`chz`、`godot`、`b3d`を使う。
- Nixの変更後は`just nix-check`と`just nix-build`を実行する。
- chezmoiの変更後は`just chz-diff`を確認し、必要な場合だけ`just chz-apply`して、最後に`just chz-status`を実行する。
- `upgrade`、lock更新、profile切替、chezmoi apply、Nix GCは依頼の範囲と影響を確認してから行う。
- ユーザーの既存変更を保持し、Gitへのstage、commit、pushは明示的な依頼なしに行わない。

## 安全上のルール

- 秘密情報、トークン、秘密鍵、認証情報を平文で追加しない。必要なら暗号化または外部シークレット管理を提案する。
- `.gitconfig`はテンプレートのみを管理し、identityはchezmoi dataの`gitName`と`gitEmail`を参照する。
- `chezmoi purge`、`chezmoi destroy`、`chezmoi state reset`などの破壊的操作は、明示的な依頼なしに実行しない。
- profile履歴の削除やNix store GCでは、先に新しいprofileの動作を検証する。
