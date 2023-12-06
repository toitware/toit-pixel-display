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

  make_alpha_map --padding/int=0 -> Canvas:
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

  pixmap x/int y/int
      --pixels/ByteArray
      --alpha/ByteArray=#[]
      --palette/ByteArray=#[]
      --source_width/int
      --orientation/int=ORIENTATION_0
      --source_line_stride/int=source_width:
    transform.xyo x y orientation: | x2 y2 o2 |
      bitmap_draw_bytemap x2 y2 --alpha=alpha --orientation=o2 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --palette=palette --destination=pixels_ --destination_width=width_
