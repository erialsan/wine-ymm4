# パッチが wine-11.20 に当たるかだけを検証する安い derivation。
# `nix flake check` / `nix build .#checks.<system>.patches-apply` から使う。
# フルの Wine ビルド (数十分) を待たずにパッチの腐敗を検出できる。
{ stdenv, callPackage }:

let
  sources = callPackage ./sources.nix { };
in
stdenv.mkDerivation {
  pname = "wine-ymm4-patches-apply";
  version = "11.20";

  src = sources.wine;

  patches = sources.patches.d2d1 ++ [
    sources.patches.compat
    sources.patches.winex11
  ];

  dontBuild = true;

  # configure まで走らせると 32bit 開発ライブラリの有無を要求されて
  # 環境依存になる。ここで見たいのはパッチが当たるかどうかだけなので飛ばす。
  dontConfigure = true;

  # 当たった「つもり」で中身が変わっていないケースを潰す。
  postPatch = ''
    grep -q d2d_command_sink_create dlls/d2d1/device.c
    grep -q d2d_command_list_clear dlls/d2d1/command_list.c
    grep -q 'Application compat' dlls/d2d1/command_list.c
    grep -q 'Application compat' dlls/d2d1/device.c
    grep -q x11drv_attach_child_surface dlls/winex11.drv/x11drv.h

    # 統合版にあった無条件 fprintf が混ざっていないこと。
    if grep -rn 'YMM4DIAG' dlls/d2d1 dlls/winex11.drv; then
      echo "デバッグ出力が残っています" >&2
      exit 1
    fi
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    runHook postInstall
  '';
}
