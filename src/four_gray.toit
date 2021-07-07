// Copyright (C) 2020 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Classes useful for 4-gray-scale displays like e-ink displays.
// A canvas is a frame buffer that can be drawn on and sent to a display.
// A texture is an object that can draw itself onto a canvas.

import .two_bit_texture
import bitmap show *
import font show Font
import icons show Icon
import .texture

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
class Canvas extends TwoBitCanvas_:
  constructor width height:
    super width height

class InfiniteBackground extends TwoBitInfiniteBackground_:
  constructor color:
    super color

class FilledRectangle extends TwoBitFilledRectangle_:
  constructor color x/int y/int w/int h/int transform/Transform:
    super color x y w h transform

  /// A line from $x1,$y1 to $x2,$y2.  The line must be horizontal or vertical.
  constructor.line color x1/int y1/int x2/int y2/int transform/Transform:
    return FilledRectangle_.line_ x1 y1 x2 y2: | x y w h |
      FilledRectangle color x y w h transform

class TextTexture extends TwoBitTextTexture_:
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
  constructor text_x/int text_y/int transform/Transform alignment/int text/string font color:
    super text_x text_y transform alignment text font color

class IconTexture extends TwoBitTextTexture_:
  constructor icon_x/int icon_y/int transform/Transform alignment/int icon/Icon font/Font color/int:
    super icon_x icon_y transform alignment icon.stringify icon.font_ color

  icon= new_icon/Icon -> none:
    text = new_icon.stringify
    font = new_icon.font_

/// A texture that contains an uncompressed 2-color image.
/// Initially all pixels are transparent, but pixels can be given the color
///   with $set_pixel.
class BitmapTexture extends TwoBitBitmapTexture_:
  constructor x/int y/int w/int h/int transform/Transform color/int:
    super x y w h transform color

/// A two color bitmap texture.  Initially all pixels have the background color.
/// Use $set_pixel to paint with the foreground, and $clear_pixel to paint with
///   the background.
class OpaqueBitmapTexture extends TwoBitOpaqueBitmapTexture_:

  constructor x/int y/int w/int h/int transform/Transform foreground_color/int background_color:
    super x y w h transform foreground_color background_color

/// A four-color pixmap texture.
/// Use $set_all_pixels to set a background color and $set_pixel to draw.
class OpaquePixmapTexture extends BitmapTextureBase_:
  bytes_/ByteArray ::= ?
  bytes_2_/ByteArray ::= ?

  constructor x/int y/int w/int h/int transform/Transform initial_color/int=0:
    bytes_per_plane := h * ((w + 7) >> 3)  // Divide by 8, rounding up.
    bytes_ = ByteArray bytes_per_plane
    bytes_2_ = ByteArray bytes_per_plane
    super x y w h transform
    set_all_pixels initial_color

  pixel_color x/int y/int -> int:
    index_and_mask_ x y: | index bit |
      lo := (bytes_[index] & bit) == 0 ? 0 : 1
      hi := (bytes_2_[index] & bit) == 0 ? 0 : 2
      return lo + hi
    unreachable

  set_pixel x/int y/int color/int -> none:
    index_and_mask_ x y: | index bit |
      if color & 1 == 0:
        bytes_[index] &= bit ^ 0b1111_1111
      else:
        bytes_[index] |= bit
      if color & 2 == 0:
        bytes_2_[index] &= bit ^ 0b1111_1111
      else:
        bytes_2_[index] |= bit

  set_all_pixels color/int -> none:
    bitmap_zap bytes_ color & 1
    bitmap_zap bytes_2_ (color & 2) >> 1

  write2_ win_x win_y canvas:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      x := x2 - win_x
      y := y2 - win_y
      // Zero out the area of the Pixmap.
      bitmap_rectangle x y 0 w2 h2 canvas.plane_0_ canvas.width
      bitmap_rectangle x y 0 w2 h2 canvas.plane_1_ canvas.width
    super win_x win_y canvas  // Calls draw_

  draw_ bx by orientation canvas:
    // The area was already zeroed, add in the 1s as needed.
    bitmap_draw_bitmap bx by 1 orientation bytes_ 0 w canvas.plane_0_ canvas.width false
    bitmap_draw_bitmap bx by 1 orientation bytes_2_ 0 w canvas.plane_1_ canvas.width false

class BarCodeEan13 extends TwoBitBarCodeEan13_:

  constructor code/string x/int y/int transform/Transform:
    super code x y transform BLACK WHITE

class SimpleWindow extends TwoBitSimpleWindow_:
  /**
  A rectangular window with a fixed width colored border.  The border is
    subtracted from the visible area inside the window.
  */
  constructor x/int y/int w/int h/int transform/Transform border_width/int border_color/int background_color/int:
    super x y w h transform border_width border_color background_color

class RoundedCornerWindow extends TwoBitRoundedCornerWindow_:
  constructor x/int y/int w/int h/int transform/Transform corner_radius/int background_color/int:
    super x y w h transform corner_radius background_color
