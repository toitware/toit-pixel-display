// Copyright (C) 2018 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Classes useful for black-and-white $TwoColorPixelDisplay.
For use with e-paper displays and the SSD1306 128x64 display
  (driver at https://pkg.toit.io/package/ssd1306&url=github.com%2Ftoitware%2Ftoit-ssd1306&index=latest)
*/

import bitmap show *
import font show Font
import icons show Icon
import .common
import .pixel_display show TwoColorPixelDisplay  // For the doc comment.

WHITE ::= 0
BLACK ::= 1
TRANSPARENT ::= 3

// The canvas contains a bitmapped ByteArray.
// Starts off with/ all pixels white.
class Canvas_ extends Canvas:
  pixels_ := ?

  supports_8_bit -> bool: return false
  gray_scale -> bool: return true

  constructor width/int height/int:
    assert: height & 7 == 0
    size := (width * height) >> 3
    assert: size <= 4000
    pixels_ = ByteArray size
    super width height

  set_all_pixels color/int -> none:
    bitmap_zap pixels_ (color & 1)

  get_pixel_ x y:
    bit := 1 << (y & 7)
    idx := x + width_ * (y >> 3)
    return (pixels_[idx] & bit) == 0 ? 0 : 1

  /**
  Creates a blank canvas with the same dimensions as this one.
  */
  create_similar -> Canvas_:
    result := Canvas_ width_ height_
    result.transform = transform
    return result

  make_alpha_map --padding/int=0 -> Canvas:
    result := Canvas_ (width_ + padding) (height_ + padding)
    result.transform = transform
    return result

  composit frame_opacity frame_canvas/Canvas_? painting_opacity painting_canvas/Canvas_:
    fo := frame_opacity is ByteArray ? frame_opacity : frame_opacity.pixels_
    po := painting_opacity is ByteArray ? painting_opacity : painting_opacity.pixels_
    composit_bytes pixels_ fo (frame_canvas ? frame_canvas.pixels_ : null) po painting_canvas.pixels_ true

  rectangle x/int y/int --w/int --h/int --color/int:
    transform.xywh x y w h: | x2 y2 w2 h2 |
      bitmap_rectangle x2 y2 color w2 h2 pixels_ width_

  text x/int y/int --text/string --color/int --font/Font --orientation/int=ORIENTATION_0:
    transform.xyo x y orientation: | x2 y2 o2 |
      bitmap_draw_text x2 y2 color o2 text font pixels_ width_
