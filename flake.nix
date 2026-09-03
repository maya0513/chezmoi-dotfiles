{
  description = "ubuntu environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { nixpkgs, ... }:

    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # supportedSystems の各 system に対して、同じ形式の属性セットを生成するためのヘルパー
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      # 利用できるパッケージの定義
      packages = forAllSystems (
        system:
        let
          # 対象 system 用の nixpkgs パッケージセット
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          # `nix build` や `nix profile install .`で選ばれるデフォルトパッケージ
          default = pkgs.buildEnv {
            # 生成される環境の名前
            name = "base-env";

            paths = with pkgs; [
              chezmoi
              starship
              mise
            ];
          };
        }
      );
    };
}