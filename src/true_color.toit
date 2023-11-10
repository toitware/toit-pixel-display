// Copyright (C) 2018 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Classes useful for RGB $TrueColorPixelDisplay.
*/

import binary show BIG_ENDIAN
import bitmap show *
import font show Font
import icons show Icon
import .common
import .one_byte show OneByteCanvas_
import .pixel_display show TrueColorPixelDisplay  // For the doc comment.
import .texture

get_rgb r/int g/int b/int -> int:
  return (r << 16) | (g << 8) | b

WHITE ::= 0xff_ff_ff
BLACK ::= 0

red_component pixel/int -> int:
  return pixel >> 16

green_component pixel/int -> int:
  return (pixel >> 8) & 0xff

blue_component pixel/int -> int:
  return pixel & 0xff

// The canvas contains three ByteArrays, red, green, and blue.
// 0 is black, 255 is max intensity.  Initially all pixels are black.
class Canvas extends AbstractCanvas:
  red_ := ?
  green_ := ?
  blue_ := ?

  constructor width/int height/int:
    size := width * height
    red_ = ByteArray size
    green_ = ByteArray size
    blue_ = ByteArray size
    super width height

  stringify:
    return "true_color.Canvas $(width_)x$height_"

  set_all_pixels color/int -> none:
    bytemap_zap red_ (red_component color)
    bytemap_zap green_ (green_component color)
    bytemap_zap blue_ (blue_component color)

  get_pixel_ x y:
    idx := x + width_ * y
    return get_rgb red_[idx] green_[idx] blue_[idx]

  /**
  Creates a blank texture with the same dimensions as this one.
  */
  create_similar:
    result := Canvas width_ height_
    result.transform = transform
    return result

  make_alpha_map --padding/int=0 -> AbstractCanvas:
    result := OneByteCanvas_ (width_ + padding) (height_ + padding)
    result.transform = transform
    return result

  composit frame_opacity frame_canvas/Canvas? painting_opacity painting_canvas/Canvas:
    fo := frame_opacity is ByteArray ? frame_opacity : frame_opacity.pixels_
    po := painting_opacity is ByteArray ? painting_opacity : painting_opacity.pixels_
    composit_bytes red_ fo (frame_canvas ? frame_canvas.red_ : null) po painting_canvas.red_ false
    composit_bytes green_ fo (frame_canvas ? frame_canvas.green_ : null) po painting_canvas.green_ false
    composit_bytes blue_ fo (frame_canvas ? frame_canvas.blue_ : null) po painting_canvas.blue_ false

  rectangle x/int y/int --w/int --h/int --color/int:
    transform.xywh x y w h: | x2 y2 w2 h2 |
      r := color >> 16
      g := (color >> 8) & 0xff
      b := color & 0xff
      bytemap_rectangle x2 y2 r w2 h2 red_   width_
      bytemap_rectangle x2 y2 g w2 h2 green_ width_
      bytemap_rectangle x2 y2 b w2 h2 blue_  width_

  text x/int y/int --text/string --color/int --font/Font --orientation/int=ORIENTATION_0:
    transform.xyo x y orientation: | x2 y2 o2 |
      r := color >> 16
      g := (color >> 8) & 0xff
      b := color & 0xff
      bytemap_draw_text x2 y2 r o2 text font red_ width_
      bytemap_draw_text x2 y2 g o2 text font green_ width_
      bytemap_draw_text x2 y2 b o2 text font blue_ width_

  bitmap x/int y/int -> none
      --pixels/ByteArray
      --alpha/ByteArray    // 2-element byte array.
      --palette/ByteArray  // 6-element byte array.
      --source_width/int   // In pixels.
      --line_stride/int:   // In bytes.
    source_byte_width := (source_width + 7) >> 3
    zero_alpha := alpha[0]
    // Fast case if the alpha is either 0 or 0xff, because we can use the
    // primitives that paint 1's with a particular color and leave the zeros
    // transparent.  We don't check for the case where 0 is opaque and 1 is
    // transparent, because pngunzip fixes that for us.
    if alpha[1] == 0xff and (zero_alpha == 0xff or zero_alpha == 0):
      if zero_alpha == 0xff:
        h := pixels.size / source_byte_width
        // Draw the zeros.
        rectangle x y --w=source_width --h=h --color=(BIG_ENDIAN.uint24 palette 0)
      // Draw the ones.
      transform.xyo x y 0: | x2 y2 orientation |
        bitmap_draw_bitmap x2 y2 palette[3] orientation pixels 0 source_width line_stride red_ width_ true
        bitmap_draw_bitmap x2 y2 palette[4] orientation pixels 0 source_width line_stride green_ width_ true
        bitmap_draw_bitmap x2 y2 palette[5] orientation pixels 0 source_width line_stride blue_ width_ true
      return
    // Unfortunately one of the alpha values is not 0 or 0xff, so we can't use
    // the bitmap draw primitive.  We can blow it up to bytes, then use the
    // bitmap_draw_bytemap.
    h := pixels.size / source_byte_width
    bytemap := ByteArray source_width * h
    bitmap_draw_bitmap 0 0 1 0 pixels 0 source_width line_stride bytemap source_width true
    transform.xyo x y 0: | x2 y2 orientation |
      bitmap_draw_bytemap x2 y2 alpha orientation bytemap source_width source_width palette red_ width_
      bitmap_draw_bytemap x2 y2 alpha orientation bytemap source_width source_width palette[1..] green_ width_
      bitmap_draw_bytemap x2 y2 alpha orientation bytemap source_width source_width palette[2..] blue_ width_

  rgb_pixmap x/int y/int --r/ByteArray --g/ByteArray --b/ByteArray
      --alpha=-1
      --palette/ByteArray?=null
      --source_width/int
      --orientation/int=ORIENTATION_0
      --line_stride/int=source_width:
    palette_r := palette ? palette : #[]
    palette_g := palette ? palette[1..] : #[]
    palette_b := palette ? palette[2..] : #[]
    transform.xyo x y orientation: | x2 y2 o2 |
      bitmap_draw_bytemap x2 y2 alpha o2 r source_width line_stride palette_r red_ width_
      bitmap_draw_bytemap x2 y2 alpha o2 g source_width line_stride palette_g green_ width_
      bitmap_draw_bytemap x2 y2 alpha o2 b source_width line_stride palette_b blue_ width_

