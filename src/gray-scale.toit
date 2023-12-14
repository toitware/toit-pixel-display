// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Constants useful for $pixel-display.PixelDisplay.gray-scale.
These are displays with 8-bit pixels, where each pixel is a gray-scale value
  from 0 (black) to 255 (white).
*/

import bitmap show *
import font show Font

import .pixel-display
import .pixel-display as pixel-display
import .one-byte_

/// Color value for use with $PixelDisplay.gray-scale.
WHITE ::= 255
/// Color value for use with $PixelDisplay.gray-scale.
LIGHT-GRAY ::= 170
/// Color value for use with $PixelDisplay.gray-scale.
DARK-GRAY ::= 85
/// Color value for use with $PixelDisplay.gray-scale.
BLACK ::= 0

// The canvas contains a ByteArray.
// Initially all pixels have the 0 color.
class Canvas_ extends OneByteCanvas_:
  constructor width/int height/int:
    super width height

  constructor.private_ width/int height/int pixels/ByteArray:
    super.private_ width height pixels

  supports-8-bit -> bool: return true
  gray-scale -> bool: return true

  /**
  Creates a blank canvas with the same dimensions as this one.
  */
  create-similar:
    result := Canvas_ width_ height_
    result.transform=transform
    return result

  subcanvas x/int y/int w/int h/int --ignore-x/bool=false --ignore-y/bool=false -> Canvas?:
    return subcanvas-helper_ x y w h ignore-x ignore-y: | y2 h2 |
      from := y2 * width_
      to := (y2 + h2) * width_
      Canvas_.private_ width_ h2 pixels_[from..to]
