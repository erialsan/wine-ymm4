#!/bin/bash
# wine-ymm4: winex11.drv パッチ（子サーフェスアタッチ）をビルドするスクリプト
# 使い方: build-winex11.sh <wine-source-dir> [deploy-dest ...]
#   例: build-winex11.sh ~/wine /opt/wine-cachyos/lib/wine/x86_64-unix
set -e
SRC="${1:?usage: $0 <wine-source-dir> [deploy-dest ...]}"; shift || true
HERE="$(cd "$(dirname "$0")/.." && pwd)"

cd "$SRC"
P="$HERE/patches/winex11/0001-winex11-child-surface-attach.patch"
if git -C "$SRC" apply --check "$P" 2>/dev/null; then
    echo "applying: $(basename "$P")"
    git -C "$SRC" apply "$P"
else
    echo "skip (already applied?): $(basename "$P")"
fi

rm -f dlls/winex11.drv/*.o
make -j"$(nproc)" dlls/winex11.drv/winex11.so

SO="$SRC/dlls/winex11.drv/winex11.so"
echo "built: $SO"
for d in "$@"; do
    echo "deploying: $d"
    cp -a "$SO" "$d/"
done
echo "起動時に WINE_X11_CHILD_SURFACE_ATTACH=1 を設定してください"
