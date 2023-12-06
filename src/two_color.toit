// Copyright (C) 2018 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Classes useful for black-and-white $TwoColorPixelDisplay.
For use with e-paper displays and the SSD1306 128x64 display
  (driver at https://pkg.toit.io/package/ssd1306&url=github.com%2Ftoitware%2Ftoit-ssd1306&index=latest)
*/

import bitmap show *
import font show Font
import icons show Icon
import .common
import .pixel_display show TwoColorPixelDisplay  // For the doc comment.
import .texture

WHITE ::= 0
BLACK ::= 1
TRANSPARENT ::= 3

// The canvas contains a bitmapped ByteArray.
// Starts off with/ all pixels white.
class Canvas_ extends Canvas:
  pixels_ := ?

  supports_8_bit -> bool: return false
  gray_scale -> bool: return true

  constructor width/int height/int:
    assert: height & 7 == 0
    size := (width * height) >> 3
    assert: size <= 4000
    pixels_ = ByteArray size
    super width height

  set_all_pixels color/int -> none:
    bitmap_zap pixels_ (color & 1)

  get_pixel_ x y:
    bit := 1 << (y & 7)
    idx := x + width_ * (y >> 3)
    return (pixels_[idx] & bit) == 0 ? 0 : 1

  /**
  Creates a blank texture with the same dimensions as this one.
  */
  create_similar -> Canvas_:
    result := Canvas_ width_ height_
    result.transform = transform
    return result

  make_alpha_map --padding/int=0 -> Canvas:
    result := Canvas_ (width_ + padding) (height_ + padding)
    result.transform = transform
    return result

  composit frame_opacity frame_canvas/Canvas_? painting_opacity painting_canvas/Canvas_:
    fo := frame_opacity is ByteArray ? frame_opacity : frame_opacity.pixels_
    po := painting_opacity is ByteArray ? painting_opacity : painting_opacity.pixels_
    composit_bytes pixels_ fo (frame_canvas ? frame_canvas.pixels_ : null) po painting_canvas.pixels_ true

  rectangle x/int y/int --w/int --h/int --color/int:
    transform.xywh x y w h: | x2 y2 w2 h2 |
      bitmap_rectangle x2 y2 color w2 h2 pixels_ width_

  text x/int y/int --text/string --color/int --font/Font --orientation/int=ORIENTATION_0:
    transform.xyo x y orientation: | x2 y2 o2 |
      bitmap_draw_text x2 y2 color o2 text font pixels_ width_

class FilledRectangle extends FilledRectangle_:
  color_ := ?

  constructor .color_ x/int y/int w/int h/int transform/Transform:
    assert: color_ < 2  // Not transparent.
    super x y w h transform

  /// A line from $x1,$y1 to $x2,$y2.  The line must be horizontal or vertical.
  constructor.line color x1/int y1/int x2/int y2/int transform/Transform:
    return FilledRectangle_.line_ x1 y1 x2 y2: | x y w h |
      FilledRectangle color x y w h transform

  translated_write_ x/int y/int w/int h/int canvas/Canvas_:
    bitmap_rectangle x y color_ w h canvas.pixels_ canvas.width_

class TextTexture extends TextTexture_:
  color_/int := 0

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
  constructor text_x/int text_y/int transform/Transform alignment/int text/string font/Font .color_:
    assert: color_ < 2  // No transparent color.
    super text_x text_y transform alignment text font

  color= new_color/int -> none:
    if color_ == new_color: return
    color_ = new_color
    invalidate

  draw_ bx by orientation canvas/Canvas_:
    bitmap_draw_text bx by color_ orientation string_ font_ canvas.pixels_ canvas.width_

class IconTexture extends TextTexture:
  constructor icon_x/int icon_y/int transform/Transform alignment/int icon/Icon font/Font color/int:
    super icon_x icon_y transform alignment icon.stringify font color

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

  draw_ bx by orientation canvas/Canvas_:
    bitmap_draw_bitmap bx by color_ orientation bytes_ 0 w canvas.pixels_ canvas.width_ false

/**
A two color bitmap texture where foreground and background pixels in the
  texture are both drawn.
Initially all pixels have the background color.
Use $set_pixel to paint with the foreground, and $clear_pixel to paint with
  the background.
*/
class OpaqueBitmapTexture extends BitmapTexture:
  foreground_color_/int := ?
  background_color_/int := ?

  constructor x/int y/int w/int h/int transform/Transform .foreground_color_/int=BLACK .background_color_/int=WHITE:
    super x y w h transform foreground_color_

  write2_ canvas/Canvas_:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      x := x2 - canvas.x_offset_
      y := y2 - canvas.y_offset_
      bitmap_rectangle x y background_color_ w2 h2 canvas.pixels_ canvas.width_
    super canvas  // Draw foreground.

class BarCodeEan13 extends BarCodeEan13_:
  constructor code/string x/int y/int transform/Transform:
    super code x y transform

  white_square_ x y w h canvas/Canvas_:
    white ::= 0
    bitmap_rectangle x y white w h canvas.pixels_ canvas.width_

  digit_ digit x y canvas orientation -> none:
    if digit == "": return
    black ::= 1
    bitmap_draw_text x y black orientation digit sans10_ canvas.pixels_ canvas.width_

  block_ x y width height canvas/Canvas_:
    black ::= 1
    bitmap_rectangle x y black width height canvas.pixels_ canvas.width_

/**
A rectangular window with a fixed width colored border.
The border is subtracted from the visible area inside the window.
*/
class SimpleWindow extends SimpleWindow_:
  background_color/int := ?
  border_color/int := ?

  constructor x/int y/int w/int h/int transform/Transform border_width/int .border_color .background_color:
    super x y w h transform border_width

  draw_frame canvas/Canvas_:
    bitmap_zap canvas.pixels_ border_color

  draw_background canvas/Canvas_:
    bitmap_zap canvas.pixels_ background_color

  make_alpha_map_ canvas/Canvas_:
    return ByteArray (canvas.width_ * canvas.height_) >> 3

  make_opaque_ x y w h map map_width:
    // Paint the border mask with 1's.
    bitmap_rectangle x y 1 w h map map_width

class RoundedCornerWindow extends RoundedCornerWindow_:
  background_color := ?

  constructor x/int y/int w/int h/int transform/Transform corner_radius/int .background_color:
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
    bitmap_zap canvas.pixels_ background_color

  draw_frame canvas/Canvas_:
    throw "UNREACHABLE"

// Pbm documentation: http://netpbm.sourceforge.net/doc/pbm.html
MOST_SIGNIFICANT_BIT_OF_BYTE_MASK_ ::= 0b10000000
draw_pbm texture/BitmapTexture pbm/Pbm --scale=1:
  // TODO(Lau): Check whether the texture is large enough for the bit map.
  pbm.height.repeat: | y |
    row := pbm.row y
    x := 0
    row.size.repeat:
      byte := row[it]
      number_of_bits := 8
      if it == row.size - 1 and pbm.width % 8 != 0: number_of_bits = pbm.width % 8
      number_of_bits.repeat:
        color := (byte & MOST_SIGNIFICANT_BIT_OF_BYTE_MASK_) == 0 ? 0 : 1
        scale_and_set_ color x++ y scale texture
        byte = (byte << 1) & 0xFF

scale_and_set_ color x y scale texture:
  scale.repeat:
    texture_x := scale * x + it
    scale.repeat:
      texture_y := scale * y + it
      if color == 1:
        texture.set_pixel texture_x texture_y
      else:
        texture.clear_pixel texture_x texture_y

class Pbm:
  width_ := 0
  height_ := 0
  rows_ := null
  parser_ := ?

  constructor.parse bytes:
    parser_ = PbmParser_ bytes
    parser_.parse_
    width_ = parser_.width
    height_ = parser_.height

  height: return height_

  width: return width_

  row index/int:
    if not rows_:
      rows_ = parser_.rows
    if not 0 <= index < rows_.size: throw "OUT OF BOUNDS"
    return rows_[index]

// A texture backed by a P4 (binary two-level) PBM file.  The white areas
// (zeros) are rendered transparent and the black areas (ones) are rendered in
// an arbitrary color.  This is normally more efficient than the Pbm class, but
// it cannot scale the image.
class PbmTexture extends BitmapTexture_:
  width_ := 0
  height_ := 0
  color_ := 0
  bytes_ := ?

  // The byte array passed in must be a valid binary-mode (P4) PBM file.
  // If $bytes is a constant literal then it is used directly from
  //   flash.  However if the pixel drawing methods on this are used then
  //   $bytes is moved to RAM and modified.  This could cause an out-of-memory
  //   on very large PBM files.
  constructor x/int y/int transform/Transform .color_/int bytes/ByteArray:
    parser := PbmParser_ bytes
    parser.parse_
    bytes_ = bytes[parser.image_data_offset..]
    super.no_allocate_ x y parser.width parser.height transform

  draw_ bx by orientation canvas/Canvas_:
    bitmap_draw_bitmap bx by color_ orientation bytes_ 0 w canvas.pixels_ canvas.width_ false

// A texture backed by a P4 (binary two-level) PBM file.  This is normally more
// efficient than the Pbm class, but it cannot scale the image.
class OpaquePbmTexture extends PbmTexture:
  // The byte array passed in must be a valid binary-mode (P4) PBM file.
  // If $bytes is a constant literal then it is used directly from
  //   flash.  However if the pixel drawing methods on this are used then
  //   $bytes is moved to RAM and modified.  This could cause an out-of-memory
  //   on very large PBM files.
  constructor x/int y/int transform/Transform bytes/ByteArray:
    foreground ::= 1
    super x y transform foreground bytes

  write2_ canvas/Canvas_:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      x := x2 - canvas.x_offset_
      y := y2 - canvas.y_offset_
      background ::= 0
      bitmap_rectangle x y background w2 h2 canvas.pixels_ canvas.width_
    super canvas
