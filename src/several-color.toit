// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import bitmap show *
import font show Font
import icons show Icon
import .one-byte
import .two-color as two-color

// The canvas contains a ByteArray.
// Initially all pixels have the 0 color.
class Canvas_ extends OneByteCanvas_:
  constructor width/int height/int:
    super width height

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
