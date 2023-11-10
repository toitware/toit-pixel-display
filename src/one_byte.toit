// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Classes useful for one-byte-per-pixel displays.
// A canvas is a frame buffer that can be drawn on and sent to a display.
// A texture is an object that can draw itself onto a canvas.

import bitmap show *
import font show Font
import icons show Icon
import .common
import .texture

// The canvas contains a ByteArray.
// Initially all pixels are 0.
class OneByteCanvas_ extends AbstractCanvas:
  pixels_ := ?

  constructor width/int height/int:
    size := width * height
    pixels_ = ByteArray size
    super width height

  set_all_pixels color/int -> none:
    bytemap_zap pixels_ color

  get_pixel_ x y:
    return pixels_[x + width_ * y]

  /**
  Creates a blank texture with the same dimensions as this one.
  */
  create_similar:
    result := OneByteCanvas_ width_ height_
    result.transform=transform
    return result

  make_alpha_map --padding/int=0 -> AbstractCanvas:
    result := OneByteCanvas_ (width_ + padding) (height_ + padding)
    result.transform=transform
    return result

  composit frame_opacity frame_canvas/OneByteCanvas_? painting_opacity painting_canvas/OneByteCanvas_:
    fo := frame_opacity is ByteArray ? frame_opacity : frame_opacity.pixels_
    po := painting_opacity is ByteArray ? painting_opacity : painting_opacity.pixels_
    composit_bytes pixels_ fo (frame_canvas ? frame_canvas.pixels_ : null) po painting_canvas.pixels_ false

  rectangle x/int y/int --w/int --h/int --color/int:
    transform.xywh x y w h: | x2 y2 w2 h2 |
      bytemap_rectangle x2 y2 color w2 h2 pixels_ width_

  text x/int y/int --text/string --color/int --font/Font --orientation/int=ORIENTATION_0:
    transform.xyo x y orientation: | x2 y2 o2 |
      bytemap_draw_text x2 y2 color o2 text font pixels_ width_

  bitmap x/int y/int -> none
      --pixels/ByteArray
      --alpha/ByteArray    // 2-element byte array.
      --palette/ByteArray  // 6-element byte array.
      --source_width/int   // In pixels.
      --line_stride/int:   // In bytes.
    throw "Not implemented"

  gray_pixmap x/int y/int --pixels/ByteArray
      --palette/ByteArray=#[]
      --source_width/int
      --orientation/int=ORIENTATION_0:
    transform.xyo x y orientation: | x2 y2 o2 |
      bitmap_draw_bytemap x2 y2 -1 o2 pixels source_width palette pixels_ width_

class OneByteFilledRectangle_ extends FilledRectangle_:
  color_ := ?

  constructor .color_ x/int y/int w/int h/int transform/Transform:
    assert: 0 <= color_ <= 0xff
    super x y w h transform

  translated_write_ x y w h canvas/OneByteCanvas_:
    bytemap_rectangle x y color_ w h canvas.pixels_ canvas.width_

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

  draw_ bx by orientation canvas/OneByteCanvas_:
    bytemap_draw_text bx by color_ orientation string_ font_ canvas.pixels_ canvas.width_

/**
A texture that contains an uncompressed 2-color image.  Initially all pixels
  are transparent, but pixels can be given the color with $set_pixel.
*/
class OneByteBitmapTexture_ extends BitmapTexture_:
  color_ := 0

  constructor x/int y/int w/int h/int transform/Transform .color_/int:
    super x y w h transform

  draw_ bx by orientation canvas/OneByteCanvas_:
    bitmap_draw_bitmap bx by color_ orientation bytes_ 0 w canvas.pixels_ canvas.width_ true

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

  write2_ canvas/OneByteCanvas_:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      x := x2 - canvas.x_offset_
      y := y2 - canvas.y_offset_
      bytemap_rectangle x y background_color_ w2 h2 canvas.pixels_ canvas.width_
    super canvas  // Draw foreground.

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

  draw_ bx by orientation canvas/OneByteCanvas_:
    bitmap_draw_bitmap bx by color_ orientation bytes_ 0 w canvas.pixels_ canvas.width_ true

abstract class OneByteBarCodeEan13_ extends BarCodeEan13_:
  constructor code/string x/int y/int transform/Transform:
    super code x y transform

  abstract white_ -> int
  abstract black_ -> int

  white_square_ x y w h canvas/OneByteCanvas_:
    white ::= 0xff
    bytemap_rectangle x y white_ w h canvas.pixels_ canvas.width_

  digit_ digit x y canvas orientation -> none:
    if digit == "": return
    bytemap_draw_text x y black_ orientation digit sans10_ canvas.pixels_ canvas.width_

  block_ x y width height canvas/OneByteCanvas_:
    bytemap_rectangle x y black_ width height canvas.pixels_ canvas.width_

class OneByteSimpleWindow_ extends SimpleWindow_:
  background_color := ?
  border_color := ?

  /**
  A rectangular window with a fixed width colored border.  The border is
    subtracted from the visible area inside the window.
  */
  constructor x y w h transform border_width .border_color .background_color:
    super x y w h transform border_width

  draw_frame canvas/OneByteCanvas_:
    bytemap_zap canvas.pixels_ border_color

  draw_background canvas/OneByteCanvas_:
    bytemap_zap canvas.pixels_ background_color

  make_alpha_map_ canvas/OneByteCanvas_:
    return ByteArray canvas.width_ * canvas.height_

  make_opaque_ x y w h map map_width:
    bytemap_rectangle x y 0xff w h map map_width

abstract class OneByteRoundedCornerWindow_ extends RoundedCornerWindow_:
  background_color := ?

  constructor x y w h transform corner_radius .background_color:
    super x y w h transform corner_radius

  make_alpha_map_ canvas padding:
    return ByteArray (canvas.width_ + padding) * (canvas.height_ + padding)

  make_opaque_ x y w h map map_width --frame/bool:
    assert: not frame
    bytemap_rectangle x y 0xff w h map map_width

  draw_background canvas/OneByteCanvas_:
    bytemap_zap canvas.pixels_ background_color

  draw_frame canvas/OneByteCanvas_:
    throw "UNREACHABLE"
