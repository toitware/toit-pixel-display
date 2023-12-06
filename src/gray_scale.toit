// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Classes useful for $GrayScalePixelDisplay.
For use with monochrome displays with many tones of gray.
*/

import bitmap show *
import font show Font
import icons show Icon
import .pixel_display show GrayScalePixelDisplay  // For the doc comment.
import .one_byte

WHITE ::= 255
LIGHT_GRAY ::= 170
DARK_GRAY ::= 85
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
