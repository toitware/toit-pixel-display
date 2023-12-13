// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import bitmap show *
import font show Font
import .one-byte
import .two-color as two-color
import .pixel-display

// The canvas contains a ByteArray.
// Initially all pixels have the 0 color.
class Canvas_ extends OneByteCanvas_:
  constructor width/int height/int:
    super width height

  constructor.private_ width/int height/int pixels/ByteArray:
    super.private_ width height pixels

  supports-8-bit -> bool: return true
  gray-scale -> bool: return false

  /**
  Creates a blank canvas with the same dimensions as this one.
  */
  create-similar:
    result := Canvas_ width_ height_
    result.transform=transform
    return result

  static NO-MIXING_ ::= #[
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
  ]

  composit frame-opacity frame-canvas/OneByteCanvas_? painting-opacity painting-canvas/OneByteCanvas_:
    fo := frame-opacity is ByteArray ? frame-opacity : frame-opacity.pixels_
    po := painting-opacity is ByteArray ? painting-opacity : painting-opacity.pixels_
    // We can't mix pixels on a palette-based display so all pixels must be 0 or 0xff.
    blit fo fo fo.size --lookup-table=NO-MIXING_
    blit po po fo.size --lookup-table=NO-MIXING_
    composit-bytes pixels_ fo (frame-canvas ? frame-canvas.pixels_ : null) po painting-canvas.pixels_ false

  subcanvas x/int y/int w/int h/int --ignore-x/bool=false --ignore-y/bool=false -> Canvas?:
    return subcanvas-helper_ x y w h ignore-x ignore-y: | y2 h2 |
      from := y2 * width_
      to := (y2 + h2) * width_
      Canvas_.private_ width_ h2 pixels_[from..to]