class FilledRectangle extends FilledRectangle_:
  color_ := ?

  constructor .color_ x/int y/int w/int h/int transform/Transform:
    assert: color_ <= 0xff_ff_ff  // Not transparent.
    super x y w h transform

  /// A line from $x1,$y1 to $x2,$y2.  The line must be horizontal or vertical.
  constructor.line color x1/int y1/int x2/int y2/int transform/Transform:
    return FilledRectangle_.line_ x1 y1 x2 y2: | x y w h |
      FilledRectangle color x y w h transform

  translated_write_ x y w h canvas/Canvas:
    if bytemap_rectangle x y (red_component color_)   w h canvas.red_   canvas.width_:
       bytemap_rectangle x y (green_component color_) w h canvas.green_ canvas.width_
       bytemap_rectangle x y (blue_component color_)  w h canvas.blue_  canvas.width_

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
    assert: color_ <= 0xff_ff_ff  // No transparent color.
    super text_x text_y transform alignment text font

  color= new_color -> none:
    if color_ == new_color: return
    color_ = new_color
    invalidate

  draw_ bx by orientation canvas/Canvas:
    bytemap_draw_text bx by (red_component color_) orientation string_ font_ canvas.red_ canvas.width_
    bytemap_draw_text bx by (green_component color_) orientation string_ font_ canvas.green_ canvas.width_
    bytemap_draw_text bx by (blue_component color_) orientation string_ font_ canvas.blue_ canvas.width_

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

  draw_ bx by orientation canvas/Canvas:
    bitmap_draw_bitmap bx by (red_component color_) orientation bytes_ 0 w canvas.red_ canvas.width_ true
    bitmap_draw_bitmap bx by (green_component color_) orientation bytes_ 0 w canvas.green_ canvas.width_ true
    bitmap_draw_bitmap bx by (blue_component color_) orientation bytes_ 0 w canvas.blue_ canvas.width_ true

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

  write2_ canvas/Canvas:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      x := x2 - canvas.x_offset_
      y := y2 - canvas.y_offset_
      bytemap_rectangle x y (red_component background_color_) w2 h2 canvas.red_ canvas.width_
      bytemap_rectangle x y (green_component background_color_) w2 h2 canvas.green_ canvas.width_
      bytemap_rectangle x y (blue_component background_color_) w2 h2 canvas.blue_ canvas.width_
    super canvas  // Draw foreground.

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

  draw_ bx by orientation canvas/Canvas:
    bitmap_draw_bitmap bx by (red_component color_)   orientation bytes_ 0 w canvas.red_   canvas.width_ true
    bitmap_draw_bitmap bx by (green_component color_) orientation bytes_ 0 w canvas.green_ canvas.width_ true
    bitmap_draw_bitmap bx by (blue_component color_)  orientation bytes_ 0 w canvas.blue_  canvas.width_ true

