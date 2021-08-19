// Copyright (C) 2020 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Classes useful for three-color displays like red-white-black e-ink displays.
// A canvas is a frame buffer that can be drawn on and sent to a display.
// A texture is an object that can draw itself onto a canvas.

import font show Font
import icons show Icon
import .texture
import .two_bit_texture

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
class Canvas extends TwoBitCanvas_:
  constructor width height:
    super width height

class InfiniteBackground extends TwoBitInfiniteBackground_:
  constructor color:
    assert: color != 3   // Invalid color.
    super color

class FilledRectangle extends TwoBitFilledRectangle_:
  constructor color x/int y/int w/int h/int transform/Transform:
    assert: color != 3   // Invalid color.
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
    assert: color != 3   // Invalid color.
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
class BitmapTexture extends TwoBitBitmapTexture_:
  constructor x/int y/int w/int h/int transform/Transform color/int:
    assert: color != 3   // Invalid color.
    super x y w h transform color

// A two color bitmap texture.  Initially all pixels have the background color.
// Use set_pixel to paint with the foreground, and clear_pixel to paint with
// the background.
class OpaqueBitmapTexture extends TwoBitOpaqueBitmapTexture_:
  constructor x/int y/int w/int h/int transform/Transform foreground_color/int background_color:
    assert: background_color != 3   // Invalid color.
    super x y w h transform foreground_color background_color

class BarCodeEan13 extends TwoBitBarCodeEan13_:
  constructor code/string x/int y/int transform/Transform:
    super code x y transform BLACK WHITE

/**
A rectangular window with a fixed width colored border.
The border is subtracted from the visible area inside the window.
*/
class SimpleWindow extends TwoBitSimpleWindow_:
  constructor x y w h transform border_width border_color background_color:
    super x y w h transform border_width border_color background_color

class RoundedCornerWindow extends TwoBitRoundedCornerWindow_:
  constructor x y w h transform corner_radius background_color:
    super x y w h transform corner_radius background_color
