// Copyright (C) 2020 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Classes useful for $ThreeColorPixelDisplay.
For use with e-paper black, white, and red displays.
*/

import font show Font
import icons show Icon
import .pixel_display show ThreeColorPixelDisplay  // For the doc comment.
import .two_bit_texture
import .two_bit_texture as two_bit

WHITE ::= 0
BLACK ::= 1
RED ::= 2

// The canvas contains two bitmapped ByteArrays, black and red.
// Black Red
//   0    0   White
//   1    0   Black
//   0    1   Red
//   1    1   Invalid
// Starts off with all pixels white.
class Canvas_ extends two_bit.Canvas_:
  constructor width height:
    super width height

  supports_8_bit -> bool: return false
  gray_scale -> bool: return false

  /**
  Creates a blank texture with the same dimensions as this one.
  */
  create_similar:
    result := Canvas_ width_ height_
    result.transform = transform
    return result
