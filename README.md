# wine-ymm4

**YukkuriMovieMaker4 (YMM4) を Linux / Wine で完全に動かすための Wine パッチ集。**

**最新リリース: [v3 — wine 11.20 対応 + 検証済みバイナリ同梱](https://github.com/maebahesioru/wine-ymm4/releases/tag/v3)**

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

**wine 11.20 用の統合パッチ**: `patches/d2d1/wine-11.20-d2d1-ymm4-complete.patch`
— 上記すべて（CL修正・エフェクト画像描画・組み込みエフェクト登録・カスタムエフェクトfallback）を
含む 5 ファイル一括パッチ。**wine-11.20 のツリーにそのまま `git apply` できます**（Nix flake はこちらを使用）。
エフェクト登録の実機検証は `scripts/fxprobe.cpp`（mingw でビルドし wine 上で実行、18種の CreateEffect/SetValue/描画を確認）。

### `patches/winex11/` — Wine 本体（dlls/winex11.drv/）に適用

- `winex11-attach-v3-11.20.patch` — **wine 11.20 向け（推奨）**。`init.c` / `window.c` / `x11drv.h` の 3 ファイル。
  子ウィンドウサーフェスをトップレベル窓内に直接アタッチ表示する（下記 0001 と同機能の 11.20 移植版）。
- `0001` **child surface attach**（旧版・wine 10 系向け） — ネイティブ DXVK は Wine の present コールバックを
  呼ばないため、プレビュー子窓が「オフスクリーン合成扱い → 不可視」になり描画が届かない問題の回避策。

いずれも環境変数 `WINE_X11_CHILD_SURFACE_ATTACH=1` で有効化します。

### `patches/setupapi/` — Wine 本体（dlls/setupapi/）に適用

- `0001` **Skip registration of native .NET / Gecko shims** — wineboot の INF 処理（`RegisterDlls`）が
  `mscoree.dll`（ネイティブ .NET）/ `mshtml.dll`（Gecko）を再登録しようとすると、これらの
  `DllRegisterServer` が対話エラーダイアログ（"This application could not be started."）を出して
  永久に待機し、wineboot が Wow64Install 工程で停止する問題を回避する。
  （dotnet472 等でネイティブ上書きされた古いプレフィックスを wine 11 で初回更新する時に発生。2026-10-18 修正）

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

起動時は `WINE_X11_CHILD_SURFACE_ATTACH=1` が必要です。同梱の `scripts/run-ymm4.sh` を使うと、
環境変数一式（DOTNET 系・winewayland 無効化・ntsync チェック）を設定して起動できます:

```bash
scripts/run-ymm4.sh <YMM4ディレクトリ> <Wineプレフィックス> <プロジェクト.ymmp> [wineバイナリ]
# 例: scripts/run-ymm4.sh ~/ymm4-423-test ~/.wine-ymm-test ~/ymm4-423-test/test.ymmp /opt/wine11up/bin/wine
```

## Nix でビルドする

`flake.nix` に、パッチ済み Wine のビルドと開発シェルを用意してあります。
対象の Wine は `nix/sources.nix` で **wine-11.20 に固定**しているので、
パッチが当たるかどうかが環境ごとにぶれません。

```bash
# パッチを当てた Wine を丸ごとビルド（初回は数十分かかります）
nix build                # -> ./result/bin/wine
nix build .#wine         # 同上

# パッチが wine-11.20 に当たるかだけを確認（フルビルド不要・数分）
nix flake check

# 開発シェル（Wine のビルド依存 + wine ソースが .wine-src/ に展開される）
nix develop
```

開発シェルの中では `$WINE_SRC` が `.wine-src/` を指すので、
`scripts/*.sh` をそのまま使えます。

```bash
# 初回だけ configure しておく（d2d1.dll / winex11.so を作るだけなら 64bit のみで足りる）
cd "$WINE_SRC"
./configure --enable-archs=x86_64 --disable-tests
cd -

./scripts/build-d2d1.sh    "$WINE_SRC"
./scripts/build-winex11.sh "$WINE_SRC"
```

> `nix build .#wine` は nixpkgs の wine-wow64 の構成（`--enable-archs=i386,x86_64`）を
> そのまま使うため、32bit 側の mingw クロスコンパイラもビルド対象になります。
> （`nix develop` で d2d1.dll だけ作る場合は 64bit のみで済みます。）

NixOS の `configuration.nix` からは overlay 経由でそのまま使えます。

```nix
{
  inputs.wine-ymm4.url = "github:maebahesioru/wine-ymm4";

  imports = [ inputs.wine-ymm4.overlays.default ];
  environment.systemPackages = [ pkgs.wine-ymm4 ];
}
```

`nix develop` を使わない場合、従来どおり手元の wine 11.20 チェックアウトを
`scripts/*.sh` の引数に渡せば同じようにビルドできます。

### CI とバイナリキャッシュ

`.github/workflows/nix.yml` が `main` への push と手動実行で `nix build .#wine` を回し、
成果物を Cachix（キャッシュ名 `ymm4-wine`）に投入します。キャッシュを有効にすると、
以降の `nix build` はビルドではなくダウンロードになります（16 コアでも 40 分ほどかかります）。

```bash
cachix use ymm4-wine        # ローカルの substituter に追加
```

`flake.nix` の `nixConfig` にも substituter と公開鍵を書いてあるので、
`accept-flake-config = true` にしている環境なら `cachix use` なしでも取りに行きます。

GitHub の Settings → Secrets and variables → Actions に `CACHIX_AUTH_TOKEN` を登録してください。
未設定でもワークフローは動き、キャッシュへの push だけがスキップされます。

## SBC / ARM について

パッチ本体はアーキ非依存の C コードなので、ARM (aarch64) の Wine ツリーにもそのまま適用できます
（`scripts/build-d2d1.sh` は PE ターゲットのアーキディレクトリを自動検出します）。
SBC で動かす場合の想定ルート:

- x86_64 アプリ (YMM4 は x64 の .NET) を動かすには **Box64 / FEX-Emu** などのユーザー空間エミュレーション
  + wine (x86_64 ビルド) + **DXVK (Vulkan 必須)** の組み合わせ
- プレビュー子窓の表示には winex11 の attach パッチ（`WINE_X11_CHILD_SURFACE_ATTACH`）が同様に必要です
- **実機（Raspberry Pi 等）での動作検証はまだ行えていません**。試した報告・失敗ログは歓迎します

## YMM4 動作に必要なその他のポイント（要点）

- Wine プレフィックスに **DXVK 3.1.1（最新・推奨。wine 11.20 でプレビュー/書き出し実測動作）** または 2.5.3（d3d9/d3d11/dxgi）+ `dxgi.syncInterval=0`
- 日本語フォント（Noto CJK）とフォント代替設定、`DOTNET_SYSTEM_GLOBALIZATION_USENLS=1`
- ntsync デッドロック回避（wine が `/dev/ntsync` を使うと固まる環境）: デバイスを `chmod 000` で封鎖する。
  再起動・デバイス再作成のたびの手動 chmod を不要にするには、udev ルールで自動化するのがおすすめ:
  `echo 'SUBSYSTEM=="misc", KERNEL=="ntsync", RUN+="/usr/bin/chmod 000 /dev/ntsync"' | sudo tee /etc/udev/rules.d/99-ntsync-block.rules && sudo udevadm control --reload-rules`
- `WINEDLLOVERRIDES="winewayland.drv=d"` で X11 強制
- 補足: 古いプレフィックス（wine 10 製）を wine 11 で初回起動する際、wineboot の
  「Wow64Install」工程で rundll32 ダイアログ（"This application could not be started."）が
  出て停止することがあります。**本リポジトリの `patches/setupapi/` を適用したビルドでは
  発生しません**（2026-10-18 修正・実測確認済み）。未適用ビルドでは、ダイアログを閉じて
  続行して問題ありません（64bit アプリには実害なし）。

## ライセンス

Wine 本体に由来するパッチのため **LGPL-2.1-or-later**（`LICENSE` / `COPYING.LIB` 参照）。

## 更新履歴

- **2026-10-18**: wow64 更新時の wineboot 停止問題を修正 — `patches/setupapi/0001`
  （ネイティブ mscoree / mshtml の再登録スキップ）。dotnet472 入りの古いプレフィックスを
  wine 11 で初回更新する時の「rundll32 ダイアログで停止」が解消（実測確認済み）。
  併せて起動まわりを整理: `scripts/run-ymm4.sh`（環境変数一式の起動ラッパー）を追加、
  ntsync 自動封鎖の udev ルール手順を README に追記。

- **2026-10-18 (Nix)**: Nix flake を追加 — `nix build .#wine` でパッチ適用済み Wine、
  `nix develop` で `d2d1.dll` / `winex11.so` だけを作る開発環境。
  対象 Wine を wine-11.20 に固定したので、パッチ適用可否は `nix flake check` で検証できる。
  パッチは d2d1 統合パッチ（wine-11.20 用）+ winex11 の 11.20 版 + setupapi の wineboot 修正。
  GitHub Actions + Cachix でビルド結果をキャッシュする workflow も追加。
  なお統合版 `patches/wine-ymm4-complete-2026-10-17.patch` は master 2026-09-23 ベースで
  wine-11.20 には適用できないため、flake では分割版 5 本 + winex11 の 11.20 版を使う。

- **2026-10-18 (3)**: 実使用フィードバックによる修正 — ①ウィンドウ移動時の子サーフェス**再同期**
  （`X11DRV_WindowPosChanged` フック + アタッチ登録簿。プレビュー位置が動かすとズレる問題の修正）、
  ②子サーフェスの**クリック透過**（ShapeInput を空に。プレビュー上のクリックが届かない問題の修正）、
  ③win32 枠座標 → X クライアント座標の補正（`ClientToScreen`。最大化時の枠オフセットによるズレの修正）、
  ⑤`XReparentWindow` は初回のみに制限（毎回の再親付けが DXVK スワップチェーンの関連付けを壊し、
  フリーズと explorer の 100% 超スピンを引き起こしていたため）、
  ④d2d1 の消し忘れ診断 fprintf を除去（毎描画の stderr 出力を解消）。
- **2026-10-18 (2)**: 未登録だった組み込みエフェクト **18 種を追加登録**
  （ChromaKey / CrossFade / DistantDiffuse / DistantSpecular / EdgeDetection / Exposure /
  GammaTransfer / HighlightsShadows / Invert / LinearTransfer / LuminanceToAlpha / Morphology /
  PointDiffuse / Posterize / Sepia / Sharpen / Tile / Tint）。
  `scripts/fxprobe.cpp` で 18/18 の CreateEffect + SetValue + DrawImage を実測確認。
  併せて **wine 11.20 用の d2d1 統合パッチ**（`patches/d2d1/wine-11.20-d2d1-ymm4-complete.patch`）を追加。
  描画は従来同様の入力再帰（近似）方式のため、これらのエフェクトの**見た目**は今後 wine 側の
  エフェクト実行パス実装で改善されます（クラッシュ・作成失敗は解消）。

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
