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
import .texture

WHITE ::= 255
LIGHT_GRAY ::= 170
DARK_GRAY ::= 85
BLACK ::= 0

// The canvas contains a ByteArray.
// 0 is black, 255 is max intensity.  Initially all pixels are black.
class Canvas:
  width := 0
  height := 0
  pixels_ := ?

  constructor .width .height:
    size := width * height
    assert: size <= 4000
    pixels_ = ByteArray size

  stringify:
    return "gray_scale.Canvas $(width)x$height"

  set_all_pixels color:
    bytemap_zap pixels_ color

  set_pixel color x y:
    pixels_[x + width * y] = color

  get_pixel x y:
    return pixels_[x + width * y]

  /**
  Creates a blank texture with the same dimensions as this one.
  */
  create_similar:
    return Canvas width height

  composit frame_opacity frame_canvas painting_opacity painting_canvas:
    composit_bytes pixels_ frame_opacity (frame_canvas ? frame_canvas.pixels_ : null) painting_opacity painting_canvas.pixels_ false

class InfiniteBackground extends InfiniteBackground_:
  color_ := 0

  constructor .color_:

  color -> int:
    return color_

  write x y canvas:
    bytemap_zap canvas.pixels_ color_

  write_ win_x win_y canvas:
    throw "Not used"

class FilledRectangle extends FilledRectangle_:
  color_ := ?

  constructor .color_ x/int y/int w/int h/int transform/Transform:
    assert: 0 <= color_ <= 0xff
    super x y w h transform

  /// A line from $x1,$y1 to $x2,$y2.  The line must be horizontal or vertical.
  constructor.line color x1/int y1/int x2/int y2/int transform/Transform:
    return FilledRectangle_.line_ x1 y1 x2 y2: | x y w h |
      FilledRectangle color x y w h transform

  translated_write_ x y w h canvas:
    bytemap_rectangle x y color_ w h canvas.pixels_ canvas.width

class TextTexture extends TextTexture_:
  color_ := 0

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
  constructor text_x/int text_y/int transform/Transform alignment/int text/string font .color_:
    assert: 0 <= color_ <= 0xff
    super text_x text_y transform alignment text font

  color= new_color -> none:
    if color_ == new_color: return
    color_ = new_color
    invalidate

  draw_ bx by orientation canvas:
    bytemap_draw_text bx by color_ orientation string_ font_ canvas.pixels_ canvas.width

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
class BitmapTexture extends BitmapTexture_:
  color_ := 0

  constructor x/int y/int w/int h/int transform/Transform .color_/int:
    super x y w h transform

  draw_ bx by orientation canvas:
    bitmap_draw_bitmap bx by color_ orientation bytes_ 0 w canvas.pixels_ canvas.width true

/**
A two color bitmap texture where foreground and background pixels in the
  texture are both drawn.
Initially all pixels have the background color.
Use $set_pixel to paint with the foreground, and $clear_pixel to paint with
  the background.
*/
class OpaqueBitmapTexture extends BitmapTexture:
  background_color_ := 0

  constructor x/int y/int w/int h/int transform/Transform foreground_color/int .background_color_:
    super x y w h transform foreground_color

  write2_ win_x win_y canvas:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      x := x2 - win_x
      y := y2 - win_y
      bytemap_rectangle x y background_color_ w2 h2 canvas.pixels_ canvas.width
    super win_x win_y canvas  // Draw foreground.

// A texture backed by a P4 (binary two-level) PBM file.  The white areas
// (zeros) are rendered transparent and the black areas (ones) are rendered in
// an arbitrary color.
class PbmTexture extends BitmapTexture_:
  width_ := 0
  height_ := 0
  color_ := 0
  bytes_ := ?

  // The byte array passed in must be a valid binary-mode (P4) PBM file.
  // If $bytes is a literal containing constants then it is used directly
  //   from flash.  However if the pixel drawing methods on this are used then
  //   $bytes is moved to RAM and modified.  This could cause an out-of-memory
  //   on very large PBM files.
  constructor x/int y/int transform/Transform .color_/int bytes/ByteArray:
    parser := PbmParser_ bytes
    parser.parse_
    bytes_ = bytes[parser.image_data_offset..]
    super.no_allocate_ x y parser.width parser.height transform

  draw_ bx by orientation canvas:
    bitmap_draw_bitmap bx by color_ orientation bytes_ 0 w canvas.pixels_ canvas.width true

