// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .element
import .style show *
import .pixel-display

import png-tools.png-reader

/**
Element that draws a PNG image.
The width and height of the element is determined by the image.
The image is given by a byte array, png-file, which must be a valid PNG file.
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
  png_/png-reader.AbstractPng
  last-palette_/ByteArray? := null
  last-alpha-palette_/ByteArray? := null
  last-transformed-palette_/ByteArray? := null
  last-transformed-alpha-palette_/ByteArray? := null
  palette-transformer_/PaletteTransformer? := null
  palette-transformer-buffer_/ByteArray? := null

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
      --classes/List?=null
      --id/string?=null
      --background=null
      --border/Border?=null
      --png-file/ByteArray
      --color/int?=null
      --palette-transformer/PaletteTransformer?=null:
    palette-transformer_ = palette-transformer
    info := png-reader.PngInfo png-file
    if info.uncompressed-random-access:
      png_ = png-reader.PngRandomAccess png-file
    else:
      png_ = png-reader.Png png-file
    if png_.bit-depth > 8: throw "UNSUPPORTED"
    if png_.color-type == png-reader.COLOR-TYPE-TRUECOLOR or png_.color-type == png-reader.COLOR-TYPE-TRUECOLOR-ALPHA: throw "UNSUPPORTED"
    super
        --x = x
        --y = y
        --w = png_.width
        --h = png_.height
        --style = style
        --classes = classes
        --id = id
        --background = background
        --border = border
    if color: this.color = color

  /**
  Causes the PNG to be redrawn with new values from the palette transformer.
  */
  invalidate-palette-transformer -> none:
    invalidate
    last-transformed-palette_ = null
    last-transformed-alpha-palette_ = null

  /**
  Causes the palette of the PNG to be ignored, and all pixels will
    be drawn with the given color.  Alpha (transparency) will be
    unchanged.
  */
  color= value/int -> none:
    invalidate-palette-transformer
    palette-transformer_ = SingleColorPaletteTransformer_ value

  set-attribute_ key/string value -> none:
    if key == "color":
      color = value
    else:
      super key value
  /**
  The $palette-transformer is an optional PaletteTransformer that transforms
    the colors in the PNG.  This can be used for example if you have a PNG
    that is black-and-transparent, and you want to display it as an
    image that is red-and-transparent.
  The palette transformer is not called eagerly, so if it is
    going to return new values (eg. to change the color of the PNG)
    you must call $invalidate-palette-transformer.
  A simpler way to use palette transformation is to simply set the
    color on this element. This will cause all PNG pixels to be
    drawn with the same color, but alpha (transparency) will still
    be taken from the PNG file.
  */
  palette-transformer= value/PaletteTransformer?:
    invalidate-palette-transformer
    palette-transformer_ = value

  // Redraw routine.
  custom-draw canvas/Canvas:
    y2 := 0
    while y2 < h and (canvas.bounds-analysis 0 y2 w (h - y2)) != Canvas.DISJOINT:
      png_.get-indexed-image-data y2 h
          --accept-8-bit=canvas.supports-8-bit
          --need-gray-palette=canvas.gray-scale: | y-from/int y-to/int bits-per-pixel/int pixels/ByteArray line-stride/int palette/ByteArray alpha-palette/ByteArray |
        if palette-transformer_:
          if palette != last-palette_ or alpha-palette != last-alpha-palette_:
            if last-transformed-alpha-palette_ == null or
                last-transformed-palette_.size != palette.size:
              last-transformed-palette_ = ByteArray palette.size
            if last-transformed-alpha-palette_ == null or
                last-transformed-alpha-palette_.size != palette.size:
              last-transformed-alpha-palette_ = ByteArray palette.size
          if palette-transformer-buffer_ == null:
            palette-transformer-buffer_ = ByteArray 4
          (palette.size / 3).repeat: | i |
            3.repeat:
              palette-transformer-buffer_[it] = palette[i * 3 + it]
            palette-transformer-buffer_[3] = alpha-palette[i]
            palette-transformer_.transform palette-transformer-buffer_
            3.repeat:
              last-transformed-palette_[i * 3 + it] = palette-transformer-buffer_[it]
            last-transformed-alpha-palette_[i] = palette-transformer-buffer_[3]
          palette = last-transformed-palette_
          alpha-palette = last-transformed-alpha-palette_
        if bits-per-pixel == 1:
          // Last line a little shorter because it has no stride padding.
          adjust := line-stride - ((round-up w 8) >> 3)
          pixels = pixels[0 .. (y-to - y-from) * line-stride - adjust]
          canvas.bitmap 0 y-from
              --pixels=pixels
              --alpha=alpha-palette
              --palette=palette
              --source-width=w
              --source-line-stride=line-stride
        else:
          adjust := line-stride - w
          pixels = pixels[0 .. (y-to - y-from) * line-stride - adjust]
          canvas.pixmap 0 y-from --pixels=pixels
              --alpha=alpha-palette
              --palette=palette
              --source-width=w
              --source-line-stride=line-stride
        y2 = y-to

  type -> string: return "png"

interface PaletteTransformer:
  /**
  Takes a 4-element byte array in rgba order and modifies the
    byte array to indicate which color and transparency should
    be used instead.
  */
  transform rgba/ByteArray -> none

class SingleColorPaletteTransformer_ implements PaletteTransformer:
  color_/int
  constructor .color_:

  transform rgba/ByteArray -> none:
    rgba[0] = color_ >> 16
    rgba[1] = color_ >> 8
    rgba[2] = color_
