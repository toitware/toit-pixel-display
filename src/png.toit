// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .common
import .element
import .style show *

import png_tools.png_reader

/**
Element that draws a PNG image.
The width and height of the element is determined by the image.
The image is given by a byte array which is a valid PNG file.
The PNG file can be converted to a Toit byte array using the
   xxxd tool (https://github.com/toitware/xxxd).
The PNG file can be compressed (a normal PNG file) or uncompressed.
  Uncompressed PNG files are produced by pngunzip, which is part of
  the releases of the png-tools package at
  https://github.com/toitware/toit-png-tools
Uncompressed PNG files can still be 1-bit-per-pixel, 2-bit-per-pixel,
  4-bit-per-pixel, or 8-bit-per-pixel, but they do not make use
  of the DEFLATE compression algorithm.  They are still valid PNG
  files that can be read by other tools like editors and browsers.
Uncompressed PNG files do not use much RAM when they are used in
  elements, but they use more flash memory.  When to use compressed
  vs. uncompressed PNG files depends on how frequently the image
  is displayed and how much RAM and flash memory is available.
Only PNGs with up to 8 bits per pixel are supported.  They can be
  generated from any PNG image, for example using the pngquant tool by Lesinski
  and Roelofs.  If you are using compressed PNG files you will get
  better compression by using the --nofs option to disable Floyd-Steinberg
  dithering.  Afterwards, you may want to manipulate the palettes and
  transparency information using pngunzip to make the transparent color fully
  transparent, and the opaque colors fully opaque.
*/
class Png extends CustomElement:
  png_/png_reader.AbstractPng

  /**
  Constructs an element that displays a PNG image, given a byte array
    that contains a valid PNG file with 1-8 bits per pixel.
  See the class documentation of $Png for more information.
  See also $Element.constructor.
  */
  constructor
      --x/int?=null
      --y/int?=null
      --style/Style?=null
      --element_class/string?=null
      --classes/List?=null
      --id/string?=null
      --background=null
      --border/Border?=null
      --png_file/ByteArray:
    info := png_reader.PngInfo png_file
    if info.uncompressed_random_access:
      png_ = png_reader.PngRandomAccess png_file
    else:
      png_ = png_reader.Png png_file
    if png_.bit_depth > 8: throw "UNSUPPORTED"
    if png_.color_type == png_reader.COLOR_TYPE_TRUECOLOR or png_.color_type == png_reader.COLOR_TYPE_TRUECOLOR_ALPHA: throw "UNSUPPORTED"
    super
        --x = x
        --y = y
        --w = png_.width
        --h = png_.height
        --style = style
        --element_class = element_class
        --classes = classes
        --id = id
        --background = background
        --border = border

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
