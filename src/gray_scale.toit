// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Constants useful for $PixelDisplay.gray-scale.
*/

import bitmap show *
import font show Font
import icons show Icon
import .pixel-display show PixelDisplay  // For the doc comments.
import .one-byte

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

  supports-8-bit -> bool: return true
  gray-scale -> bool: return true

  /**
  Creates a blank canvas with the same dimensions as this one.
  */
  create-similar:
    result := Canvas_ width_ height_
    result.transform=transform
    return result
