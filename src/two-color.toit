// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Constants useful for black-and-white $pixel-display.PixelDisplay.two-color.
For use with e-paper displays and the SSD1306 128x64 display
  (driver at https://pkg.toit.io/package/ssd1306&url=github.com%2Ftoitware%2Ftoit-ssd1306&index=latest)
*/

import bitmap show *
import font show Font

import .pixel-display
import .pixel-display as pixel-display

WHITE ::= 0
BLACK ::= 1

// The canvas contains a bitmapped ByteArray.
// Starts off with/ all pixels white.
class Canvas_ extends Canvas:
  pixels_ := ?

  supports-8-bit -> bool: return false
  gray-scale -> bool: return true

  constructor width/int height/int:
    assert: height & 7 == 0
    size := (width * height) >> 3
    assert: size <= 4000
    pixels_ = ByteArray size
    super width height

  set-all-pixels color/int -> none:
    bitmap-zap pixels_ (color & 1)

  get-pixel_ x y:
    bit := 1 << (y & 7)
    idx := x + width_ * (y >> 3)
    return (pixels_[idx] & bit) == 0 ? 0 : 1

  /**
  Creates a blank canvas with the same dimensions as this one.
  */
  create-similar -> Canvas_:
    result := Canvas_ width_ height_
    result.transform = transform
    return result

  subcanvas x/int y/int w/int h/int --ignore-x/bool=false --ignore-y/bool=false -> Canvas_?:
    // This would rarely succeed since we have a vertical granularity of 8
    // pixels.
    return null

  make-alpha-map --padding/int=0 -> Canvas:
    result := Canvas_ (width_ + padding) (height_ + padding)
    result.transform = transform
    return result

  composit frame-opacity frame-canvas/Canvas_? painting-opacity painting-canvas/Canvas_:
    fo := frame-opacity is ByteArray ? frame-opacity : frame-opacity.pixels_
    po := painting-opacity is ByteArray ? painting-opacity : painting-opacity.pixels_
    composit-bytes pixels_ fo (frame-canvas ? frame-canvas.pixels_ : null) po painting-canvas.pixels_ true

  rectangle x/int y/int --w/int --h/int --color/int:
    transform.xywh x y w h: | x2 y2 w2 h2 |
      bitmap-rectangle x2 y2 color w2 h2 pixels_ width_

  text x/int y/int --text/string --color/int --font/Font --orientation/int=ORIENTATION-0:
    transform.xyo x y orientation: | x2 y2 o2 |
      bitmap-draw-text x2 y2 color o2 text font pixels_ width_

  // Convert from a PNG color (0 = black, 255 = white) to white or black.
  nearest-color_ palette/ByteArray offset/int -> int:
    return palette[offset] < 128 ? BLACK : WHITE

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
            --destination = pixels_
            --destination-width = width_
      return
    throw "No partially transparent PNGs on 2-color displays."
