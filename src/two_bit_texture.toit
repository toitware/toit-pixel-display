// Copyright (C) 2020 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Classes useful for three- or four-color displays like red-white-black e-ink
// displays.
// A canvas is a frame buffer that can be drawn on and sent to a display.

import bitmap show *
import font show Font

import .pixel-display
import .two-color as two-color

// The canvas contains two bitmapped ByteArrays, for up to 4 colors or gray
// scales per pixel.  Starts off with all pixels 0, 0.
abstract class Canvas_ extends Canvas:
  plane-0_ := ?
  plane-1_ := ?

  constructor width/int height/int:
    assert: height & 7 == 0
    size := (width * height) >> 3
    assert: size <= 4000
    plane-0_ = ByteArray size
    plane-1_ = ByteArray size
    super width height

  set-all-pixels color/int -> none:
    bitmap-zap plane-0_ (color & 1)
    bitmap-zap plane-1_ ((color & 2) >> 1)

  get-pixel_ x y:
    bit := 1 << (y & 7)
    idx := x + width_ * (y >> 3)
    bit0 := (plane-0_[idx] & bit) == 0 ? 0 : 1
    bit1 := (plane-1_[idx] & bit) == 0 ? 0 : 1
    return bit0 + (bit1 << 1)

  make-alpha-map --padding/int=0 -> Canvas:
    result := two-color.Canvas_ (width_ + padding) (height_ + padding)
    result.transform = transform
    return result

  composit frame-opacity frame-canvas painting-opacity painting-canvas/Canvas_:
    fo := frame-opacity is ByteArray ? frame-opacity : frame-opacity.pixels_
    po := painting-opacity is ByteArray ? painting-opacity : painting-opacity.pixels_
    composit-bytes plane-0_ fo (frame-canvas ? frame-canvas.plane-0_ : null) po painting-canvas.plane-0_ true
    composit-bytes plane-1_ fo (frame-canvas ? frame-canvas.plane-1_ : null) po painting-canvas.plane-1_ true

  rectangle x/int y/int --w/int --h/int --color/int:
    transform.xywh x y w h: | x2 y2 w2 h2 |
      c2 := (color & 2) >> 1
      bitmap-rectangle x2 y2 (color & 1) w2 h2 plane-0_ width_
      bitmap-rectangle x2 y2 c2          w2 h2 plane-1_ width_

  text x/int y/int --text/string --color/int --font/Font --orientation/int=ORIENTATION-0:
    transform.xyo x y orientation: | x2 y2 o2 |
      b0 := color & 1
      b1 := (color >> 1) & 1
      bitmap-draw-text x2 y2 b0 o2 text font plane-0_ width_
      bitmap-draw-text x2 y2 b1 o2 text font plane-1_ width_

  abstract nearest-color_ palette/ByteArray offset/int -> int

  bitmap x/int y/int -> none
      --pixels/ByteArray
      --alpha/ByteArray         // 2-element byte array.
      --palette/ByteArray       // 4 element byte array.
      --source-width/int        // In pixels.
      --source-line-stride/int  // In bytes.
      --orientation/int=ORIENTATION-0:
    source-byte-width := (source-width + 7) >> 3
    zero-alpha := alpha[0]
    // Fast case if the alpha is either 0 or 0xff, because we can use the
    // primitives that paint 1's with a particular color and leave the zeros
    // transparent.  We don't check for the case where 0 is opaque and 1 is
    // transparent, because pngunzip fixes that for us.
    if alpha[1] == 0xff and (zero-alpha == 0xff or zero-alpha == 0):
      if zero-alpha == 0xff:
        h := (pixels.size + source-line-stride - source-byte-width ) / source-line-stride
        // Draw the zeros.
        rectangle x y --w=source-width --h=h --color=(nearest-color_ palette 0)
      // Draw the ones.
      transform.xyo x y orientation: | x2 y2 o2 |
        color := nearest-color_ palette 3
        bitmap-draw-bitmap x2 y2
            --color = (color & 1)
            --orientation = o2
            --source = pixels
            --source-width = source-width
            --source-line-stride = source-line-stride
            --destination = plane-0_
            --destination-width = width_
        bitmap-draw-bitmap x2 y2
            --color = (color >> 1)
            --orientation = o2
            --source = pixels
            --source-width = source-width
            --source-line-stride = source-line-stride
            --destination = plane-1_
            --destination-width = width_
      return
    throw "No partially transparent PNGs on 3-color displays."
