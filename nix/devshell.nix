# 開発シェル。wine-11.20 のソースを .wine-src/ に展開し、
# scripts/build-d2d1.sh / build-winex11.sh をすぐ叩ける状態にする。
#
#   nix develop
#   ./scripts/build-d2d1.sh .wine-src
#   ./scripts/build-winex11.sh .wine-src
#
# フルの Wine をビルドしたい場合はシェルを抜けて `nix build` を使う。
{
  wine,
  callPackage,
  mkShell,
  # --enable-maintainer-mode まわり
  fontforge,
  perlPackages,
  librsvg,
  icoutils,
  imagemagick,
  # scripts/ が使うもの
  git,
  bison,
  flex,
  autoconf,
}:

let
  sources = callPackage ./sources.nix { };
in
mkShell {
  # nixpkgs の wine ビルド依存 (X11 / Vulkan / freetype / mingw gcc ...) を
  # そのまま借りる。ここを手書きすると差分が出やすい。
  inputsFrom = [ wine ];

  packages = [
    fontforge
    perlPackages.XMLLibXML
    librsvg
    icoutils
    imagemagick
    git
    bison
    flex
    autoconf
  ];

  shellHook = ''
    if [ ! -d ./patches/d2d1 ]; then
      echo "[wine-ymm4] リポジトリ直下で 'nix develop' を実行してください。" >&2
    fi

    if [ ! -f ./.wine-src/configure ]; then
      echo "[wine-ymm4] wine-11.20 のソースを .wine-src/ に展開します (初回のみ)"
      rm -rf ./.wine-src
      cp -r ${sources.wine} ./.wine-src
      chmod -R u+w ./.wine-src
    fi

    export WINE_SRC="$PWD/.wine-src"

    echo
    echo "  WINE_SRC=$WINE_SRC"
    echo "  ./scripts/build-d2d1.sh    \$WINE_SRC   # d2d1.dll だけ再ビルド"
    echo "  ./scripts/build-winex11.sh \$WINE_SRC   # winex11.so だけ再ビルド"
    echo "  nix build .#wine                        # パッチ済み Wine を丸ごとビルド"
    echo
  '';
}
