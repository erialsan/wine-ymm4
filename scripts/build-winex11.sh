#!/bin/bash
# wine-ymm4: winex11.drv パッチ（子サーフェスアタッチ）をビルドするスクリプト
# 使い方: build-winex11.sh <wine-source-dir> [deploy-dest ...]
#   例: build-winex11.sh ~/wine /opt/wine11up/lib/wine/x86_64-unix
#       build-winex11.sh ~/wine /opt/wine-cachyos/lib/wine/x86_64-unix
# 対象ツリーに適用できるパッチを自動選択（11.20 用 v3 を優先、旧版はスキップ）
set -e
SRC="${1:?usage: $0 <wine-source-dir> [deploy-dest ...]}"; shift || true
HERE="$(cd "$(dirname "$0")/.." && pwd)"

cd "$SRC"

APPLIED=""
for P in "$HERE/patches/winex11/winex11-attach-v3-11.20.patch" \
         "$HERE/patches/winex11/0001-winex11-child-surface-attach.patch"; do
    if git -C "$SRC" apply --check "$P" 2>/dev/null; then
        echo "applying: $(basename "$P")"
        git -C "$SRC" apply "$P"
        APPLIED="$(basename "$P")"
        break
    else
        echo "skip (not applicable or already applied): $(basename "$P")"
    fi
done
[ -n "$APPLIED" ] || { echo "適用できる winex11 パッチがありません（適用済み？）" >&2; exit 1; }

rm -f dlls/winex11.drv/*.o
make -j"$(nproc)" dlls/winex11.drv/winex11.so

SO="$SRC/dlls/winex11.drv/winex11.so"
echo "built: $SO"
for d in "$@"; do
    echo "deploying: $d"
    cp -a "$SO" "$d/"
done
echo "起動時に WINE_X11_CHILD_SURFACE_ATTACH=1 を設定してください"
