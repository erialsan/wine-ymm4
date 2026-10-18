# wine-11.20 のソースと、このリポジトリが持つパッチの一覧。
#
# パッチはすべて wine-11.20 のツリーに対して適用できることを前提にしている
# (scripts/build-d2d1.sh / build-winex11.sh も同じ前提)。
# ベースの Wine を上げるときは wine.rev と hash を更新したうえで、
# patches/ 以下がまだ当たるか必ず確認すること。
#
# d2d1 は wine-11.20 用に生成した統合パッチ 1 本を使う (CL修正・エフェクト登録・
# アプリ互換ハックをすべて含む)。master 2026-09-23 ベースの
# patches/wine-ymm4-complete-*.patch は wine-11.20 には適用できない。
{ lib, fetchFromGitHub }:

let
  wine = fetchFromGitHub {
    owner = "wine-mirror";
    repo = "wine";
    rev = "wine-11.20";
    hash = "sha256-FV9Ey13Q3H3j4snyiUcVsmJxdk6i7Nyfb8hVAJ4GX/o=";
  };

  d2d1 = [
    ../patches/d2d1/wine-11.20-d2d1-ymm4-complete.patch
  ];
in
{
  inherit wine;

  patches = {
    inherit d2d1;

    # wow64 更新時に wineboot が rundll32 ダイアログで止まる問題の修正。
    # dotnet472 入りの古いプレフィックスを wine 11 で初回更新するときに踏む。
    setupapi = ../patches/setupapi/0001-setupapi-Skip-registration-of-native-dotNET-and-Gecko-shims.patch;

    # wine 11.20 向けの子サーフェイス attach。
    # 旧版 0001-winex11-child-surface-attach.patch は wine 10 系向けで
    # vulkan.c も触るため 11.20 には適用できない。
    winex11 = ../patches/winex11/winex11-attach-v3-11.20.patch;
  };
}
