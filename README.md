# wine-ymm4

**YukkuriMovieMaker4 (YMM4) を Linux / Wine で完全に動かすための Wine パッチ集。**

Wine の `d2d1.dll` に不足していた Direct2D のコマンドリスト／エフェクト画像対応を追加し、
さらに YMM4 固有の描画互換処理（およびプレビュー子窓の表示修正）を加えるパッチ群です。

このパッチを当ててビルドした `d2d1.dll` + `winex11.so` を使うと、Wine 上で
**プレビュー表示と動画出力（mp4書き出し）の両方が正しく描画**されます。

| 検証 | 結果 |
|---|---|
| プレビュー窓 | 写真が中央・正色で表示（`docs/preview-after-fix.png`） |
| エクスポートmp4 | フレーム抽出で写真正色を確認（`docs/export-frame-after-fix.png`） |
| 実プロジェクト（116クリップ・3分20秒） | プレビュー再生 + 全編書き出し **200.6秒 / 12036フレーム / 例外0**（2026-10-17 実測） |

検証環境（最新実測 2026-10-17 深夜）: CachyOS（Linux） / **Wine 11.20（上流タグを自前フルビルド）** / **DXVK 3.1.1** / YMM4 v4.56.1.1 / Xvfb X11
（旧実測: Wine 10.0 (wine-cachyos) / DXVK 2.5.3 でも動作）

## パッチ構成

### `patches/d2d1/` — Wine 本体（dlls/d2d1/）に適用して d2d1.dll をビルド

（wine master / 11.20 系で開発。**wine 11.20 ツリーで 5 本すべて `git apply` 可を実測確認**）

1. `0001` **EndDraw() on command list target** — コマンドリストへの録音終了を許可（Wine は E_NOTIMPL を返す）
2. `0002` **DrawImage() for command lists and effect images** — コマンドリストのリプレイ（内部コマンドシンク）と、エフェクト画像の初期対応（入力0への再帰 + 標準transform/cropエフェクトのプロパティ適用）
3. `0003` **Don't record Clear() into command lists** — ★核心修正。記録された Clear がリプレイ時に実行されて描画済み内容を全消去していた（詳細: [docs/discovery.md](docs/discovery.md)）
4. `0004` **Bounds queries for effects and command lists** — `GetImageLocalBounds`/`GetImageWorldBounds` のエフェクト・CL対応
5. `0005` **Application compatibility tweaks** — YMM4 固有の互換処理:
   - 使用済みコマンドリストへの再録音の許可（Wine は ERROR 化して以後のリプレイを全て無効化する）
   - Open 状態のリストのリプレイ許容
   - 中心座標系キャンバスの補正（明示オフセット付きビットマップ描画をターゲット中心基準で配置）

### `patches/winex11/` — Wine 本体（dlls/winex11.drv/）に適用

- `winex11-attach-v3-11.20.patch` — **wine 11.20 向け（推奨）**。`init.c` / `window.c` / `x11drv.h` の 3 ファイル。
  子ウィンドウサーフェスをトップレベル窓内に直接アタッチ表示する（下記 0001 と同機能の 11.20 移植版）。
- `0001` **child surface attach**（旧版・wine 10 系向け） — ネイティブ DXVK は Wine の present コールバックを
  呼ばないため、プレビュー子窓が「オフスクリーン合成扱い → 不可視」になり描画が届かない問題の回避策。

いずれも環境変数 `WINE_X11_CHILD_SURFACE_ATTACH=1` で有効化します。

## ビルド方法（wine 11.20・2026-10-17 実測手順）

```bash
# 0. 依存（フォント・アイコン生成のため。無いと --enable-maintainer-mode が失敗する）
sudo pacman -S --needed fontforge perl-xml-libxml   # + rsvg-convert / icoutils / imagemagick

# 1. Wine ソース（最新タグ）を取得
git clone --depth 1 -b wine-11.20 https://github.com/wine-mirror/wine
cd wine
./configure --enable-archs=i386,x86_64 --disable-tests --enable-maintainer-mode

# 2. d2d1.dll ビルド（パッチ適用込み・スクリプト使用）
/path/to/repo/scripts/build-d2d1.sh "$PWD"

# 3. winex11 ビルド（11.20 用パッチを自動適用・スクリプト使用）
/path/to/repo/scripts/build-winex11.sh "$PWD"

# 4. デプロイ（インストール先とプレフィックスの両方へ）
#   d2d1.dll   -> <wine>/lib/wine/x86_64-windows/ と <prefix>/drive_c/windows/system32/
#   winex11.so -> <wine>/lib/wine/x86_64-unix/
```

起動時に `WINE_X11_CHILD_SURFACE_ATTACH=1` を設定してください。

## YMM4 動作に必要なその他のポイント（要点）

- Wine プレフィックスに **DXVK 3.1.1（最新・推奨。wine 11.20 でプレビュー/書き出し実測動作）** または 2.5.3（d3d9/d3d11/dxgi）+ `dxgi.syncInterval=0`
- 日本語フォント（Noto CJK）とフォント代替設定、`DOTNET_SYSTEM_GLOBALIZATION_USENLS=1`
- 起動前に `sudo chmod 000 /dev/ntsync`（ntsync デッドロック回避・再起動毎に必要）
- `WINEDLLOVERRIDES="winewayland.drv=d"` で X11 強制
- 補足: 古いプレフィックス（wine 10 製）を wine 11 で初回起動すると、wineboot の
  「Wow64Install」処理が rundll32 ダイアログで待機することがあります。
  64bit アプリの動作には実害がないため、閉じて続行して問題ありません。

## ライセンス

Wine 本体に由来するパッチのため **LGPL-2.1-or-later**（`LICENSE` / `COPYING.LIB` 参照）。

## 更新履歴

- **2026-10-17 v3**: 上流 wine **11.20** (最新タグ) のフルビルドに対応
  — winex11アタッチパッチの 11.20 版 = `patches/winex11/winex11-attach-v3-11.20.patch`。
  実プロジェクト(116クリップ・3分20秒)のプレビュー + 全編書き出し(200.6秒・例外0)を
  wine 11.20 + DXVK 3.1.1 + 本パッチ + d2d1修正で再実測達成(2026-10-17夜)。
  ビルドは `--enable-maintainer-mode` + fontforge + perl-xml-libxml 必須(フォント/アイコン生成のため)。
  d2d1 パッチ5本の 11.20 適用可も確認済み。

- **2026-10-17 v2**: 実プロジェクト（116クリップ・3分20秒）での完全動作を実測確認
  — プレビュー表示・全編mp4書き出し（12036フレーム/例外0）。
  追加修正: エフェクトチェーン/コマンドリストの中心座標系補正、CLリプレイの
  オフセット継承、AlphaMask/Opacity/OpacityMetadataエフェクト登録、
  カスタムエフェクトのパススルーfallback。
  → 完全版パッチ: `patches/wine-ymm4-complete-2026-10-17.patch`（統合版・master 2026-09-23 ベース）

## 注記

本パッチ群は AI（LLM）の支援を受けて開発されたものです。
WineHQ のコントリビューター・ポリシーが LLM 生成コードの upstream 持ち込みを
控えるよう求めているため、upstream への提出は行わず、独立プロジェクトとして
ここに公開しています。
