// Copyright (C) 2020 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Classes useful for $FourGrayPixelDisplay.
For use with e-paper displays with four tones of gray.
*/

import bitmap show *
import font show Font
import icons show Icon
import .common
import .pixel_display show FourGrayPixelDisplay  // For the doc comment.
import .two_bit_texture
import .two_bit_texture as two_bit

WHITE ::= 0
LIGHT_GRAY ::= 1
DARK_GRAY ::= 2
BLACK ::= 3

// The canvas contains two bitmapped ByteArrays, giving 4 grays.
//   0    0   White
//   0    1   Light gray
//   1    0   Dark gray
//   1    1   Black
// Starts off with all pixels white.
class Canvas_ extends two_bit.Canvas_:
  constructor width/int height/int:
    super width height

  supports_8_bit -> bool: return false
  gray_scale -> bool: return true

  /**
  Creates a blank texture with the same dimensions as this one.
  */
  create_similar:
    result := Canvas_ width_ height_
    result.transform = transform
    return result
