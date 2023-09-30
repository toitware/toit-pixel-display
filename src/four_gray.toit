// Copyright (C) 2020 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Classes useful for $FourGrayPixelDisplay.
For use with e-paper displays with four tones of gray.
*/

import .two_bit_texture
import bitmap show *
import font show Font
import icons show Icon
import .pixel_display show FourGrayPixelDisplay  // For the doc comment.
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
  constructor width/int height/int:
    super width height

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

/**
A texture that contains an uncompressed 2-color image.
Initially all pixels are transparent, but pixels can be given the color
  with $set_pixel.
*/
class BitmapTexture extends TwoBitBitmapTexture_:
  constructor x/int y/int w/int h/int transform/Transform color/int:
    super x y w h transform color

/**
A two color bitmap texture where foreground and background pixels in the
  texture are both drawn.
Initially all pixels have the background color.
Use $set_pixel to paint with the foreground, and $clear_pixel to paint with
  the background.
*/
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

  write2_ canvas/Canvas:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      x := x2 - canvas.x_offset_
      y := y2 - canvas.y_offset_
      // Zero out the area of the Pixmap.
      bitmap_rectangle x y 0 w2 h2 canvas.plane_0_ canvas.width_
      bitmap_rectangle x y 0 w2 h2 canvas.plane_1_ canvas.width_
    super canvas  // Calls draw_

  draw_ bx by orientation canvas/Canvas:
    // The area was already zeroed, add in the 1s as needed.
    bitmap_draw_bitmap bx by 1 orientation bytes_ 0 w canvas.plane_0_ canvas.width_ false
    bitmap_draw_bitmap bx by 1 orientation bytes_2_ 0 w canvas.plane_1_ canvas.width_ false

// A texture backed by a P4 (binary two-level) PBM file.  The white areas
// (zeros) are rendered transparent and the black areas (ones) are rendered in
// an arbitrary color.
class PbmTexture extends PbmTexture_:
  // The byte array passed in must be a valid binary-mode (P4) PBM file.
  // If $bytes is a literal containing constants then it is used directly
  //   from flash.  However if the pixel drawing methods on this are used then
  //   $bytes is moved to RAM and modified.  This could cause an out-of-memory
  //   on very large PBM files.
  constructor x/int y/int transform/Transform color/int bytes/ByteArray:
    super x y transform color bytes

class BarCodeEan13 extends TwoBitBarCodeEan13_:
  constructor code/string x/int y/int transform/Transform:
    super code x y transform BLACK WHITE

/**
A rectangular window with a fixed width colored border.
The border is subtracted from the visible area inside the window.
*/
class SimpleWindow extends TwoBitSimpleWindow_:
  constructor x/int y/int w/int h/int transform/Transform border_width/int border_color/int background_color/int:
    super x y w h transform border_width border_color background_color

class RoundedCornerWindow extends RoundedCornerWindow_:
  background_color := ?

  constructor x y w h transform corner_radius .background_color:
    super x y w h transform corner_radius

  make_alpha_map_ canvas/Canvas padding:
    return ByteArray (canvas.width_ + padding) * (canvas.height_ + padding)

  make_opaque_ x y w h map map_width --frame/bool:
    assert: not frame
    bytemap_rectangle x y 0xff w h map map_width

  set_opacity_ x y opacity map map_width --frame/bool:
    assert: not frame
    if 0 <= x < map_width:
      y_offset := y * map_width
      if 0 <= y_offset < map.size:
        map[x + y_offset] = opacity

  draw_background canvas/Canvas:
    bytemap_zap canvas.plane_0_ (background_color & 1)
    bytemap_zap canvas.plane_1_ (background_color & 2) >> 1

  draw_frame canvas/Canvas:
    throw "UNREACHABLE"

class DropShadowWindow extends DropShadowWindow_:
  background_color := ?
  max_shadow_opacity_ := ?

  constructor x y w h transform .background_color --corner_radius=5 --blur_radius=5 --drop_distance_x=10 --drop_distance_y=10 --shadow_opacity_percent=25:
    // Scale the 0-100% opacity percentage to cover the 8 bit unsigned integer
    // range 0-255.
    max_shadow_opacity_ = (shadow_opacity_percent * 2.5500001).to_int
    super x y w h transform corner_radius blur_radius drop_distance_x drop_distance_y

  make_alpha_map_ canvas/Canvas padding:
    return ByteArray (canvas.width_ + padding) * (canvas.height_ + padding)

  make_opaque_ x y w h map map_width --frame/bool:
    bytemap_rectangle x y (frame ? max_shadow_opacity_ : 255) w h map map_width

  set_opacity_ x y opacity map map_width --frame/bool:
    if 0 <= x < map_width:
      y_offset := y * map_width
      if 0 <= y_offset < map.size:
        if frame:
          map[x + y_offset] = (opacity * max_shadow_opacity_) >> 8
        else:
          map[x + y_offset] = opacity

  draw_background canvas/Canvas:
    bytemap_zap canvas.plane_0_ (background_color & 1)
    bytemap_zap canvas.plane_1_ (background_color & 2) >> 1

  draw_frame canvas/Canvas:
    bytemap_zap canvas.plane_0_ 0
    bytemap_zap canvas.plane_1_ 0
