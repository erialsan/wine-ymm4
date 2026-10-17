# wine-ymm4

**YukkuriMovieMaker4 (YMM4) を Linux / Wine で完全に動かすための Wine パッチ集。**

Wine の `d2d1.dll` に不足していた Direct2D のコマンドリスト／エフェクト画像対応を追加し、
さらに YMM4 固有の描画互換処理を加えるパッチ群です。

このパッチを当ててビルドした `d2d1.dll` を使うと、Wine 上で
**プレビュー表示と動画出力（mp4書き出し）の両方が正しく描画**されます。

| 検証 | 結果 |
|---|---|
| プレビュー窓 | 写真が中央・正色で表示（`docs/preview-after-fix.png`） |
| エクスポートmp4 | フレーム抽出で写真正色を確認（`docs/export-frame-after-fix.png`） |

検証環境: CachyOS（Linux） / Wine 10.0 (wine-cachyos) / DXVK 2.5.3 / YMM4 v4.56.1.1 / Xvfb X11

## パッチ構成

### `patches/d2d1/` — Wine 本体（dlls/d2d1/）に適用して d2d1.dll をビルド

1. `0001` **EndDraw() on command list target** — コマンドリストへの録音終了を許可（Wine は E_NOTIMPL を返す）
2. `0002` **DrawImage() for command lists and effect images** — コマンドリストのリプレイ（内部コマンドシンク）と、エフェクト画像の初期対応（入力0への再帰 + 標準transform/cropエフェクトのプロパティ適用）
3. `0003` **Don't record Clear() into command lists** — ★核心修正。記録された Clear がリプレイ時に実行されて描画済み内容を全消去していた（詳細: [docs/discovery.md](docs/discovery.md)）
4. `0004` **Bounds queries for effects and command lists** — `GetImageLocalBounds`/`GetImageWorldBounds` のエフェクト・CL対応
5. `0005` **Application compatibility tweaks** — YMM4 固有の互換処理:
   - 使用済みコマンドリストへの再録音の許可（Wine は ERROR 化して以後のリプレイを全て無効化する）
   - Open 状態のリストのリプレイ許容
   - 中心座標系キャンバスの補正（明示オフセット付きビットマップ描画をターゲット中心基準で配置）

### `patches/winex11/` — Wine 本体（dlls/winex11.drv/）に適用

- `0001` **child surface attach** — 子ウィンドウサーフェスをトップレベル窓内にアタッチ表示する。
  ネイティブ DXVK は Wine の present コールバックを呼ばないため、プレビュー子窓が
  「オフスクリーン合成扱い → 不可視」になり描画が届かない問題の回避策
  （環境変数 `WINE_X11_CHILD_SURFACE_ATTACH=1` で有効化）

## ビルド方法

```bash
# 1. Wine ソースを取得（このパッチは wine master / 11.20 系で開発）
git clone https://gitlab.winehq.org/wine/wine.git
cd wine && ./configure --enable-archs=x86_64 --disable-tests

# 2. パッチ適用 + d2d1.dll ビルド（スクリプト使用）
/path/to/repo/scripts/build-d2d1.sh "$PWD"

# 3. デプロイ（Wine インストール先とプレフィックスの両方へ）
sudo cp dlls/d2d1/x86_64-windows/d2d1.dll /opt/wine-cachyos/lib/wine/x86_64-windows/
cp dlls/d2d1/x86_64-windows/d2d1.dll ~/.wine/drive_c/windows/system32/
```

winex11 パッチを使う場合は Wine ツリーの `dlls/winex11.drv/` に適用し、
`winex11.so` をビルドして `lib/wine/x86_64-unix/` に配置します
（`WINE_X11_CHILD_SURFACE_ATTACH=1` を付けて起動）。

## YMM4 動作に必要なその他のポイント（要点）

- Wine プレフィックスに **DXVK 2.5.3**（d3d9/d3d11/dxgi）+ `dxgi.syncInterval=0`
- 日本語フォント（Noto CJK）とフォント代替設定、`DOTNET_SYSTEM_GLOBALIZATION_USENLS=1`
- 起動前に `sudo chmod 000 /dev/ntsync`（ntsync デッドロック回避・再起動毎に必要）
- `WINEDLLOVERRIDES="winewayland.drv=d"` で X11 強制

## ライセンス

Wine 本体に由来するパッチのため **LGPL-2.1-or-later**（`LICENSE` / `COPYING.LIB` 参照）。

## 更新履歴

- **2026-10-17 v2**: 実プロジェクト（116クリップ・3分20秒）での完全動作を実測確認
  — プレビュー表示・全編mp4書き出し（12036フレーム/例外0）。
  追加修正: エフェクトチェーン/コマンドリストの中心座標系補正、CLリプレイの
  オフセット継承、AlphaMask/Opacity/OpacityMetadataエフェクト登録、
  カスタムエフェクトのパススルーfallback。
  → 完全版パッチ: `patches/wine-ymm4-complete-2026-10-17.patch`（統合版・これ1本でOK）

## 注記

本パッチ群は AI（LLM）の支援を受けて開発されたものです。
WineHQ のコントリビューター・ポリシーが LLM 生成コードの upstream 持ち込みを
控えるよう求めているため、upstream への提出は行わず、独立プロジェクトとして
ここに公開しています。
