// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
Functions and constants useful for the RGB
  $pixel-display.PixelDisplay.true-color display.
See for example https://pkg.toit.io/package/github.com%2Ftoitware%2Ftoit-color-tft
*/

import binary show BIG-ENDIAN
import bitmap show *
import font show Font

import .gray-scale as gray-scale_
import .pixel-display
import .pixel-display as pixel-display

/**
Create a 24 bit color from three components in the 0-255 range.
As an alternative, you can use the web-similar syntax, 0xrrggbb.
*/
get-rgb r/int g/int b/int -> int:
  return (r << 16) | (g << 8) | b

WHITE ::= 0xff_ff_ff
BLACK ::= 0

/**
Extract the red component in the 0-255 range from a color.
*/
red-component pixel/int -> int:
  return pixel >> 16

/**
Extract the green component in the 0-255 range from a color.
*/
green-component pixel/int -> int:
  return (pixel >> 8) & 0xff

/**
Extract the blue component in the 0-255 range from a color.
*/
blue-component pixel/int -> int:
  return pixel & 0xff

// The canvas contains three ByteArrays, red, green, and blue.
// 0 is black, 255 is max intensity.  Initially all pixels are black.
class Canvas_ extends Canvas:
  red_/ByteArray := ?
  green_/ByteArray := ?
  blue_/ByteArray := ?
  components_/List := ?

  supports-8-bit -> bool: return true
  gray-scale -> bool: return false

  constructor width/int height/int:
    size := width * height
    red_ = ByteArray size
    green_ = ByteArray size
    blue_ = ByteArray size
    components_ = [red_, green_, blue_]
    super width height

  constructor.private_ width/int height/int .red_ .green_ .blue_:
    components_ = [red_, green_, blue_]
    super width height

  stringify:
    return "true-color.Canvas_ $(width_)x$height_"

  set-all-pixels color/int -> none:
    bytemap-zap red_ (red-component color)
    bytemap-zap green_ (green-component color)
    bytemap-zap blue_ (blue-component color)

  get-pixel_ x y:
    idx := x + width_ * y
    return get-rgb red_[idx] green_[idx] blue_[idx]

  /**
  Creates a blank canvas with the same dimensions as this one.
  */
  create-similar:
    result := Canvas_ width_ height_
    result.transform = transform
    return result

  make-alpha-map --padding/int=0 -> Canvas:
    result := gray-scale_.Canvas_ (width_ + padding) (height_ + padding)
    result.transform = transform
    return result

  subcanvas x/int y/int w/int h/int --ignore-x/bool=false --ignore-y/bool=false -> Canvas?:
    return subcanvas-helper_ x y w h ignore-x ignore-y: | y2 h2 |
      from := y2 * width_
      to := (y2 + h2) * width_
      Canvas_.private_ width_ h2
          red_[from..to]
          green_[from..to]
          blue_[from..to]

  composit frame-opacity frame-canvas/Canvas_? painting-opacity painting-canvas/Canvas_:
    fo := frame-opacity is ByteArray ? frame-opacity : frame-opacity.pixels_
    po := painting-opacity is ByteArray ? painting-opacity : painting-opacity.pixels_
    for i := 0; i < 3; i++:
      composit-bytes components_[i] fo (frame-canvas ? frame-canvas.components_[i] : null) po painting-canvas.components_[i] false

  rectangle x/int y/int --w/int --h/int --color/int:
    transform.xywh x y w h: | x2 y2 w2 h2 |
      r := color >> 16
      g := (color >> 8) & 0xff
      b := color & 0xff
      bytemap-rectangle x2 y2 r w2 h2 red_   width_
      bytemap-rectangle x2 y2 g w2 h2 green_ width_
      bytemap-rectangle x2 y2 b w2 h2 blue_  width_

  text x/int y/int --text/string --color/int --font/Font --orientation/int=ORIENTATION-0:
    transform.xyo x y orientation: | x2 y2 o2 |
      r := color >> 16
      g := (color >> 8) & 0xff
      b := color & 0xff
      bytemap-draw-text x2 y2 r o2 text font red_ width_
      bytemap-draw-text x2 y2 g o2 text font green_ width_
      bytemap-draw-text x2 y2 b o2 text font blue_ width_

  bitmap x/int y/int -> none
      --pixels/ByteArray
      --alpha/ByteArray         // 2-element byte array.
      --palette/ByteArray       // 6-element byte array.
      --source-width/int        // In pixels.
      --source-line-stride/int  // In bytes.
      --orientation/int=ORIENTATION-0:
    source-byte-width := (source-width + 7) >> 3
    zero-alpha := alpha[0]
    // Fast case if the alpha is either 0 or 0xff, because we can use the
    // primitives that paint 1's with a particular color and leave the zeros
    // transparent.  We don't check for the case where 0 is opaque and 1 is
    // transparent, because pngunzip fixes that for us.
    if alpha[1] == 0xff and (zero-alpha == 0xff or zero-alpha == 0):
      if zero-alpha == 0xff:
        h := (pixels.size + source-line-stride - source-byte-width) / source-line-stride
        // Draw the zeros.
        rectangle x y --w=source-width --h=h --color=(BIG-ENDIAN.uint24 palette 0)
      // Draw the ones.
      transform.xyo x y 0: | x2 y2 o2 |
        for i := 0; i < 3; i++:
          bitmap-draw-bitmap x2 y2
              --color = palette[3 + i]
              --orientation = o2
              --source = pixels
              --source-width = source-width
              --source-line-stride = source-line-stride
              --destination = components_[i]
              --destination-width = width_
              --bytewise
      return
    // Unfortunately one of the alpha values is not 0 or 0xff, so we can't use
    // the bitmap draw primitive.  We can blow it up to bytes, then use the
    // bitmap-draw-bytemap.
    h := (pixels.size + source-line-stride - source-byte-width) / source-line-stride
    bytemap := ByteArray source-width * h
    bitmap-draw-bitmap 0 0
        --color = 1
        --source = pixels
        --source-width = source-width
        --source-line-stride = source-line-stride
        --destination = bytemap
        --destination-width = source-width
        --bytewise
    transform.xyo x y 0: | x2 y2 o2 |
      for i := 0; i < 3; i++:
        bitmap-draw-bytemap x2 y2
            --alpha = alpha
            --orientation = o2
            --source = bytemap
            --source-width = source-width
            --palette = palette[i..]
            --destination = components_[i]
            --destination-width = width_

  pixmap x/int y/int
      --pixels/ByteArray
      --alpha/ByteArray=#[]
      --palette/ByteArray=#[]
      --source-width/int
      --orientation/int=ORIENTATION-0
      --source-line-stride/int=source-width:

    transform.xyo x y orientation: | x2 y2 o2 |
      for i := 0; i < 3; i++:
        component-palette := palette.size > i ?  palette[i..] : #[]
        bitmap-draw-bytemap x2 y2
            --alpha = alpha
            --orientation = o2
            --source = pixels
            --source-width = source-width
            --source-line-stride = source-line-stride
            --palette = component-palette
            --destination = components_[i]
            --destination-width = width_

  rgb-pixmap x/int y/int --r/ByteArray --g/ByteArray --b/ByteArray
      --alpha/ByteArray=#[]
      --palette/ByteArray?=null
      --source-width/int
      --orientation/int=ORIENTATION-0
      --source-line-stride/int=source-width:
    components := [r, g, b]
    transform.xyo x y orientation: | x2 y2 o2 |
      3.repeat: | i |
        component-palette := (palette and palette.size > i) ?  palette[i..] : #[]
        bitmap-draw-bytemap x2 y2
            --alpha = alpha
            --orientation = o2
            --source = components[i]
            --source-width = source-width
            --source-line-stride = source-line-stride
            --palette = component-palette
            --destination = components_[i]
            --destination-width = width_
