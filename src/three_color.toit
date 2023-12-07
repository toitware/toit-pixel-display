// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Constants useful for $PixelDisplay.three_color.
For use with e-paper black, white, and red displays.
*/

import font show Font
import icons show Icon
import .pixel_display show PixelDisplay  // For the doc comment.
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

  // Convert from a PNG color (0 = black, 255 = white) to a 2-bit
  // red-white-black color.
  nearest_color_ palette/ByteArray offset/int -> int:
    r := palette[offset]
    g := palette[offset + 1]
    b := palette[offset + 2]
    if r > 0x60 and r > g + b: return RED
    value := (r * 77 + g * 150 + b * 29) >> 14
    return value < 2 ? BLACK : WHITE
