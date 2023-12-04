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
import .two_color as two_color

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

  static NO_MIXING_ := ByteArray 0x100: it < 0x80 ? 0 : 0xff

  composit frame_opacity frame_canvas/OneByteCanvas_? painting_opacity painting_canvas/OneByteCanvas_:
    fo := frame_opacity is ByteArray ? frame_opacity : frame_opacity.pixels_
    po := painting_opacity is ByteArray ? painting_opacity : painting_opacity.pixels_
    // We can't mix pixels on a palette-based display so all pixels must be 0 or 0xff.
    blit fo fo fo.size --lookup_table=NO_MIXING_
    blit po po fo.size --lookup_table=NO_MIXING_
    composit_bytes pixels_ fo (frame_canvas ? frame_canvas.pixels_ : null) po painting_canvas.pixels_ false
