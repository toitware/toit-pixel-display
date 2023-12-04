// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Classes useful for $SeveralColorPixelDisplay.
For use with displays that have between 5 and 256 discrete colors.
*/

import bitmap show *
import font show Font
import icons show Icon
import .pixel_display show SeveralColorPixelDisplay  // For the doc comment.
import .one_byte

// The canvas contains a ByteArray.
// Initially all pixels have the 0 color.
class Canvas_ extends OneByteCanvas_:
  constructor width/int height/int:
    super width height

  supports_8_bit -> bool: return true
  gray_scale -> bool: return false

  /**
  Creates a blank canvas with the same dimensions as this one.
  */
  create_similar:
    result := Canvas_ width_ height_
    result.transform=transform
    return result
