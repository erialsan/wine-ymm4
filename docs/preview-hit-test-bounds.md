# プレビューの画像をクリックしても選択できない／選択枠がアイテムに追従しない件（2026-10-20 修正）

## 症状
YMM4 v4.56.1.1 で、プレビューに描画されているアイテムをマウスでクリックしても選択されない。
右パネルは「アイテムが選択されていません」のまま。タイムラインで Ctrl+A しても、
プレビュー側に選択枠（ハンドル付きの破線枠）が出ない。

部分修正後は「クリックで選択はできるが、アイテムを移動しても選択枠が付いてこない
（常にキャンバス中央に描かれる）」という症状が残った。

## 当たり判定の作り方（アプリ側の IL 解析で確定）
`TimelineVideoPlayer.Child_MouseDown` はクリック座標を `currentCursorPosition` から取り、
`timelineVideo.TimelineItemRects`（描画ループが毎フレーム作るクアッド 4 点）との
`IsPointInQuad()`（外積符号一致）だけで当たり判定する。

`TimelineSource.Update` はそのクアッドを次の順で作る:

1. `DrawingEffect as IBoundsQuadProvider` が非 null なら `GetTransformedBoundsQuad()`
2. null なら `ID2D1DeviceContext::GetImageLocalBounds(effect.GetOutput())` の軸平行矩形を4点に展開

どちらの経路でも最終的な元データは **`GetImageLocalBounds()` の戻り値**である。

## 原因（2段階）

### 1) コマンドリストの bounds が空
Wine の `d2d1` は `ID2D1CommandList` に対して `GetImageLocalBounds()` が
**常に空矩形**（`(0,0)-(0,0)`）を返していた。クアッドが縮退するため
`IsPointInQuad()` が必ず false になり、クリックが常に外れる（同時に枠も描かれない）。

### 2) 記録時にアイテムの変換行列を畳んでいなかった
記録済み描画の範囲を累積するようにしても、`DrawImage()` に渡される
**エフェクト出力の「サイズ」だけ**を使っていたため、YMM4 が位置を載せている
効果行列（2DAffineTransform / 3DTransform）が bounds に反映されず、
どのアイテムも `(-640,-360)-(640,360)` になっていた。結果、選択枠とヒット領域が
キャンバス中央に固定される。

## 修正内容（`dlls/d2d1/`）

| ファイル | 変更 |
|---|---|
| `command_list.c` | `d2d_command_list_union_point()` / `union_rect()` を追加し、`fill_rectangle` / `draw_rectangle`（stroke幅/2 で膨らます）/ `draw_bitmap` / `draw_image` / `fill_geometry` の記録時に範囲を累積。`d2d_command_list_set_transform()` で `record_transform` を保持し、累積時に適用 |
| `command_list.c` | `d2d_command_list_image_bounds()` を新設。Bitmap → 実サイズ、CommandList → 記録済み bounds、Effect → 入力0へ再帰した後に `d2d_effect_apply_matrix_to_bounds()` で変換を畳む。`union_image()` はこの矩形を使う |
| `device.c` | `GetImageLocalBounds()` の COMMANDLIST 分岐が記録済み bounds をそのまま返す。空のときのみ描画ターゲットサイズでフォールバック |
| `device.c` | `d2d_effect_apply_matrix_to_bounds()` を公開（`d2d1_private.h` に宣言） |

## 実測（Wine 11.18 自前ビルド + DXVK 3.1.1 / Xvfb :99 / YMM4 v4.56.1.1）

`YMM4DIAG=1` の診断出力（本パッチには診断は含まない）で確認:

```
YMM4DIAG: union_image img=… off=(0.0,0.0) -> (-340,-360)-(940,360)   ← X=300 が畳まれている
YMM4DIAG: bounds COMMANDLIST raw=(-340,-360)-(940,360)
```

| 操作 | 結果 |
|---|---|
| X=300 のアイテムをクリック | 画像にぴったりの選択枠が出る（旧: 枠なし、または中央固定） |
| X を 300 → 0 に変更 | 枠が画像の新しい位置に移動 |
| プレビュー内でドラッグ移動 | ドラッグ中も枠が追従 |
| 2アイテム（A: X=0/不透明度100%、B: X=300/50%） | A だけの領域をクリック→A が選択（0.0px/100.0%）、B の領域→B が選択（300.0px/50.0%） |

`docs/preview-hit-test-bounds.png` は X=0 で枠が画像に一致している例、
`docs/preview-hit-test-drag.png` はドラッグ中に枠が追従している例。
