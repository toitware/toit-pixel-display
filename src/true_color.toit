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
import .gray_scale as gray_scale_
import .pixel_display show TrueColorPixelDisplay  // For the doc comment.

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
class Canvas_ extends Canvas:
  red_ := ?
  green_ := ?
  blue_ := ?

  supports_8_bit -> bool: return true
  gray_scale -> bool: return false

  constructor width/int height/int:
    size := width * height
    red_ = ByteArray size
    green_ = ByteArray size
    blue_ = ByteArray size
    super width height

  stringify:
    return "true_color.Canvas_ $(width_)x$height_"

  set_all_pixels color/int -> none:
    bytemap_zap red_ (red_component color)
    bytemap_zap green_ (green_component color)
    bytemap_zap blue_ (blue_component color)

  get_pixel_ x y:
    idx := x + width_ * y
    return get_rgb red_[idx] green_[idx] blue_[idx]

  /**
  Creates a blank canvas with the same dimensions as this one.
  */
  create_similar:
    result := Canvas_ width_ height_
    result.transform = transform
    return result

  make_alpha_map --padding/int=0 -> Canvas:
    result := gray_scale_.Canvas_ (width_ + padding) (height_ + padding)
    result.transform = transform
    return result

  composit frame_opacity frame_canvas/Canvas_? painting_opacity painting_canvas/Canvas_:
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
      --alpha/ByteArray         // 2-element byte array.
      --palette/ByteArray       // 6-element byte array.
      --source_width/int        // In pixels.
      --source_line_stride/int  // In bytes.
      --orientation/int=ORIENTATION_0:
    source_byte_width := (source_width + 7) >> 3
    zero_alpha := alpha[0]
    // Fast case if the alpha is either 0 or 0xff, because we can use the
    // primitives that paint 1's with a particular color and leave the zeros
    // transparent.  We don't check for the case where 0 is opaque and 1 is
    // transparent, because pngunzip fixes that for us.
    if alpha[1] == 0xff and (zero_alpha == 0xff or zero_alpha == 0):
      if zero_alpha == 0xff:
        h := (pixels.size + source_line_stride - source_byte_width) / source_line_stride
        // Draw the zeros.
        rectangle x y --w=source_width --h=h --color=(BIG_ENDIAN.uint24 palette 0)
      // Draw the ones.
      transform.xyo x y 0: | x2 y2 o2 |
        bitmap_draw_bitmap x2 y2 --color=palette[3] --orientation=o2 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --destination=red_ --destination_width=width_ --bytewise
        bitmap_draw_bitmap x2 y2 --color=palette[4] --orientation=o2 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --destination=green_ --destination_width=width_ --bytewise
        bitmap_draw_bitmap x2 y2 --color=palette[5] --orientation=o2 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --destination=blue_ --destination_width=width_ --bytewise
      return
    // Unfortunately one of the alpha values is not 0 or 0xff, so we can't use
    // the bitmap draw primitive.  We can blow it up to bytes, then use the
    // bitmap_draw_bytemap.
    h := (pixels.size + source_line_stride - source_byte_width) / source_line_stride
    bytemap := ByteArray source_width * h
    bitmap_draw_bitmap 0 0 --color=1 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --destination=bytemap --destination_width=source_width --bytewise
    transform.xyo x y 0: | x2 y2 o2 |
      bitmap_draw_bytemap x2 y2 --alpha=alpha --orientation=o2 --source=bytemap --source_width=source_width --palette=palette --destination=red_ --destination_width=width_
      bitmap_draw_bytemap x2 y2 --alpha=alpha --orientation=o2 --source=bytemap --source_width=source_width --palette=palette[1..] --destination=green_ --destination_width=width_
      bitmap_draw_bytemap x2 y2 --alpha=alpha --orientation=o2 --source=bytemap --source_width=source_width --palette=palette[2..] --destination=blue_ --destination_width=width_

  pixmap x/int y/int
      --pixels/ByteArray
      --alpha/ByteArray=#[]
      --palette/ByteArray=#[]
      --source_width/int
      --orientation/int=ORIENTATION_0
      --source_line_stride/int=source_width:
    palette_r := palette
    palette_g := palette.size > 0 ? palette[1..] : #[]
    palette_b := palette.size > 1 ? palette[2..] : #[]
    transform.xyo x y orientation: | x2 y2 o2 |
      bitmap_draw_bytemap x2 y2 --alpha=alpha --orientation=o2 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --palette=palette_r --destination=red_ --destination_width=width_
      bitmap_draw_bytemap x2 y2 --alpha=alpha --orientation=o2 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --palette=palette_g --destination=green_ --destination_width=width_
      bitmap_draw_bytemap x2 y2 --alpha=alpha --orientation=o2 --source=pixels --source_width=source_width --source_line_stride=source_line_stride --palette=palette_b --destination=blue_ --destination_width=width_

  rgb_pixmap x/int y/int --r/ByteArray --g/ByteArray --b/ByteArray
      --alpha/ByteArray=#[]
      --palette/ByteArray?=null
      --source_width/int
      --orientation/int=ORIENTATION_0
      --source_line_stride/int=source_width:
    palette_r := palette ? palette : #[]
    palette_g := palette ? palette[1..] : #[]
    palette_b := palette ? palette[2..] : #[]
    transform.xyo x y orientation: | x2 y2 o2 |
      bitmap_draw_bytemap x2 y2 --alpha=alpha --orientation=o2 --source=r --source_width=source_width --source_line_stride=source_line_stride --palette=palette_r --destination=red_ --destination_width=width_
      bitmap_draw_bytemap x2 y2 --alpha=alpha --orientation=o2 --source=g --source_width=source_width --source_line_stride=source_line_stride --palette=palette_g --destination=green_ --destination_width=width_
      bitmap_draw_bytemap x2 y2 --alpha=alpha --orientation=o2 --source=b --source_width=source_width --source_line_stride=source_line_stride --palette=palette_b --destination=blue_ --destination_width=width_
