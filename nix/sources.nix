# wine-11.20 のソースと、このリポジトリが持つパッチの一覧。
#
# パッチはすべて wine-11.20 のツリーに対して適用できることを前提にしている
# (scripts/build-d2d1.sh / build-winex11.sh も同じ前提)。
# ベースの Wine を上げるときは wine.rev と hash を更新したうえで、
# patches/ 以下がまだ当たるか必ず確認すること。
#
# なお patches/wine-ymm4-complete-2026-10-17.patch (統合版) は master
# 2026-09-23 をベースにしており wine-11.20 には適用できない。ここでは使わない。
{ lib, fetchFromGitHub }:

let
  wine = fetchFromGitHub {
    owner = "wine-mirror";
    repo = "wine";
    rev = "wine-11.20";
    hash = "sha256-FV9Ey13Q3H3j4snyiUcVsmJxdk6i7Nyfb8hVAJ4GX/o=";
  };

  d2d1 = [
    ../patches/d2d1/0001-d2d1-Support-EndDraw-on-a-command-list-target.patch
    ../patches/d2d1/0002-d2d1-Implement-DrawImage-for-command-lists-and-effec.patch
    ../patches/d2d1/0003-d2d1-Don-t-record-Clear-into-command-lists.patch
    ../patches/d2d1/0004-d2d1-Implement-bounds-queries-for-effects-and-comman.patch
  ];
in
{
  inherit wine;

  patches = {
    inherit d2d1;

    # アプリ固有の互換ハック (中心座標系補正、Open 状態のコマンドリスト再生など)。
    # Windows の挙動とは異なるので、切り離せるようにしてある。
    compat = ../patches/d2d1/0005-d2d1-Application-compatibility-tweaks-YukkuriMovieMa.patch;

    # wine 11.20 向けの子サーフェイス attach。
    # 旧版 0001-winex11-child-surface-attach.patch は wine 10 系向けで
    # vulkan.c も触るため 11.20 には適用できない。
    winex11 = ../patches/winex11/winex11-attach-v3-11.20.patch;
  };
}
