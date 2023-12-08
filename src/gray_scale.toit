// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Constants useful for $PixelDisplay.gray_scale.
*/

import bitmap show *
import font show Font
import icons show Icon
import .pixel_display show PixelDisplay  // For the doc comments.
import .one_byte

/// Color value for use with $PixelDisplay.gray_scale.
WHITE ::= 255
/// Color value for use with $PixelDisplay.gray_scale.
LIGHT_GRAY ::= 170
/// Color value for use with $PixelDisplay.gray_scale.
DARK_GRAY ::= 85
/// Color value for use with $PixelDisplay.gray_scale.
BLACK ::= 0

// The canvas contains a ByteArray.
// Initially all pixels have the 0 color.
class Canvas_ extends OneByteCanvas_:
  constructor width/int height/int:
    super width height

  supports_8_bit -> bool: return true
  gray_scale -> bool: return true

  /**
  Creates a blank canvas with the same dimensions as this one.
  */
  create_similar:
    result := Canvas_ width_ height_
    result.transform=transform
    return result