/**
A rectangular pixmap that can be drawn in any of 4 orientations on a canvas.
Up to 255 different colors can be represented.  Each color to be used
  is allocated and given an index by $allocate_color.  In addition there is
  a transparent index, always index 0.
*/
class IndexedPixmapTexture extends PixmapTexture_:
  bytes_/ByteArray ::= ?
  palette_/ByteArray := ?
  green_palette_/ByteArray? := null
  blue_palette_/ByteArray? := null
  used_indices_/int := 1

  /**
  Creates a pixmap. All pixels are initially transparent.
  */
  constructor x/int y/int w/int h/int transform/Transform:
    bytes_ = ByteArray w * h
    palette_ = #[0]
    super x y w h transform

  /**
  Creates a pixmap with the given pixels and palette.
  Transparent pixels are represented by zero bytes.
  The palette byte array contains 3 bytes (r, g, b) for each
    index in use.  The first three entries in the palette are
    ignored since they correspond to the transparent index.
  */
  constructor x/int y/int w/int h/int transform/Transform .bytes_/ByteArray .palette_/ByteArray:
    if bytes_.size != w * h: throw "INVALID_ARGUMENT"
    if palette_.size % 3 != 0: throw "INVALID_ARGUMENT"
    used_indices_ = palette_.size / 3
    super x y w h transform

  /**
  Gets the index in the palette for a given color, expressed with components from 0-255.
  This can be quite slow if there are a lot of colors.
  At most 255 colors can be allocated.
  */
  allocate_color r/int g/int b/int -> int:
    for i := 1; i < used_indices_; i++:
      if r == (red_component i) and g == (green_component i) and b == (blue_component i): return i
    if used_indices_ == 0x100: throw "No more colors available"
    if palette_.size / 3 <= (round_up used_indices_ 16):
      old := palette_
      palette_ = ByteArray palette_.size + 48
      palette_.replace 0 old
      green_palette_ = null
      blue_palette_ = null
    palette_[used_indices_ * 3] = r
    palette_[used_indices_ * 3 + 1] = g
    palette_[used_indices_ * 3 + 2] = b
    return used_indices_++

  /**
  Gets the index in the palette for a given color, expressed as a 6 digit hex value 0xrrggbb.
  This can be quite slow if there are a lot of colors.
  At most 255 colors can be allocated.
  */
  allocate_color color/int -> int:
    return allocate_color
      color >> 16
      (color >> 8) & 0xff
      color & 0xff

  /// Looks up the index in the palette.
  red_component index/int -> int:
    return palette_[index * 3]

  /// Looks up the index in the palette.
  green_component index/int -> int:
    return palette_[index * 3 + 1]

  /// Looks up the index in the palette.
  blue_component index/int -> int:
    return palette_[index * 3 + 2]

  /// Returns the index value of the color at the given coordinates.
  get_pixel x/int y/int -> int:
    return bytes_[x + y * w]

  set_pixel x/int y/int index/int -> none:
    bytes_[x + y * w] = index

  /// Sets the pixel at the given coordinates to transparent.
  clear_pixel x/int y/int -> none:
    set_pixel x y 0

  set_all_pixels index/int -> none:
    bitmap_zap bytes_ index

  /// Sets all pixels to transparent.
  clear_all_pixels -> none:
    bitmap_zap bytes_ 0

  draw_ bx by orientation canvas/Canvas:
    if not green_palette_: green_palette_ = palette_[1..]
    if not blue_palette_: blue_palette_ = palette_[2..]
    bitmap_draw_bytemap bx by 0 orientation bytes_ w w palette_       canvas.red_   canvas.width_
    bitmap_draw_bytemap bx by 0 orientation bytes_ w w green_palette_ canvas.green_ canvas.width_
    bitmap_draw_bytemap bx by 0 orientation bytes_ w w blue_palette_  canvas.blue_  canvas.width_

