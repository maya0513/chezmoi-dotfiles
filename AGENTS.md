# リポジトリ作業ガイド

## 目的と構成

このリポジトリは、Nix flakeによる基本CLI環境と、chezmoiによるホームディレクトリ設定を管理する。

- `flake.nix`と`flake.lock`: Nixパッケージ環境
- `justfile`: Nixとchezmoiの定型操作
- `.chezmoiroot`: chezmoiのソース状態を`home/`へ切り替える指定
- `home/`: chezmoi形式の管理ファイル。リポジトリ用ドキュメントやNix設定は置かない

## 基本コマンド

作業前に`git status --short --branch`、`just status`、`just diff`で現状を確認する。

- `just check`: flakeの評価とchecks
- `just build`: デフォルトパッケージのビルド（`result`リンクは作らない）
- `just switch`: checkとbuild後にユーザーprofileへ反映
- `just upgrade`: lock更新後にprofileへ反映
- `just status`: chezmoi管理対象の状態確認
- `just diff`: chezmoi適用前の差分確認
- `just apply`: chezmoiの状態をホームディレクトリへ反映

## 作業と検証

- Nixの変更後は`just check`と`just build`を実行する。
- chezmoiの変更後は`just diff`を確認し、必要な場合だけ`just apply`して、最後に`just status`を実行する。
- `flake.lock`の更新、profile切替、chezmoi apply、Nix GCは依頼の範囲と影響を確認してから行う。
- ユーザーの既存変更を保持し、Gitへのstage、commit、pushは明示的な依頼なしに行わない。

## 安全上のルール

- 秘密情報、トークン、秘密鍵、認証情報を平文で追加しない。必要なら暗号化または外部シークレット管理を提案する。
- `.gitconfig`はテンプレートとしてのみ管理し、氏名・メールの実値をリポジトリへ書かない。
- Git identityはローカルのchezmoi dataから参照し、テンプレートでは`gitName`と`gitEmail`を使用する。
- `chezmoi purge`、`chezmoi destroy`、`chezmoi state reset`などの破壊的操作は、明示的な依頼なしに実行しない。
- profile履歴の削除やNix store GCでは、先に新しいprofileの動作を検証する。
