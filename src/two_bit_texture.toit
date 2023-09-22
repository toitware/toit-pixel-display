// Copyright (C) 2020 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Classes useful for three- or four-color displays like red-white-black e-ink
// displays.
// A canvas is a frame buffer that can be drawn on and sent to a display.

import bitmap show *
import font show Font
import .texture

// The canvas contains two bitmapped ByteArrays, for up to 4 colors or gray
// scales per pixel.  Starts off with all pixels 0, 0.
class TwoBitCanvas_ extends AbstractCanvas:
  plane_0_ := ?
  plane_1_ := ?

  constructor width/int height/int x_offset/int y_offset/int:
    assert: height & 7 == 0
    size := (width * height) >> 3
    assert: size <= 4000
    plane_0_ = ByteArray size
    plane_1_ = ByteArray size
    super width height x_offset y_offset

  get_pixel_ x y:
    bit := 1 << (y & 7)
    idx := x + width_ * (y >> 3)
    bit0 := (plane_0_[idx] & bit) == 0 ? 0 : 1
    bit1 := (plane_1_[idx] & bit) == 0 ? 0 : 1
    return bit0 + (bit1 << 1)

  /**
  Creates a blank texture with the same dimensions as this one.
  */
  create_similar:
    return TwoBitCanvas_ width_ height_ x_offset_ y_offset_

  composit frame_opacity frame_canvas painting_opacity painting_canvas/TwoBitCanvas_:
    composit_bytes plane_0_ frame_opacity (frame_canvas ? frame_canvas.plane_0_ : null) painting_opacity painting_canvas.plane_0_ true
    composit_bytes plane_1_ frame_opacity (frame_canvas ? frame_canvas.plane_1_ : null) painting_opacity painting_canvas.plane_1_ true

class TwoBitInfiniteBackground_ extends InfiniteBackground_:
  color_ := ?

  constructor .color_:

  color -> int:
    return color_

  write canvas/TwoBitCanvas_:
    bitmap_zap canvas.plane_0_ (color_ & 1)
    bitmap_zap canvas.plane_1_ (color_ & 2) >> 1

  write_ canvas/TwoBitCanvas_:
    throw "Not used"

class TwoBitFilledRectangle_ extends FilledRectangle_:
  color_ := ?

  constructor .color_ x/int y/int w/int h/int transform/Transform:
    super x y w h transform

  translated_write_ x y w h canvas/TwoBitCanvas_:
    bitmap_rectangle x y (color_ & 1)        w h canvas.plane_0_ canvas.width_
    bitmap_rectangle x y ((color_ & 2) >> 1) w h canvas.plane_1_   canvas.width_

class TwoBitTextTexture_ extends TextTexture_:
  color_ := 0

  // The coordinates given here to the constructor (and move_to) are the bottom
  // left of the first letter in the string (for left alignment).  Once the
  // string has been rotated and aligned, and overhanging letter shapes have
  // been taken into account, the bounding box (properties x, y, w, h,
  // inherited from SizedTexture) reflects the actual bounding box of the
  // text string.
  constructor text_x/int text_y/int transform/Transform alignment/int text/string font .color_:
    super text_x text_y transform alignment text font

  color= new_color -> none:
    if color_ == new_color: return
    color_ = new_color
    invalidate

  draw_ bx by orientation canvas/TwoBitCanvas_:
    bitmap_draw_text bx by color_&1        orientation string_ font_ canvas.plane_0_ canvas.width_
    bitmap_draw_text bx by (color_&2) >> 1 orientation string_ font_ canvas.plane_1_ canvas.width_

/**
A texture that contains an uncompressed 2-color image.  Initially all pixels
  are transparent, but pixels can be given the color with $set_pixel.
*/
class TwoBitBitmapTexture_ extends BitmapTexture_:
  color_ := 0

  constructor x/int y/int w/int h/int transform/Transform .color_/int:
    super x y w h transform

  draw_ bx by orientation canvas/TwoBitCanvas_:
    bitmap_draw_bitmap bx by (color_ & 1)        orientation bytes_ 0 w canvas.plane_0_ canvas.width_ false
    bitmap_draw_bitmap bx by ((color_ & 2) >> 1) orientation bytes_ 0 w canvas.plane_1_ canvas.width_ false

