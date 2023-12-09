// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Classes useful for one-byte-per-pixel displays.
// A canvas is a frame buffer that can be drawn on and sent to a display.
// A texture is an object that can draw itself onto a canvas.

import bitmap show *
import font show Font
import icons show Icon
import .common
import .gray-scale as gray-scale_

// The canvas contains a ByteArray.
// Initially all pixels are 0.
abstract class OneByteCanvas_ extends Canvas:
  pixels_ := ?

  constructor width/int height/int:
    size := width * height
    pixels_ = ByteArray size
    super width height

  set-all-pixels color/int -> none:
    bytemap-zap pixels_ color

  get-pixel_ x y:
    return pixels_[x + width_ * y]

  make-alpha-map --padding/int=0 -> gray-scale_.Canvas_:
    result := gray-scale_.Canvas_ (width_ + padding) (height_ + padding)
    result.transform=transform
    return result

  composit frame-opacity frame-canvas/OneByteCanvas_? painting-opacity painting-canvas/OneByteCanvas_:
    fo := frame-opacity is ByteArray ? frame-opacity : frame-opacity.pixels_
    po := painting-opacity is ByteArray ? painting-opacity : painting-opacity.pixels_
    composit-bytes pixels_ fo (frame-canvas ? frame-canvas.pixels_ : null) po painting-canvas.pixels_ false

  rectangle x/int y/int --w/int --h/int --color/int:
    transform.xywh x y w h: | x2 y2 w2 h2 |
      bytemap-rectangle x2 y2 color w2 h2 pixels_ width_

  text x/int y/int --text/string --color/int --font/Font --orientation/int=ORIENTATION-0:
    transform.xyo x y orientation: | x2 y2 o2 |
      bytemap-draw-text x2 y2 color o2 text font pixels_ width_

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
      if zero-alpha == 0xff:  // If the zeros in the bitmap are drawn (opaque).
        h := (pixels.size + source-line-stride - source-byte-width ) / source-line-stride
        // Draw the zeros.
        rectangle x y --w=source-width --h=h --color=palette[0]
      // Draw the ones.
      transform.xyo x y orientation: | x2 y2 o2 |
        bitmap-draw-bitmap x2 y2
            --color = palette[3]
            --orientation = o2
            --source = pixels
            --source-width = source-width
            --source-line-stride = source-line-stride
            --destination = pixels_
            --destination-width = width_
            --bytewise
      return
    // Unfortunately one of the alpha values is not 0 or 0xff, so we can't use
    // the bitmap draw primitive.  We can blow it up to bytes, then use the
    // bitmap-draw-bytemap.
    h := (pixels.size + source-line-stride - source-byte-width ) / source-line-stride
    bytemap := ByteArray source-width * h
    bitmap-draw-bitmap 0 0
        --color = 1
        --source = pixels
        --source-width = source-width
        --source-line-stride = source-line-stride
        --destination = bytemap
        --destination-width = source-width
        --bytewise
    transform.xyo x y 0: | x2 y2 o2 |
      bitmap-draw-bytemap x2 y2
          --alpha = alpha
          --orientation = o2
          --source = bytemap
          --source-width = source-width
          --palette = palette
          --destination = pixels_
          --destination-width = width_

  pixmap x/int y/int
      --pixels/ByteArray
      --alpha/ByteArray=#[]
      --palette/ByteArray=#[]
      --source-width/int
      --orientation/int=ORIENTATION-0
      --source-line-stride/int=source-width:
    transform.xyo x y orientation: | x2 y2 o2 |
      bitmap-draw-bytemap x2 y2
          --alpha = alpha
          --orientation = o2
          --source = pixels
          --source-width = source-width
          --source-line-stride = source-line-stride
          --palette = palette
          --destination = pixels_
          --destination-width = width_
