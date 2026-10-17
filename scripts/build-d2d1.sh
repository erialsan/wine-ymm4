#!/bin/bash
# wine-ymm4: d2d1.dll をビルドするスクリプト
# 使い方: build-d2d1.sh <wine-source-dir> [deploy-dest ...]
#   例: build-d2d1.sh ~/wine
#       build-d2d1.sh ~/wine /opt/wine11up/lib/wine/x86_64-windows ~/.wine/drive_c/windows/system32
set -e
SRC="${1:?usage: $0 <wine-source-dir> [deploy-dest ...]}"; shift || true
HERE="$(cd "$(dirname "$0")/.." && pwd)"

cd "$SRC"
if [ ! -f configure ]; then
    echo "wine configure が見つかりません。先に ./configure --enable-archs=i386,x86_64 --disable-tests --enable-maintainer-mode を実行してください" >&2
    exit 1
fi

for p in "$HERE"/patches/d2d1/*.patch; do
    if git -C "$SRC" apply --check "$p" 2>/dev/null; then
        echo "applying: $(basename "$p")"
        git -C "$SRC" apply "$p"
    else
        echo "skip (already applied?): $(basename "$p")"
    fi
done

rm -f dlls/d2d1/x86_64-windows/{device,bitmap,command_list,effect}.o dlls/d2d1/x86_64-windows/d2d1.dll
make -j"$(nproc)" dlls/d2d1/x86_64-windows/d2d1.dll

DLL="$SRC/dlls/d2d1/x86_64-windows/d2d1.dll"
echo "built: $DLL"
for d in "$@"; do
    echo "deploying: $d"
    cp -a "$DLL" "$d/"
done
