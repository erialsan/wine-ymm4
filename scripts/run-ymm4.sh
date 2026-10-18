#!/bin/bash
# wine-ymm4: YMM4 起動ラッパー（環境変数一式を設定して起動）
# 使い方: run-ymm4.sh <YMM4ディレクトリ> <Wineプレフィックス> <プロジェクト.ymmp> [wineバイナリ]
#   例: run-ymm4.sh ~/ymm4-423-test ~/.wine-ymm-test ~/ymm4-423-test/test.ymmp /opt/wine11up/bin/wine
set -e
YMMDIR="${1:?usage: $0 <ymm4-dir> <wineprefix> <project.ymmp> [wine-binary]}"
PREFIX="${2:?usage: $0 <ymm4-dir> <wineprefix> <project.ymmp> [wine-binary]}"
PROJ="${3:?usage: $0 <ymm4-dir> <wineprefix> <project.ymmp> [wine-binary]}"
WINE="${4:-wine}"

if [ -c /dev/ntsync ] && [ -r /dev/ntsync ]; then
    echo "警告: /dev/ntsync がアクセス可能です。ntsync デッドロック回避のため封鎖してください:" >&2
    echo "  sudo chmod 000 /dev/ntsync   （udev ルールでの自動化は README 参照）" >&2
fi

export WINEPREFIX="$PREFIX"
export WINE_X11_CHILD_SURFACE_ATTACH=1
export DOTNET_ReadyToRun=0
export DOTNET_SYSTEM_GLOBALIZATION_USENLS=1
export WINEDLLOVERRIDES="winewayland.drv=d"
export WINEDEBUG=-all

# プロジェクトのパスを Windows 形式 (Z:\) に変換
case "$PROJ" in
    [A-Za-z]:*) PROJ_WIN="$PROJ" ;;
    /*) PROJ_WIN="Z:${PROJ//\//\\}" ;;
    *) PROJ_WIN="$PROJ" ;;
esac

cd "$YMMDIR"
exec "$WINE" YukkuriMovieMaker.exe "$PROJ_WIN"
