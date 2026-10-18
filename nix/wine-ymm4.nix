# d2d1 / winex11.drv の YMM4 向けパッチを当てた Wine。
#
# nixpkgs の wine は 11.0 を指していてパッチ対象のタグと一致しないので、
# src と version を wine-11.20 に差し替えたうえで patches を入れ替える。
# ビルド自体は nixpkgs の wine-wow64 (--enable-archs=x86_64,i386) の構成を
# そのまま使うので、32bit 側の mingw クロスコンパイラなども nixpkgs 任せになる。
{
  lib,
  callPackage,
  wineWow64Packages,
  # アプリ固有の互換ハック (patches/d2d1/0005) を入れるか。
  withCompat ? true,
  # winex11.drv の子サーフェイス attach (patches/winex11) を入れるか。
  withAttach ? true,
}:

let
  sources = callPackage ./sources.nix { };

  ymm4Patches =
    sources.patches.d2d1
    ++ [ sources.patches.setupapi ]
    ++ lib.optional withCompat sources.patches.compat
    ++ lib.optional withAttach sources.patches.winex11;
in
wineWow64Packages.full.overrideAttrs (old: {
  pname = "wine-ymm4";
  version = "11.20";

  # base.nix は src を「derivation に version / patches / staging /
  # updateScript を足した attrset」として扱う。素の fetchFromGitHub 結果を
  # そのまま渡すと staging 参照で落ちるので、明示的に潰しておく。
  src = sources.wine // {
    staging = null;
    updateScript = null;
  };

  # nixpkgs 側のパッチのうち cert-path.patch (NIX_SSL_CERT_FILE 対応) だけ残す。
  # 11.1 未満向けのものは 11.20 には不要なので落とす。
  patches = lib.filter (p: lib.hasInfix "cert-path" (toString p)) (old.patches or [ ]) ++ ymm4Patches;

  # パッチが黙って当たらなくなった場合に、ビルドの早い段階で気づけるようにする。
  postPatch = ''
    grep -q d2d_command_sink_create dlls/d2d1/device.c
    grep -q d2d_command_list_clear dlls/d2d1/command_list.c
    grep -q 'skipping registration of native shim' dlls/setupapi/install.c
  ''
  + lib.optionalString withCompat ''
    grep -q 'Application compat' dlls/d2d1/command_list.c
    grep -q 'Application compat' dlls/d2d1/device.c
  ''
  + lib.optionalString withAttach ''
    grep -q x11drv_attach_child_surface dlls/winex11.drv/x11drv.h
  '';

  passthru = (old.passthru or { }) // {
    inherit ymm4Patches sources;
    withCompat = withCompat;
    withAttach = withAttach;
  };
})
