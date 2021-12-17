// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Classes useful for one-byte-per-pixel displays.
// A canvas is a frame buffer that can be drawn on and sent to a display.
// A texture is an object that can draw itself onto a canvas.

import bitmap show *
import font show Font
import icons show Icon
import .texture

// The canvas contains a ByteArray.
// Initially all pixels are 0.
class OneByteCanvas_:
  width := 0
  height := 0
  pixels_ := ?

  constructor .width .height:
    size := width * height
    pixels_ = ByteArray size

  set_all_pixels color:
    bytemap_zap pixels_ color

  set_pixel color x y:
    pixels_[x + width * y] = color

  get_pixel x y:
    return pixels_[x + width * y]

  composit frame_opacity frame_canvas painting_opacity painting_canvas:
    composit_bytes pixels_ frame_opacity (frame_canvas ? frame_canvas.pixels_ : null) painting_opacity painting_canvas.pixels_ false

class OneByteInfiniteBackground_ extends InfiniteBackground_:
  color_ := 0

  constructor .color_:

  color -> int:
    return color_

  write x y canvas:
    bytemap_zap canvas.pixels_ color_

  write_ win_x win_y canvas:
    throw "Not used"

class OneByteFilledRectangle_ extends FilledRectangle_:
  color_ := ?

  constructor .color_ x/int y/int w/int h/int transform/Transform:
    assert: 0 <= color_ <= 0xff
    super x y w h transform

  translated_write_ x y w h canvas:
    bytemap_rectangle x y color_ w h canvas.pixels_ canvas.width

class OneByteTextTexture_ extends TextTexture_:
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

/**
A texture that contains an uncompressed 2-color image.  Initially all pixels
  are transparent, but pixels can be given the color with $set_pixel.
*/
class OneByteBitmapTexture_ extends BitmapTexture_:
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
class OneByteOpaqueBitmapTexture_ extends OneByteBitmapTexture_:
  background_color_ := 0

  constructor x/int y/int w/int h/int transform/Transform foreground_color/int .background_color_:
    super x y w h transform foreground_color

  write2_ win_x win_y canvas:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      x := x2 - win_x
      y := y2 - win_y
      bytemap_rectangle x y background_color_ w2 h2 canvas.pixels_ canvas.width
    super win_x win_y canvas  // Draw foreground.

/**
A texture backed by a P4 (binary two-level) PBM file.
The white areas (zeros) are rendered transparent and the black areas
  (ones) are rendered in an arbitrary color.
*/
class OneBytePbmTexture_ extends BitmapTexture_:
  width_ := 0
  height_ := 0
  color_ := 0
  bytes_ := ?

  /**
  The byte array passed in must be a valid binary-mode (P4) PBM file.
  If $bytes is a literal containing constants then it is used directly
    from flash.  However if the pixel drawing methods on this are used then
    $bytes is moved to RAM and modified.  This could cause an out-of-memory
    on very large PBM files.
  */
  constructor x/int y/int transform/Transform .color_/int bytes/ByteArray:
    parser := PbmParser_ bytes
    parser.parse_
    bytes_ = bytes[parser.image_data_offset..]
    super.no_allocate_ x y parser.width parser.height transform

  draw_ bx by orientation canvas:
    bitmap_draw_bitmap bx by color_ orientation bytes_ 0 w canvas.pixels_ canvas.width true

abstract class OneByteBarCodeEan13_ extends BarCodeEan13_:
  constructor code/string x/int y/int transform/Transform:
    super code x y transform

  abstract white_ -> int
  abstract black_ -> int

  white_square_ x y w h canvas:
    white ::= 0xff
    bytemap_rectangle x y white_ w h canvas.pixels_ canvas.width

  digit_ digit x y canvas orientation -> none:
    if digit == "": return
    bytemap_draw_text x y black_ orientation digit sans10_ canvas.pixels_ canvas.width

  block_ x y width height canvas:
    bytemap_rectangle x y black_ width height canvas.pixels_ canvas.width

class OneByteSimpleWindow_ extends SimpleWindow_:
  background_color := ?
  border_color := ?

  /**
  A rectangular window with a fixed width colored border.  The border is
    subtracted from the visible area inside the window.
  */
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

abstract class OneByteRoundedCornerWindow_ extends RoundedCornerWindow_:
  background_color := ?

  constructor x y w h transform corner_radius .background_color:
    super x y w h transform corner_radius

  make_alpha_map_ canvas padding:
    return ByteArray (canvas.width + padding) * (canvas.height + padding)

  make_opaque_ x y w h map map_width --frame/bool:
    assert: not frame
    bytemap_rectangle x y 0xff w h map map_width

  draw_background win_x win_y canvas:
    bytemap_zap canvas.pixels_ background_color

  draw_frame win_x win_y canvas:
    throw "UNREACHABLE"
