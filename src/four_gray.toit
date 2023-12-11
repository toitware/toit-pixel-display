// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Constants useful for $PixelDisplay.four-gray.
For use with e-paper displays with four tones of gray.
*/

import bitmap show *
import font show Font
import icons show Icon

import .pixel-display
import .two-bit-texture
import .two-bit-texture as two-bit

/// Color value for use with $PixelDisplay.four-gray.
WHITE ::= 0
/// Color value for use with $PixelDisplay.four-gray.
LIGHT-GRAY ::= 1
/// Color value for use with $PixelDisplay.four-gray.
DARK-GRAY ::= 2
/// Color value for use with $PixelDisplay.four-gray.
BLACK ::= 3

// The canvas contains two bitmapped ByteArrays, giving 4 grays.
//   0    0   White
//   0    1   Light gray
//   1    0   Dark gray
//   1    1   Black
// Starts off with all pixels white.
class Canvas_ extends two-bit.Canvas_:
  constructor width/int height/int:
    super width height

  supports-8-bit -> bool: return false
  gray-scale -> bool: return true

  /**
  Creates a blank texture with the same dimensions as this one.
  */
  create-similar:
    result := Canvas_ width_ height_
    result.transform = transform
    return result

  static NEAREST-TABLE_ ::= #[BLACK, DARK-GRAY, LIGHT-GRAY, WHITE]

  // Convert from a PNG color (0 = black, 255 = white) to a 2-bit 4-gray color.
  nearest-color_ palette/ByteArray offset/int -> int:
    return NEAREST-TABLE_[palette[offset] >> 6]
