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
import .gray_scale as gray_scale_

// The canvas contains a ByteArray.
// Initially all pixels are 0.
abstract class OneByteCanvas_ extends Canvas:
  pixels_ := ?

  constructor width/int height/int:
    size := width * height
    pixels_ = ByteArray size
    super width height

  set_all_pixels color/int -> none:
    bytemap_zap pixels_ color

  get_pixel_ x y:
    return pixels_[x + width_ * y]

  make_alpha_map --padding/int=0 -> gray_scale_.Canvas_:
    result := gray_scale_.Canvas_ (width_ + padding) (height_ + padding)
    result.transform=transform
    return result

  composit frame_opacity frame_canvas/OneByteCanvas_? painting_opacity painting_canvas/OneByteCanvas_:
    fo := frame_opacity is ByteArray ? frame_opacity : frame_opacity.pixels_
    po := painting_opacity is ByteArray ? painting_opacity : painting_opacity.pixels_
    composit_bytes pixels_ fo (frame_canvas ? frame_canvas.pixels_ : null) po painting_canvas.pixels_ false

  rectangle x/int y/int --w/int --h/int --color/int:
    transform.xywh x y w h: | x2 y2 w2 h2 |
      bytemap_rectangle x2 y2 color w2 h2 pixels_ width_

  text x/int y/int --text/string --color/int --font/Font --orientation/int=ORIENTATION_0:
    transform.xyo x y orientation: | x2 y2 o2 |
      bytemap_draw_text x2 y2 color o2 text font pixels_ width_

  bitmap x/int y/int -> none
      --pixels/ByteArray
      --alpha/ByteArray         // 2-element byte array.
      --palette/ByteArray       // 4 element byte array.
      --source_width/int        // In pixels.
      --source_line_stride/int  // In bytes.
      --orientation/int=ORIENTATION_0:
    source_byte_width := (source_width + 7) >> 3
    zero_alpha := alpha[0]
    // Fast case if the alpha is either 0 or 0xff, because we can use the
    // primitives that paint 1's with a particular color and leave the zeros
    // transparent.  We don't check for the case where 0 is opaque and 1 is
    // transparent, because pngunzip fixes that for us.
    if alpha[1] == 0xff and (zero_alpha == 0xff or zero_alpha == 0):
      if zero_alpha == 0xff:
        h := (pixels.size + source_line_stride - source_byte_width ) / source_line_stride
        // Draw the zeros.
        rectangle x y --w=source_width --h=h --color=palette[0]
      // Draw the ones.
      transform.xyo x y orientation: | x2 y2 o2 |
        bitmap_draw_bitmap x2 y2 --color=palette[3] --orientation=o2 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --destination=pixels_ --destination_width=width_ --bytewise
      return
    // Unfortunately one of the alpha values is not 0 or 0xff, so we can't use
    // the bitmap draw primitive.  We can blow it up to bytes, then use the
    // bitmap_draw_bytemap.
    h := (pixels.size + source_line_stride - source_byte_width ) / source_line_stride
    bytemap := ByteArray source_width * h
    bitmap_draw_bitmap 0 0 --color=1 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --destination=bytemap --destination_width=source_width --bytewise
    transform.xyo x y 0: | x2 y2 o2 |
      bitmap_draw_bytemap x2 y2 --alpha=alpha --orientation=o2 --source=bytemap --source_width=source_width --palette=palette --destination=pixels_ --destination_width=width_

  pixmap x/int y/int
      --pixels/ByteArray
      --alpha/ByteArray=#[]
      --palette/ByteArray=#[]
      --source_width/int
      --orientation/int=ORIENTATION_0
      --source_line_stride/int=source_width:
    transform.xyo x y orientation: | x2 y2 o2 |
      bitmap_draw_bytemap x2 y2 --alpha=alpha --orientation=o2 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --palette=palette --destination=pixels_ --destination_width=width_
