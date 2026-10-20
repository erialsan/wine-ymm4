# winex11: 合成環境でのスクリーンキャプチャ修正

## 症状
KWin(Wayland/Xwayland) のようにコンポジットしている環境では **X のルートウィンドウに画素が入っていない**。
そのため Wine の GDI スクリーン読み取り（`BitBlt(GetDC(NULL), ...)` / `GetPixel`）が **常に真っ黒** を返す。
YMM4 の「アイテムの色」ダイアログのスポイトが全色黒になるのはこれが原因。

## 実測（2026-10-20）
- `ffmpeg -f x11grab -i :0.0` でルートを取得 → 全画素 (0,0,0)・平均 0.0（ユーザーの :0 = KWin/Xwayland）
- 同コマンドを :99 (Xvfb, コンポジタ無し) で実行 → 正常な画面
- 修正前の Wine での `GetPixel(GetDC(NULL))` → `mem=000000 srcdc=000000`
- 修正後 → メモ帳の白 `mem=FFFFFF`、YMM4 プレビューの写真色 `mem=E3CEAF`

## 修正内容（dlls/winex11.drv/bitblt.c）
- `capture_window_tree()`: ルートの可視トップレベルウィンドウを**下から上へ**再帰的に `XGetImage` → 一時 Pixmap に合成（depth が違うウィンドウはスキップ）
- `capture_root_window()`: ルートを `XGetImage` し、**全画素が 0 なら** 上記の合成結果を返す（通常の X サーバでは従来どおり 1 回の `XGetImage` で終わる）
- `X11DRV_GetImage()`: `drawable == root_window` のときだけ `capture_root_window()` を通す

## ビルド・配備（重要）
**必ず /opt/wine11up と同じバージョンのツリーでビルドすること**（11.20 のランタイムに 11.18 の `winex11.so` を入れると起動時に
`X Error ... X_ConfigureWindow ... Value 0x0` で即死する。実測）。

```
cd ~/wine-build/wine-upstream-11.20
make -C dlls/winex11.drv -j8
sudo cp dlls/winex11.drv/winex11.so /opt/wine11up/lib/wine/x86_64-unix/winex11.so
```

## 残課題
- ウィンドウが完全に隠れている場合は X 側に画素が無いため黒のまま（不可避）
- depth 32 (ARGB) のウィンドウは合成対象外（今のところ実害なし）
