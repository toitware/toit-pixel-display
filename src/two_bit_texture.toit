// Copyright (C) 2020 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Classes useful for three- or four-color displays like red-white-black e-ink
// displays.
// A canvas is a frame buffer that can be drawn on and sent to a display.

import bitmap show *
import font show Font
import .common
import .two_color as two_color
import .texture

// The canvas contains two bitmapped ByteArrays, for up to 4 colors or gray
// scales per pixel.  Starts off with all pixels 0, 0.
abstract class Canvas_ extends AbstractCanvas:
  plane_0_ := ?
  plane_1_ := ?

  constructor width/int height/int:
    assert: height & 7 == 0
    size := (width * height) >> 3
    assert: size <= 4000
    plane_0_ = ByteArray size
    plane_1_ = ByteArray size
    super width height

  set_all_pixels color/int -> none:
    bitmap_zap plane_0_ (color & 1)
    bitmap_zap plane_1_ ((color & 2) >> 1)

  get_pixel_ x y:
    bit := 1 << (y & 7)
    idx := x + width_ * (y >> 3)
    bit0 := (plane_0_[idx] & bit) == 0 ? 0 : 1
    bit1 := (plane_1_[idx] & bit) == 0 ? 0 : 1
    return bit0 + (bit1 << 1)

  make_alpha_map --padding/int=0 -> AbstractCanvas:
    result := two_color.Canvas_ (width_ + padding) (height_ + padding)
    result.transform = transform
    return result

  composit frame_opacity frame_canvas painting_opacity painting_canvas/Canvas_:
    fo := frame_opacity is ByteArray ? frame_opacity : frame_opacity.pixels_
    po := painting_opacity is ByteArray ? painting_opacity : painting_opacity.pixels_
    composit_bytes plane_0_ fo (frame_canvas ? frame_canvas.plane_0_ : null) po painting_canvas.plane_0_ true
    composit_bytes plane_1_ fo (frame_canvas ? frame_canvas.plane_1_ : null) po painting_canvas.plane_1_ true

  rectangle x/int y/int --w/int --h/int --color/int:
    transform.xywh x y w h: | x2 y2 w2 h2 |
      c2 := (color & 2) >> 1
      bitmap_rectangle x2 y2 (color & 1) w2 h2 plane_0_ width_
      bitmap_rectangle x2 y2 c2          w2 h2 plane_1_ width_

  text x/int y/int --text/string --color/int --font/Font --orientation/int=ORIENTATION_0:
    transform.xyo x y orientation: | x2 y2 o2 |
      b0 := color & 1
      b1 := (color >> 1) & 1
      bitmap_draw_text x2 y2 b0 o2 text font plane_0_ width_
      bitmap_draw_text x2 y2 b1 o2 text font plane_1_ width_

  abstract nearest_color_ palette/ByteArray offset/int -> int

  bitmap x/int y/int -> none
      --pixels/ByteArray
      --alpha/ByteArray    // 2-element byte array.
      --palette/ByteArray  // 4 element byte array.
      --source_width/int   // In pixels.
      --source_line_stride/int:   // In bytes.
    source_byte_width := (source_width + 7) >> 3
    zero_alpha := alpha[0]
    // Fast case if the alpha is either 0 or 0xff, because we can use the
    // primitives that paint 1's with a particular color and leave the zeros
    // transparent.  We don't check for the case where 0 is opaque and 1 is
    // transparent, because pngunzip fixes that for us.
    if alpha[1] == 0xff and (zero_alpha == 0xff or zero_alpha == 0):
      if zero_alpha == 0xff:
        h := (pixels.size + source_line_stride - source_byte_width ) / source_line_stride
        // Draw the zeros.
        rectangle x y --w=source_width --h=h --color=(nearest_color_ palette 0)
      // Draw the ones.
      transform.xyo x y 0: | x2 y2 o2 |
        color := nearest_color_ palette 3
        bitmap_draw_bitmap x2 y2 --color=(color & 1) --orientation=o2 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --destination=plane_0_ --destination_width=width_
        bitmap_draw_bitmap x2 y2 --color=(color >> 1) --orientation=o2 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --destination=plane_1_ --destination_width=width_
      return
    throw "No partially transparent PNGs on 3-color displays."

  pixmap x/int y/int
      --pixels/ByteArray
      --alpha/ByteArray=#[]
      --palette/ByteArray=#[]
      --source_width/int
      --orientation/int=ORIENTATION_0
      --source_line_stride/int=source_width:
   throw "Unimplemented"

class TwoBitFilledRectangle_ extends FilledRectangle_:
  color_ := ?

  constructor .color_ x/int y/int w/int h/int transform/Transform:
    super x y w h transform

  translated_write_ x y w h canvas/Canvas_:
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

  draw_ bx by orientation canvas/Canvas_:
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

  draw_ bx by orientation canvas/Canvas_:
    bitmap_draw_bitmap bx by --color=(color_ & 1)        --orientation=orientation --source=bytes_ --source_width=w --destination=canvas.plane_0_ --destination_width=canvas.width_
    bitmap_draw_bitmap bx by --color=((color_ & 2) >> 1) --orientation=orientation --source=bytes_ --source_width=w --destination=canvas.plane_1_ --destination_width=canvas.width_

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

  write2_ canvas/Canvas_:
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

  draw_ bx by orientation canvas/Canvas_:
    bitmap_draw_bitmap bx by --color=(color_ & 1)        --orientation=orientation --source=bytes_ --source_width=w --destination=canvas.plane_0_ --destination_width=canvas.width_
    bitmap_draw_bitmap bx by --color=((color_ & 2) >> 1) --orientation=orientation --source=bytes_ --source_width=w --destination=canvas.plane_1_ --destination_width=canvas.width_

class TwoBitBarCodeEan13_ extends BarCodeEan13_:
  black_ := 0
  white_ := 0

  constructor code/string x/int y/int transform/Transform .black_/int .white_/int:
    super code x y transform

  white_square_ x y w h canvas/Canvas_:
    bitmap_rectangle x y (white_ & 1) w h canvas.plane_0_ canvas.width_
    bitmap_rectangle x y ((white_ & 2) >> 1) w h canvas.plane_1_ canvas.width_

  digit_ digit x y canvas orientation -> none:
    if digit == "": return
    bitmap_draw_text x y (black_ & 1) orientation digit sans10_ canvas.plane_0_ canvas.width_
    bitmap_draw_text x y ((black_ & 2) >> 1) orientation digit sans10_ canvas.plane_1_ canvas.width_

  block_ x y width height canvas/Canvas_:
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

  draw_frame canvas/Canvas_:
    bitmap_zap canvas.plane_0_ (border_color & 1)
    bitmap_zap canvas.plane_1_ (border_color & 2) >> 1

  draw_background canvas/Canvas_:
    bitmap_zap canvas.plane_0_ (background_color & 1)
    bitmap_zap canvas.plane_1_ (background_color & 2) >> 1

  make_alpha_map_ canvas/Canvas_:
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

  draw_background canvas/Canvas_:
    bitmap_zap canvas.plane_0_ (background_color & 1)
    bitmap_zap canvas.plane_1_ (background_color & 2) >> 1

  draw_frame canvas/Canvas_:
    throw "UNREACHABLE"
