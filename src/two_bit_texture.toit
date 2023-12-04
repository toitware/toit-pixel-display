// Copyright (C) 2020 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Classes useful for three- or four-color displays like red-white-black e-ink
// displays.
// A canvas is a frame buffer that can be drawn on and sent to a display.

import bitmap show *
import font show Font
import .common
import .common as common
import .two_color as two_color

// The canvas contains two bitmapped ByteArrays, for up to 4 colors or gray
// scales per pixel.  Starts off with all pixels 0, 0.
abstract class Canvas_ extends Canvas:
  plane_0_ := ?
  plane_1_ := ?

  constructor width/int height/int:
    assert: height & 7 == 0
    size := (width * height) >> 3
    assert: size <= 4000
    plane_0_ = ByteArray size
    plane_1_ = ByteArray size
    super width height

  set_all_pixels color/int -> none:
    bitmap_zap plane_0_ (color & 1)
    bitmap_zap plane_1_ ((color & 2) >> 1)

  get_pixel_ x y:
    bit := 1 << (y & 7)
    idx := x + width_ * (y >> 3)
    bit0 := (plane_0_[idx] & bit) == 0 ? 0 : 1
    bit1 := (plane_1_[idx] & bit) == 0 ? 0 : 1
    return bit0 + (bit1 << 1)

  make_alpha_map --padding/int=0 -> Canvas:
    result := two_color.Canvas_ (width_ + padding) (height_ + padding)
    result.transform = transform
    return result

  composit frame_opacity frame_canvas painting_opacity painting_canvas/Canvas_:
    fo := frame_opacity is ByteArray ? frame_opacity : frame_opacity.pixels_
    po := painting_opacity is ByteArray ? painting_opacity : painting_opacity.pixels_
    composit_bytes plane_0_ fo (frame_canvas ? frame_canvas.plane_0_ : null) po painting_canvas.plane_0_ true
    composit_bytes plane_1_ fo (frame_canvas ? frame_canvas.plane_1_ : null) po painting_canvas.plane_1_ true

  rectangle x/int y/int --w/int --h/int --color/int:
    transform.xywh x y w h: | x2 y2 w2 h2 |
      c2 := (color & 2) >> 1
      bitmap_rectangle x2 y2 (color & 1) w2 h2 plane_0_ width_
      bitmap_rectangle x2 y2 c2          w2 h2 plane_1_ width_

  text x/int y/int --text/string --color/int --font/Font --orientation/int=ORIENTATION_0:
    transform.xyo x y orientation: | x2 y2 o2 |
      b0 := color & 1
      b1 := (color >> 1) & 1
      bitmap_draw_text x2 y2 b0 o2 text font plane_0_ width_
      bitmap_draw_text x2 y2 b1 o2 text font plane_1_ width_

  abstract nearest_color_ palette/ByteArray offset/int -> int

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
        rectangle x y --w=source_width --h=h --color=(nearest_color_ palette 0)
      // Draw the ones.
      transform.xyo x y orientation: | x2 y2 o2 |
        color := nearest_color_ palette 3
        bitmap_draw_bitmap x2 y2 --color=(color & 1) --orientation=o2 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --destination=plane_0_ --destination_width=width_
        bitmap_draw_bitmap x2 y2 --color=(color >> 1) --orientation=o2 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --destination=plane_1_ --destination_width=width_
      return
    throw "No partially transparent PNGs on 3-color displays."
