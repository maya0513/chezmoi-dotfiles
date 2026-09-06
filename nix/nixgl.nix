{ nixgl, pkgs }:

let
  inherit (pkgs) lib;

  # proprietary NVIDIA driver が存在しなければ、AMD/Intel/Nouveau 用の Mesa を使う。
  hasNvidiaDriver = builtins.pathExists "/proc/driver/nvidia/version";

  openGLWrapperExe = lib.getExe' nixgl.nixGLDefault "nixGL";

  # NVIDIA 用 wrapper は実行ファイル名に driver version が入るため、固定名にそろえる。
  nvidiaVulkanWrapper = pkgs.runCommand "nixVulkan" { } ''
    mkdir -p "$out/bin"
    ln -s ${nixgl.nixVulkanNvidia}/bin/* "$out/bin/nixVulkan"
  '';
  vulkanWrapperExe =
    if hasNvidiaDriver then
      "${nvidiaVulkanWrapper}/bin/nixVulkan"
    else
      lib.getExe' nixgl.nixVulkanIntel "nixVulkanIntel";

  # 元パッケージの share/ などを保持したまま、指定したコマンドだけを nixGL 経由にする。
  wrapGraphicsPackage =
    withVulkan: package:
    pkgs.symlinkJoin {
      name = "${package.name}-nixgl";
      paths = [ package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];

      postBuild = ''
        for executable in ${package}/bin/*; do
          binary="$(basename "$executable")"
          rm "$out/bin/$binary"
          ${
            if withVulkan then
              ''
                makeWrapper "${openGLWrapperExe}" "$out/bin/$binary" \
                  --add-flag "${vulkanWrapperExe}" \
                  --add-flag "$executable"
              ''
            else
              ''
                makeWrapper "${openGLWrapperExe}" "$out/bin/$binary" \
                  --add-flag "$executable"
              ''
          }
        done
      '';

      meta = package.meta // {
        outputsToInstall = [ "out" ];
      };
    };
in
{
  wrap = wrapGraphicsPackage false;
  wrapVulkan = wrapGraphicsPackage true;
}
