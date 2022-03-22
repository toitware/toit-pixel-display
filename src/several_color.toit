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
import .texture
import .one_byte

// The canvas contains a ByteArray.
// Initially all pixels have the 0 color.
class Canvas extends OneByteCanvas_:
  constructor width/int height/int x_offset/int y_offset/int:
    super width height x_offset y_offset

  /**
  Creates a blank texture with the same dimensions as this one.
  */
  create_similar:
    return Canvas width_ height_ x_offset_ y_offset_

class InfiniteBackground extends OneByteInfiniteBackground_:
  constructor color/int:
    super color

class FilledRectangle extends OneByteFilledRectangle_:
  constructor color/int x/int y/int w/int h/int transform/Transform:
    super color x y w h transform

  /// A line from x1,y1 to x2,y2.  The line must be horizontal or vertical.
  constructor.line color x1/int y1/int x2/int y2/int transform/Transform:
    return FilledRectangle_.line_ x1 y1 x2 y2: | x y w h |
      FilledRectangle color x y w h transform

class TextTexture extends OneByteTextTexture_:
  /**
  The coordinates given here to the constructor (and move_to) are the bottom
    left of the first letter in the string (for left alignment).  Once the
    string has been rotated and aligned, and overhanging letter shapes have
    been taken into account, the top left of the bounding box (properties $x,
    $y, inherited from $SizedTexture) reflects the actual top left position
    in the coordinate system of the transform.  In the coordinates of the
    display the getters $display_x, $display_y, $display_w and $display_h
    are available.
  */
  constructor text_x/int text_y/int transform/Transform alignment/int text/string font color/int:
    super text_x text_y transform alignment text font color

class IconTexture extends TextTexture:
  constructor icon_x/int icon_y/int transform/Transform alignment/int icon/Icon font/Font color/int:
    super icon_x icon_y transform alignment icon.stringify icon.font_ color

  icon= new_icon/Icon -> none:
    text = new_icon.stringify
    font = new_icon.font_

/**
A texture that contains an uncompressed 2-color image.  Initially all pixels
  are transparent, but pixels can be given the color with $set_pixel.
*/
class BitmapTexture extends OneByteBitmapTexture_:
  constructor x/int y/int w/int h/int transform/Transform color/int:
    super x y w h transform color

/**
A two color bitmap texture where foreground and background pixels in the
  texture are both drawn.
Initially all pixels have the background color.
Use $set_pixel to paint with the foreground, and $clear_pixel to paint with
  the background.
*/
class OpaqueBitmapTexture extends OneByteOpaqueBitmapTexture_:
  constructor x/int y/int w/int h/int transform/Transform foreground_color/int background_color/int:
    super x y w h transform foreground_color background_color

/**
A texture backed by a P4 (binary two-level) PBM file.
The white areas (zeros) are rendered transparent and the black areas
  (ones) are rendered in an arbitrary color.
*/
class PbmTexture extends OneBytePbmTexture_:
  /**
  The byte array passed in must be a valid binary-mode (P4) PBM file.
  If $bytes is a literal containing constants then it is used directly
    from flash.  However if the pixel drawing methods on this are used then
    $bytes is moved to RAM and modified.  This could cause an out-of-memory
    on very large PBM files.
  */
  constructor x/int y/int transform/Transform color/int bytes/ByteArray:
    super x y transform color bytes

class BarCodeEan13 extends OneByteBarCodeEan13_:
  constructor code/string x/int y/int transform/Transform:
    super code x y transform

  white_ -> int: return 1
  black_ -> int: return 0

class SimpleWindow extends OneByteSimpleWindow_:
  /**
   * A rectangular window with a fixed width colored border.  The border is
   * subtracted from the visible area inside the window.
   */
  constructor x y w h transform border_width border_color/int background_color/int:
    super x y w h transform border_width border_color background_color

  draw_frame canvas/Canvas:
    bytemap_zap canvas.pixels_ border_color

  draw_background canvas/Canvas:
    bytemap_zap canvas.pixels_ background_color

class RoundedCornerWindow extends OneByteRoundedCornerWindow_:
  constructor x y w h transform corner_radius background_color/int:
    super x y w h transform corner_radius background_color

  set_opacity_ x y opacity map map_width --frame/bool:
    if opacity < 0x80:
      opacity = 0
    else:
      opacity = 0xff
    assert: not frame
    if 0 <= x < map_width:
      y_offset := y * map_width
      if 0 <= y_offset < map.size:
        map[x + y_offset] = opacity