/**
A two color bitmap texture where foreground and background pixels in the
  texture are both drawn.
Initially all pixels have the background color.
Use $set_pixel to paint with the foreground, and $clear_pixel to paint with
  the background.
*/
class TwoBitOpaqueBitmapTexture_ extends TwoBitBitmapTexture_:
  background_color_ := 0

  constructor x/int y/int w/int h/int transform/Transform foreground_color/int .background_color_:
    super x y w h transform foreground_color

  write2_ canvas/TwoBitCanvas_:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      x := x2 - canvas.x_offset_
      y := y2 - canvas.y_offset_
      bitmap_rectangle x y (background_color_ & 1) w2 h2 canvas.plane_0_ canvas.width_
      bitmap_rectangle x y ((background_color_ & 2) >> 1) w2 h2 canvas.plane_1_ canvas.width_
    super canvas  // Draw foreground.

// A texture backed by a P4 (binary two-level) PBM file.  The white areas
// (zeros) are rendered transparent and the black areas (ones) are rendered in
// an arbitrary color.
class PbmTexture_ extends BitmapTexture_:
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

  draw_ bx by orientation canvas/TwoBitCanvas_:
    bitmap_draw_bitmap bx by (color_ & 1)        orientation bytes_ 0 w canvas.plane_0_ canvas.width_ false
    bitmap_draw_bitmap bx by ((color_ & 2) >> 1) orientation bytes_ 0 w canvas.plane_1_ canvas.width_ false

class TwoBitBarCodeEan13_ extends BarCodeEan13_:
  black_ := 0
  white_ := 0

  constructor code/string x/int y/int transform/Transform .black_/int .white_/int:
    super code x y transform

  white_square_ x y w h canvas/TwoBitCanvas_:
    bitmap_rectangle x y (white_ & 1) w h canvas.plane_0_ canvas.width_
    bitmap_rectangle x y ((white_ & 2) >> 1) w h canvas.plane_1_ canvas.width_

  digit_ digit x y canvas orientation -> none:
    if digit == "": return
    bitmap_draw_text x y (black_ & 1) orientation digit sans10_ canvas.plane_0_ canvas.width_
    bitmap_draw_text x y ((black_ & 2) >> 1) orientation digit sans10_ canvas.plane_1_ canvas.width_

  block_ x y width height canvas/TwoBitCanvas_:
    bitmap_rectangle x y (black_ & 1) width height canvas.plane_0_ canvas.width_
    bitmap_rectangle x y ((black_ & 2) >> 1) width height canvas.plane_1_ canvas.width_

/**
A rectangular window with a fixed width colored border.
The border is subtracted from the visible area inside the window.
*/
class TwoBitSimpleWindow_ extends SimpleWindow_:
  background_color := ?
  border_color := ?

  constructor x y w h transform border_width .border_color .background_color:
    super x y w h transform border_width

  draw_frame canvas/TwoBitCanvas_:
    bitmap_zap canvas.plane_0_ (border_color & 1)
    bitmap_zap canvas.plane_1_ (border_color & 2) >> 1

  draw_background canvas/TwoBitCanvas_:
    bitmap_zap canvas.plane_0_ (background_color & 1)
    bitmap_zap canvas.plane_1_ (background_color & 2) >> 1

  make_alpha_map_ canvas/TwoBitCanvas_:
    return ByteArray (canvas.width_ * canvas.height_) >> 3

  make_opaque_ x y w h map map_width:
    // Paint the border mask with 1's.
    bitmap_rectangle x y 1 w h map map_width

class TwoBitRoundedCornerWindow_ extends RoundedCornerWindow_:
  background_color := ?

  constructor x y w h transform corner_radius .background_color:
    super x y w h transform corner_radius

  make_alpha_map_ canvas padding:
    return ByteArray (canvas.width_ + padding) * ((canvas.height_ + padding + 7) >> 3)

  make_opaque_ x y w h map map_width --frame/bool:
    assert: not frame
    bitmap_rectangle x y 1 w h map map_width

  set_opacity_ x y opacity map map_width --frame/bool:
    assert: not frame
    if 0 <= x < map_width:
      y_offset := (y >> 3) * map_width
      if 0 <= y_offset < map.size:
        if opacity < 128:
          map[x + y_offset] &= ~(1 << (y & 7))
        else:
          map[x + y_offset] |= 1 << (y & 7)

  draw_background canvas/TwoBitCanvas_:
    bitmap_zap canvas.plane_0_ (background_color & 1)
    bitmap_zap canvas.plane_1_ (background_color & 2) >> 1

  draw_frame canvas/TwoBitCanvas_:
    throw "UNREACHABLE"
