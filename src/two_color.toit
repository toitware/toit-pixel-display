// Copyright (C) 2018 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Classes useful for black-and-white $TwoColorPixelDisplay.
For use with e-paper displays and the SSD1306 128x64 display
  (driver at https://pkg.toit.io/package/ssd1306&url=github.com%2Ftoitware%2Ftoit-ssd1306&index=latest)
A texture is an object that can draw itself on a display.
*/

import bitmap show *
import font show Font
import icons show Icon
import .pixel_display show TwoColorPixelDisplay  // For the doc comment.
import .texture

WHITE ::= 0
BLACK ::= 1
TRANSPARENT ::= 3

// The canvas contains a bitmapped ByteArray.
// Starts off with/ all pixels white.
class Canvas:
  width := 0
  height := 0
  pixels_ := ?

  constructor .width .height:
    assert: height & 7 == 0
    size := (width * height) >> 3
    assert: size <= 4000
    pixels_ = ByteArray size

  set_all_pixels color:
    bitmap_zap pixels_ color

  set_pixel color x y:
    bit := 1 << (y & 7)
    idx := x + width * (y >> 3)
    if color == 0:
      pixels_[idx] &= ~bit
    else:
      pixels_[idx] |= bit

  get_pixel x y:
    bit := 1 << (y & 7)
    idx := x + width * (y >> 3)
    return (pixels_[idx] & bit) == 0 ? 0 : 1

  /**
  Creates a blank texture with the same dimensions as this one.
  */
  create_similar:
    return Canvas width height

  composit frame_opacity frame_canvas painting_opacity painting_canvas:
    composit_bytes pixels_ frame_opacity (frame_canvas ? frame_canvas.pixels_ : null) painting_opacity painting_canvas.pixels_ true

class InfiniteBackground extends InfiniteBackground_:
  color_ := ?

  constructor .color_:
    assert: color_ < 2  // Not transparent.

  color -> int:
    return color_

  // No point in calling write for textures under this one.
  write x y canvas:
    bitmap_zap canvas.pixels_ color_

  write_ win_x win_y canvas:
    throw "Not used"

class FilledRectangle extends FilledRectangle_:
  color_ := ?

  constructor .color_ x/int y/int w/int h/int transform/Transform:
    assert: color_ < 2  // Not transparent.
    super x y w h transform

  /// A line from $x1,$y1 to $x2,$y2.  The line must be horizontal or vertical.
  constructor.line color x1/int y1/int x2/int y2/int transform/Transform:
    return FilledRectangle_.line_ x1 y1 x2 y2: | x y w h |
      FilledRectangle color x y w h transform

  translated_write_ x/int y/int w/int h/int canvas:
    bitmap_rectangle x y color_ w h canvas.pixels_ canvas.width

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

  draw_ bx by orientation canvas:
    bitmap_draw_text bx by color_ orientation string_ font_ canvas.pixels_ canvas.width

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

  draw_ bx by orientation canvas:
    bitmap_draw_bitmap bx by color_ orientation bytes_ 0 w canvas.pixels_ canvas.width false

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

  write2_ win_x win_y canvas:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      x := x2 - win_x
      y := y2 - win_y
      bitmap_rectangle x y background_color_ w2 h2 canvas.pixels_ canvas.width
    super win_x win_y canvas  // Draw foreground.

class BarCodeEan13 extends BarCodeEan13_:
  constructor code/string x/int y/int transform/Transform:
    super code x y transform

  white_square_ x y w h canvas:
    white ::= 0
    bitmap_rectangle x y white w h canvas.pixels_ canvas.width

  digit_ digit x y canvas orientation -> none:
    if digit == "": return
    black ::= 1
    bitmap_draw_text x y black orientation digit sans10_ canvas.pixels_ canvas.width

  block_ x y width height canvas:
    black ::= 1
    bitmap_rectangle x y black width height canvas.pixels_ canvas.width

/**
A rectangular window with a fixed width colored border.
The border is subtracted from the visible area inside the window.
*/
class SimpleWindow extends SimpleWindow_:
  background_color/int := ?
  border_color/int := ?

  constructor x/int y/int w/int h/int transform/Transform border_width/int .border_color .background_color:
    super x y w h transform border_width

  draw_frame win_x win_y canvas:
    bitmap_zap canvas.pixels_ border_color

  draw_background win_x win_y canvas:
    bitmap_zap canvas.pixels_ background_color

  make_alpha_map_ canvas:
    return ByteArray (canvas.width * canvas.height) >> 3

  make_opaque_ x y w h map map_width:
    // Paint the border mask with 1's.
    bitmap_rectangle x y 1 w h map map_width

class RoundedCornerWindow extends RoundedCornerWindow_:
  background_color := ?

  constructor x/int y/int w/int h/int transform/Transform corner_radius/int .background_color:
    super x y w h transform corner_radius

  make_alpha_map_ canvas padding:
    return ByteArray (canvas.width + padding) * ((canvas.height + padding + 7) >> 3)

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

  draw_background win_x win_y canvas:
    bitmap_zap canvas.pixels_ background_color

  draw_frame win_x win_y canvas:
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
  offset_ := 0

  // The byte array passed in is expected to continue to exist and be
  // unchanged for the lifetime of the PbmTexture eg because it is
  // backed by a file in flash.
  constructor x/int y/int transform/Transform .color_/int bytes/ByteArray:
    bytes_ = bytes
    parser := PbmParser_ bytes_
    parser.parse_
    super.no_allocate_ x y parser.width parser.height transform
    offset_ = parser.image_data_offset

  set_pixel x y:
    throw "READ_ONLY"

  clear_pixel x y:
    throw "READ_ONLY"

  set_all_pixels:
    throw "READ_ONLY"

  clear_all_pixels:
    throw "READ_ONLY"

  draw_ bx by orientation canvas:
    bitmap_draw_bitmap bx by color_ orientation bytes_ offset_ w canvas.pixels_ canvas.width false

// A texture backed by a P4 (binary two-level) PBM file.  This is normally more
// efficient than the Pbm class, but it cannot scale the image.
class OpaquePbmTexture extends PbmTexture:
  // The byte array passed in is expected to continue to exist and be
  // unchanged for the lifetime of the PbmTexture eg because it is
  // backed by a file in flash.
  constructor x/int y/int transform/Transform bytes/ByteArray:
    foreground ::= 1
    super x y transform foreground bytes

  write2_ win_x win_y canvas:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      x := x2 - win_x
      y := y2 - win_y
      background ::= 0
      bitmap_rectangle x y background w2 h2 canvas.pixels_ canvas.width
    super win_x win_y canvas

class PbmParser_:
  INVALID_PBM_ ::= "INVALID PBM"
  bytes_/ByteArray ::= ?
  next_ := 0

  width := 0
  height := 0
  rows_ := null
  row_byte_length_ := 0
  image_data_offset := 0

  constructor bytes/ByteArray:
    bytes_ = bytes

  parse_:
    parse_magic_number_
    parse_multiple_whitespace_
    width = parse_number_
    parse_multiple_whitespace_ --at_least_one
    height = parse_number_
    parse_whitespace_
    image_data_offset = next_
    parse_bit_map_

  parse_magic_number_:
    if not (bytes_.size > next_ + 1 and bytes_[next_] == 'P' and bytes_[next_ + 1] == '4'): throw INVALID_PBM_
    next_ += 2

  parse_whitespace_:
    if not (bytes_.size > next_ and is_pbm_whitespace_ bytes_[next_]): throw INVALID_PBM_
    next_++

  parse_multiple_whitespace_ --at_least_one=false:
    start := next_
    while bytes_.size > next_ and is_pbm_whitespace_ bytes_[next_]: next_++
    if bytes_.size > next_ and bytes_[next_] == '#':  // Skip comment.
      while bytes_.size > next_ and bytes_[next_] != '\n': next_++
      if bytes_.size > next_: next_++
    if at_least_one and start == next_: throw INVALID_PBM_

  parse_number_ -> int:
    next_ws := next_
    while next_ws < bytes_.size and not is_pbm_whitespace_ bytes_[next_ws]: next_ws++
    if not bytes_.is_valid_string_content next_ next_ws: throw INVALID_PBM_
    number_string := bytes_.to_string next_ next_ws
    number := int.parse number_string --on_error=: throw INVALID_PBM_
    next_ = next_ws
    return number

  parse_bit_map_:
    row_byte_length_ = width / 8 + (width % 8 == 0 ? 0 : 1)
    if not bytes_.size > row_byte_length_ * height: throw INVALID_PBM_

  rows:
    if not rows_:
      rows_ = List height:
        from := next_
        next_ = next_ + row_byte_length_
        bytes_.copy from next_
    return rows_

  is_pbm_whitespace_ byte -> bool:
    return byte == '\t' or byte == '\v' or byte == ' ' or byte == '\n' or byte == '\r' or byte == '\f'
