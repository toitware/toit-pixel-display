// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .common
import .element

import png_tools.png_reader show *

// Element that draws a PNG image.
class PngElement extends CustomElement:
  w/int
  h/int
  png_/AbstractPng

  min_w: return w
  min_h: return h

  constructor --x/int?=null --y/int?=null png_file/ByteArray:
    info := PngInfo png_file
    if info.uncompressed_random_access:
      png_ = PngRandomAccess png_file
    else:
      png_ = Png png_file
    if png_.bit_depth > 8: throw "UNSUPPORTED"
    if png_.color_type == COLOR_TYPE_TRUECOLOR or png_.color_type == COLOR_TYPE_TRUECOLOR_ALPHA: throw "UNSUPPORTED"
    w = png_.width
    h = png_.height
    super --x=x --y=y

  // Redraw routine.
  custom_draw canvas/Canvas:
    y2 := 0
    while y2 < h and (canvas.bounds_analysis 0 y2 w (h - y2)) != Canvas.DISJOINT:
      png_.get_indexed_image_data y2 h
          --accept_8_bit=canvas.supports_8_bit
          --need_gray_palette=canvas.gray_scale: | y_from/int y_to/int bits_per_pixel/int pixels/ByteArray line_stride/int palette/ByteArray alpha_palette/ByteArray |
        if bits_per_pixel == 1:
          // Last line a little shorter because it has no stride padding.
          adjust := line_stride - ((round_up w 8) >> 3)
          pixels = pixels[0 .. (y_to - y_from) * line_stride - adjust]
          canvas.bitmap 0 y_from
              --pixels=pixels
              --alpha=alpha_palette
              --palette=palette
              --source_width=w
              --source_line_stride=line_stride
        else:
          adjust := line_stride - w
          pixels = pixels[0 .. (y_to - y_from) * line_stride - adjust]
          canvas.pixmap 0 y_from --pixels=pixels
              --alpha=alpha_palette
              --palette=palette
              --source_width=w
              --source_line_stride=line_stride
        y2 = y_to

  type -> string: return "png"