/**
A rectangular pixmap that can be drawn in any of 4 orientations on a canvas.
*/
class PixmapTexture extends PixmapTexture_:
  bytes_/ByteArray ::= ?
  palette_/ByteArray ::= #[]
  transparency_/bool ::= ?

  /**
  Creates a pixmap. All pixels are initially transparent.
  */
  constructor x/int y/int w/int h/int transform/Transform:
    transparency_ = true
    bytes_ = ByteArray w * h: 42
    super x y w h transform

  /**
  Creates a pixmap with the given pixels.  No transparency is supported.
  The pixel byte array should have the size $w * $h.
  */
  constructor x/int y/int w/int h/int transform/Transform .bytes_/ByteArray:
    if bytes_.size != w * h: throw "INVALID_ARGUMENT"
    transparency_ = false
    super x y w h transform

  /**
  Brightness value of the gray shade at the given coordinates.
  Returns -1 if the pixel is transparent at that coordinate.
  */
  get_pixel x/int y/int -> int:
    result := bytes_[x + y * w]
    if not transparency_:
      return result
    return result = 42 ? -1 : result

  /**
  Set the brightness value of the gray shade at the given coordinates
    between 0 and 255.
  Setting the brightness to -1 makes the pixel transparent for a pixmap
    that supports transparency.  For transparency-supporting pixmaps,
    one value cannot be set because it is reserved, so if you set the
    pixel to a brightness of 42 it will silently use 41 instead.
  */
  set_pixel x/int y/int index/int -> none:
    if not transparency_:
      if index == 42:
        index = 41
      else if index == -1:
        index = 42
    if not 0 <= index <= 0xff: throw "Invalid pixel"
    bytes_[x + y * w] = index

  /**
  Set pixel to transparent.
  Throws an error if the pixmap was created without transparency.
  */
  clear_pixel x/int y/int -> none:
    if not transparency_: throw "No transparency"
    set_pixel x y 42

  /**
  Set the brightness value of the gray shade on the entire pixmap
    between 0 and 255.
  Setting the brightness to -1 makes the pixmap transparent for a pixmap
    that supports transparency.  For transparency-supporting pixmaps,
    one value cannot be set because it is reserved, so if you set the
    pixmap to a brightness of 42 it will silently use 41 instead.
  */
  set_all_pixels index/int -> none:
    if not transparency_:
      if index == 42:
        index = 41
      else if index == -1:
        index = 42
    if not 0 <= index <= 0xff: throw "Invalid pixel"
    bitmap_zap bytes_ index

  /**
  Set all pixels to transparent.
  Throws an error if the pixmap was created without transparency.
  */
  clear_all_pixels -> none:
    if not transparency_: throw "No transparency"
    bitmap_zap bytes_ 42

  draw_ bx by orientation canvas:
    if transparency_:
      bitmap_draw_bytemap bx by 42 orientation bytes_ w palette_ canvas.pixels_ canvas.width
    else:
      bitmap_draw_bytemap bx by -1 orientation bytes_ w palette_ canvas.pixels_ canvas.width

class BarCodeEan13 extends BarCodeEan13_:
  constructor code/string x/int y/int transform/Transform:
    super code x y transform

  white_square_ x y w h canvas:
    white ::= 0xff
    bytemap_rectangle x y white w h canvas.pixels_ canvas.width

  digit_ digit x y canvas orientation -> none:
    if digit == "": return
    black ::= 0
    bytemap_draw_text x y black orientation digit sans10_ canvas.pixels_ canvas.width

  block_ x y width height canvas:
    black ::= 0
    bytemap_rectangle x y black width height canvas.pixels_ canvas.width

/**
A rectangular window with a fixed width colored border.
The border is subtracted from the visible area inside the window.
*/
class SimpleWindow extends SimpleWindow_:
  background_color := ?
  border_color := ?

  constructor x y w h transform border_width .border_color .background_color:
    super x y w h transform border_width

  draw_frame win_x win_y canvas:
    bytemap_zap canvas.pixels_ border_color

  draw_background win_x win_y canvas:
    bytemap_zap canvas.pixels_ background_color

  make_alpha_map_ canvas:
    return ByteArray canvas.width * canvas.height

  make_opaque_ x y w h map map_width:
    bytemap_rectangle x y 0xff w h map map_width

class RoundedCornerWindow extends RoundedCornerWindow_:
  background_color := ?

  constructor x y w h transform corner_radius .background_color:
    super x y w h transform corner_radius

  make_alpha_map_ canvas padding:
    return ByteArray (canvas.width + padding) * (canvas.height + padding)

  make_opaque_ x y w h map map_width --frame/bool:
    assert: not frame
    bytemap_rectangle x y 0xff w h map map_width

  set_opacity_ x y opacity map map_width --frame/bool:
    assert: not frame
    if 0 <= x < map_width:
      y_offset := y * map_width
      if 0 <= y_offset < map.size:
        map[x + y_offset] = opacity

  draw_background win_x win_y canvas:
    bytemap_zap canvas.pixels_ background_color

  draw_frame win_x win_y canvas:
    throw "UNREACHABLE"

class DropShadowWindow extends DropShadowWindow_:
  background_color := ?
  max_shadow_opacity_ := ?

  constructor x y w h transform .background_color --corner_radius=5 --blur_radius=5 --drop_distance_x=10 --drop_distance_y=10 --shadow_opacity_percent=25:
    // Scale the 0-100% opacity percentage to cover the 8 bit unsigned integer
    // range 0-255.
    max_shadow_opacity_ = (shadow_opacity_percent * 2.5500001).to_int
    super x y w h transform corner_radius blur_radius drop_distance_x drop_distance_y

  make_alpha_map_ canvas padding:
    return ByteArray (canvas.width + padding) * (canvas.height + padding)

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

  draw_background win_x win_y canvas:
    bytemap_zap canvas.pixels_ background_color

  draw_frame win_x win_y canvas:
    bytemap_zap canvas.pixels_ 0