class BarCodeEan13 extends BarCodeEan13_:
  constructor code/string x/int y/int transform/Transform:
    super code x y transform

  white_square_ x y w h canvas/Canvas:
    white ::= 0xff
    if bytemap_rectangle x y white w h canvas.red_   canvas.width_:
       bytemap_rectangle x y white w h canvas.green_ canvas.width_
       bytemap_rectangle x y white w h canvas.blue_ canvas.width_

  digit_ digit x y canvas orientation -> none:
    if digit == "": return
    black ::= 0
    bytemap_draw_text x y black orientation digit sans10_ canvas.red_   canvas.width_
    bytemap_draw_text x y black orientation digit sans10_ canvas.green_ canvas.width_
    bytemap_draw_text x y black orientation digit sans10_ canvas.blue_  canvas.width_

  block_ x y width height canvas/Canvas:
    black ::= 0
    if bytemap_rectangle x y black width height canvas.red_   canvas.width_:
       bytemap_rectangle x y black width height canvas.green_ canvas.width_
       bytemap_rectangle x y black width height canvas.blue_  canvas.width_

/**
A rectangular window with a fixed width colored border.
The border is subtracted from the visible area inside the window.
*/
class SimpleWindow extends SimpleWindow_:
  background_color := ?
  border_color := ?

  constructor x y w h transform border_width .border_color .background_color:
    super x y w h transform border_width

  draw_frame canvas/Canvas:
    bytemap_zap canvas.red_ (red_component border_color)
    bytemap_zap canvas.green_ (green_component border_color)
    bytemap_zap canvas.blue_ (blue_component border_color)

  draw_background canvas/Canvas:
    bytemap_zap canvas.red_ (red_component background_color)
    bytemap_zap canvas.green_ (green_component background_color)
    bytemap_zap canvas.blue_ (blue_component background_color)

  make_alpha_map_ canvas/Canvas:
    return ByteArray canvas.width_ * canvas.height_

  make_opaque_ x y w h map map_width:
    bytemap_rectangle x y 0xff w h map map_width

class RoundedCornerWindow extends RoundedCornerWindow_:
  background_color := ?

  constructor x y w h transform corner_radius .background_color:
    super x y w h transform corner_radius

  make_alpha_map_ canvas padding:
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
    bytemap_zap canvas.red_ (red_component background_color)
    bytemap_zap canvas.green_ (green_component background_color)
    bytemap_zap canvas.blue_ (blue_component background_color)

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

  make_alpha_map_ canvas padding:
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
    bytemap_zap canvas.red_ (red_component background_color)
    bytemap_zap canvas.green_ (green_component background_color)
    bytemap_zap canvas.blue_ (blue_component background_color)

  draw_frame canvas/Canvas:
    bytemap_zap canvas.red_ 0
    bytemap_zap canvas.green_ 0
    bytemap_zap canvas.blue_ 0
