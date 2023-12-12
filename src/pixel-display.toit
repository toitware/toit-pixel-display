// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
A library for rendering on pixel-based displays attached to devices.
See https://docs.toit.io/language/sdk/display
*/

import bitmap show *
import bitmap show ORIENTATION-0 ORIENTATION-90 ORIENTATION-180 ORIENTATION-270
import font show Font
import icons show Icon

import .bar-code
import .element
import .two-color as two-color
import .three-color as three-color
import .two-bit-texture as two-bit
import .four-gray as four-gray
import .true-color as true-color
import .gray-scale as gray-scale
import .several-color as several-color
import .one-byte as one-byte
import .style

FLAG-2-COLOR ::=         0b1
FLAG-3-COLOR ::=         0b10
FLAG-4-COLOR ::=         0b100
FLAG-GRAY-SCALE ::=      0b1000
FLAG-SEVERAL-COLOR ::=   0b10000
FLAG-TRUE-COLOR ::=      0b100000
FLAG-PARTIAL-UPDATES ::= 0b1000000

/**
Abstract superclass for all pixel display drivers.
For example, implemented by the drivers in
  https://pkg.toit.io/package/color_tft&url=github.com%2Ftoitware%2Ftoit-color-tft&index=latest
  and
  https://pkg.toit.io/package/ssd1306&url=github.com%2Ftoitware%2Ftoit-ssd1306&index=latest
*/
abstract class AbstractDriver:
  abstract width -> int
  abstract height -> int
  abstract flags -> int
  x-rounding -> int: return 8
  y-rounding -> int: return 8
  start-partial-update speed/int -> none:
  start-full-update speed/int -> none:
  clean left/int top/int right/int bottom/int -> none:
  commit left/int top/int right/int bottom/int -> none:
  draw-two-color l/int t/int r/int b/int pixels/ByteArray -> none:
    throw "Not a two-color driver"
  draw-two-bit l/int t/int r/int b/int plane0/ByteArray plane1/ByteArray -> none:
    throw "Not a two-bit driver"
  draw-gray-scale l/int t/int r/int b/int pixels/ByteArray -> none:
    throw "Not a gray-scale driver"
  draw-several-color l/int t/int r/int b/int pixels/ByteArray -> none:
    throw "Not a several-color driver"
  draw-true-color l/int t/int r/int b/int red/ByteArray green/ByteArray blue/ByteArray -> none:
    throw "Not a true-color driver"
  close -> none:

/**
Common code for pixel-based displays connected to devices.
Height and width must be multiples of 8.
This class keeps track of the list of things to draw, and
  which areas need refreshing.  Add components with $add and render to
  the display with $draw.
See https://docs.toit.io/language/sdk/display
*/
abstract class PixelDisplay implements Window:
  // The image to display.
  elements_ := {}
  background_ := null
  width: return driver_.width
  height: return driver_.width
  inner-width: return driver_.width
  inner-height: return driver_.width

  // Need-to-redraw is tracked as a bit array of dirty bits, arranged in
  // SSD1306 layout so we can use bitmap-rectangle to invalidate areas.
  // One bit in the dirty map covers an area of 8x8 pixels of the display.
  static CLEAN_ ::= 0
  static DIRTY_ ::= 1
  dirty-bytes-per-line_ := 0
  dirty_ := null
  dirty-left_ := 0
  dirty-top_ := 0
  dirty-right_ := 0
  dirty-bottom_ := 0

  dirty-accumulator_ := ByteArray 1

  x-rounding_ := 1
  y-rounding_ := 1

  driver_ /AbstractDriver := ?
  speed_ := 50  // Speed-quality of current screen update.

  transform_ /Transform

  /**
  Constructs a display connected via a $driver_ to a device.
  The display is suitable for true-color (24 bit color) display drivers.
  By default the orientation is the natural orientation of the display driver.
  If $portrait is false, then a landscape orientation is used.
  If $portrait is true, then a portrait orientation is used, or in the case
     that the display driver is exactly square, a rotated orientation is used.
  The orientation is rotated by 180 degrees if $inverted is true.
  */
  constructor.true-color driver/AbstractDriver
      --inverted/bool=false
      --portrait/bool=false
      --transform/Transform?=null:
    return TrueColorPixelDisplay_ driver --inverted=inverted --portrait=portrait --transform=transform

  /**
  Constructs a display connected via a $driver_ to a device.
  The display is suitable for gray-scale (8 bit gray) display drivers.
  By default the orientation is the natural orientation of the display driver.
  If $portrait is false, then a landscape orientation is used.
  If $portrait is true, then a portrait orientation is used, or in the case
     that the display driver is exactly square, a rotated orientation is used.
  The orientation is rotated by 180 degrees if $inverted is true.
  */
  constructor.gray-scale driver/AbstractDriver
      --inverted/bool=false
      --portrait/bool=false
      --transform/Transform?=null:
    return GrayScalePixelDisplay_ driver --inverted=inverted --portrait=portrait --transform=transform

  /**
  Constructs a display connected via a $driver_ to a device.
  The display is suitable for pseudo-color (8 bits per pixel) display drivers.
  By default the orientation is the natural orientation of the display driver.
  If $portrait is false, then a landscape orientation is used.
  If $portrait is true, then a portrait orientation is used, or in the case
     that the display driver is exactly square, a rotated orientation is used.
  The orientation is rotated by 180 degrees if $inverted is true.
  */
  constructor.several-color driver/AbstractDriver
      --inverted/bool=false
      --portrait/bool=false
      --transform/Transform?=null:
    return SeveralColorPixelDisplay_ driver --inverted=inverted --portrait=portrait --transform=transform

  /**
  Constructs a display connected via a $driver_ to a device.
  The display is suitable for four-gray (2 bit gray) display drivers.
  By default the orientation is the natural orientation of the display driver.
  If $portrait is false, then a landscape orientation is used.
  If $portrait is true, then a portrait orientation is used, or in the case
     that the display driver is exactly square, a rotated orientation is used.
  The orientation is rotated by 180 degrees if $inverted is true.
  */
  constructor.four-gray driver/AbstractDriver
      --inverted/bool=false
      --portrait/bool=false
      --transform/Transform?=null:
    return FourGrayPixelDisplay_ driver --inverted=inverted --portrait=portrait --transform=transform

  /**
  Constructs a display connected via a $driver_ to a device.
  The display is suitable for three-color (red, white, black) display drivers.
  By default the orientation is the natural orientation of the display driver.
  If $portrait is false, then a landscape orientation is used.
  If $portrait is true, then a portrait orientation is used, or in the case
     that the display driver is exactly square, a rotated orientation is used.
  The orientation is rotated by 180 degrees if $inverted is true.
  */
  constructor.three-color driver/AbstractDriver
      --inverted/bool=false
      --portrait/bool=false
      --transform/Transform?=null:
    return ThreeColorPixelDisplay_ driver --inverted=inverted --portrait=portrait --transform=transform

  /**
  Constructs a display connected via a $driver_ to a device.
  The display is suitable for two-color (white, black) display drivers.
  By default the orientation is the natural orientation of the display driver.
  If $portrait is false, then a landscape orientation is used.
  If $portrait is true, then a portrait orientation is used, or in the case
     that the display driver is exactly square, a rotated orientation is used.
  The orientation is rotated by 180 degrees if $inverted is true.
  */
  constructor.two-color driver/AbstractDriver
      --inverted/bool=false
      --portrait/bool=false
      --transform/Transform?=null:
    return TwoColorPixelDisplay_ driver --inverted=inverted --portrait=portrait --transform=transform

  /**
  Constructs a display connected via a $driver_ to a device.
  By default the orientation is the natural orientation of the display driver.
  If $portrait is false, then a landscape orientation is used.
  If $portrait is true, then a portrait orientation is used, or in the case
     that the display driver is exactly square, a rotated orientation is used.
  The orientation is rotated by 180 degrees if $inverted is true.
  */
  constructor .driver_ --inverted/bool?=false --transform/Transform?=null --portrait/bool?=null:
    x-rounding_ = driver_.x-rounding
    y-rounding_ = driver_.y-rounding
    height := round-up driver_.height y-rounding_
    if driver_.flags & FLAG-PARTIAL-UPDATES != 0:
      dirty-bytes-per-line_ = (driver_.width >> 3) + 1
      dirty-strips := (height >> 6) + 1  // 8-tall strips of dirty bits.
      dirty_ = ByteArray dirty-bytes-per-line_ * dirty-strips

    if transform:
      if portrait != null or inverted: throw "INVALID_ARGUMENT"
      transform_ = transform
    else:
      rotation := 0
      if portrait != null:
        if portrait == (driver_.width < driver_.height):
          rotation = inverted ? 180 : 0
        else:
          rotation = inverted ? 270 : 90
      else if inverted:
        rotation = 180
      if rotation == 0:
        transform_ = Transform.identity
      else if rotation == 90:
        transform_ = (Transform.identity.translate 0 driver_.height).rotate-left
      else if rotation == 180:
        transform_ = (Transform.identity.translate driver_.width driver_.height).rotate-left.rotate-left
      else:
        transform_ = (Transform.identity.translate driver_.width 0).rotate-right

    if driver_.flags & FLAG-PARTIAL-UPDATES != 0:
      all-is-dirty_

  background= color/int -> none:
    if background_ != color:
      background_ = color
      child-invalidated_ 0 0 driver_.width driver_.height

  set-styles styles/List -> none:
    elements_.do:
      if it is Element:
        element := it as Element
        element.set-styles styles

  /**
  Adds an element to a display.  The next time the display is refreshed, this
    element will be drawn.  Elements added to this display are drawn in the
    order they were added, so the first-added elements are at the back and the
    last-added are at the front.  However elements can have children.
    This enables you to later add elements that are not at the
    front, by adding them as children of an Element that is not at the front.
  */
  add element/Element -> none:
    elements_.add element
    element.change-tracker = this
    element.invalidate

  /**
  Removes an element that was previously added.
  */
  remove element/Element -> none:
    elements_.remove element
    element.invalidate
    element.change-tracker = null

  /** Removes all elements.  */
  remove-all:
    elements_.do: it.change-tracker = null
    if elements_.size != 0: child-invalidated 0 0 driver_.width driver_.height
    elements_ = {}

  get-element-by-id id/string -> any:
    elements_.do: | child/Element |
      found := child.get-element-by-id id
      if found: return found
    return null

  child-invalidated x/int y/int w/int h/int -> none:
    transform_.xywh x y w h: | x2 y2 w2 h2 |
      child-invalidated_ x2 y2 w2 h2

  child-invalidated_ x/int y/int w/int h/int -> none:
    if not dirty_: return  // Some devices don't use the dirty array to track changes.
    dirty-left_ = min dirty-left_ x
    dirty-right_ = max dirty-right_ (x + w)
    dirty-top_ = min dirty-top_ y
    dirty-bottom_ = max dirty-bottom_ (y + h)

    // Round up the invalidated area.
    rx := x & 7
    x = (x - rx) >> 3
    w = (w + rx + 7) >> 3
    ry := y & 7
    y = (y - ry) >> 3
    h = (h + ry + 7) >> 3

    // x, y, w, h now measured in 8x8 blocks.
    bitmap-rectangle x y DIRTY_ w h dirty_ dirty-bytes-per-line_

  line-is-clean_ y:
    idx := (y >> 6) * dirty-bytes-per-line_
    mask := 1 << ((y >> 3) & 0b111)
    dirty-accumulator_[0] = CLEAN_
    blit dirty_[idx..idx+dirty-bytes-per-line_] dirty-accumulator_ dirty-bytes-per-line_ --destination-pixel-stride=0 --operation=OR
    return dirty-accumulator_[0] & mask == CLEAN_  // Only works because CLEAN_ == 0

  is-dirty_ x y:
    idx := (y >> 6) * dirty-bytes-per-line_
    mask := 1 << ((y >> 3) & 0b111)
    byte := x >> 3
    return dirty_[idx + byte] & mask != CLEAN_  // Only works because CLEAN_ == 0

  /// For displays that don't support any form of partial update.
  draw-entire-display_:
    driver_.start-full-update speed_
    w := driver_.width
    step := round-up
        max-canvas-height_ driver_.width
        y-rounding_
    canvas := create-canvas_ w step
    List.chunk-up 0 (round-up driver_.height y-rounding_) step: | top bottom |
      // For the Elements.
      // To get the translation for this tile in the driver coordinates instead
      // of the display coordinates, we invert the 2d transform, then translate
      // it, then invert it again.
      canvas.transform = (transform_.invert.translate 0 top).invert
      canvas.set-all-pixels background_
      elements_.do:
        it.draw canvas
      draw_ 0 top driver_.width bottom canvas
    driver_.commit 0 0 driver_.width driver_.height

  /**
  Draws the elements.

  After changing the display, for example by adding, removing or moving
    elements, call this to refresh the screen.  Optionally give a $speed
    between 0 and 100 to indicate the speed-image quality tradeoff.
  */
  draw --speed/int=50 -> none:
    speed_ = speed
    if speed < 10 or driver_.flags & FLAG-PARTIAL-UPDATES == 0:
      draw-entire-display_
      if dirty_: bitmap-zap dirty_ CLEAN_
      return

    // Send data for the whole screen, even if only part of it changed.
    if speed < 50: all-is-dirty_

    driver_.start-partial-update speed
    refreshed := false
    try:
      refresh-dimensions ::= [driver_.width, 0, driver_.height, 0]
      update-frame-buffer false refresh-dimensions
      refresh_ refresh-dimensions[0] refresh-dimensions[2] refresh-dimensions[1] refresh-dimensions[3]
      refreshed = true
    finally:
      if not refreshed: refresh_ 0 0 0 0

    all-is-clean_

  all-is-clean_ -> none:
    bitmap-zap dirty_ CLEAN_
    dirty-left_ = driver_.width
    dirty-right_ = 0
    dirty-top_ = driver_.height
    dirty-bottom_ = 0

  all-is-dirty_ -> none:
    bitmap-zap dirty_ DIRTY_
    dirty-left_ = 0
    dirty-right_ = driver_.width
    dirty-top_ = 0
    dirty-bottom_ = driver_.height

  // Clean determines if we should clean or draw the dirty area.
  update-frame-buffer clean/bool refresh-dimensions -> none:
    redraw := : | l t r b |
      if clean:
        clean-rect_ l t r b
      else:
        redraw-rect_ l t r b

    // Perhaps we can do it all with one canvas.
    l := round-down (max 0 dirty-left_) x-rounding_
    r := round-up (min driver_.width dirty-right_) x-rounding_
    t := round-down (max 0 dirty-top_) y-rounding_
    b := round-up (min driver_.height dirty-bottom_) y-rounding_

    if l >= r or t >= b: return

    if (max-canvas-height_ (r - l)) >= b - t:
      redraw.call l t r b
      return

    // Perhaps we can do it in two canvases, split to be as square as
    // possible.
    if r - l > b - t and r - l >= x-rounding_ * 2:
      w := round-up ((r - l) >> 1) x-rounding_
      if (max-canvas-height_ w) >= b - t:
        redraw.call l t (l + w) b
        redraw.call (l + w) t r b
        return
    // Perhaps we can do it in two canvases, split vertically.
    else if b - t >= y-rounding_ * 2:
      h := round-up ((b - t) >> 1) y-rounding_
      if (max-canvas-height_ (r - l)) >= h:
        redraw.call l t r (t + h)
        redraw.call l (t + h) r b
        return

    // Start with a width target of (slightly less than) 64 pixels, but ask
    // the canvas how tall the patches can be. It will normally try pick a
    // height that keeps things inside a 4k page.
    width-target := 64
    width := ?
    max-height := ?
    while true:
      // Canvas sizes must often be slightly less than 4k in order to fit into
      // a 4k page with object header overhead. By subtracting 8 here we get nice
      // heights like 8, 16, 24, 32 that almost fill the max canvas size.
      width = min driver_.width (width-target - 8)
      max-height = max
          round-down (max-canvas-height_ width) y-rounding_
          y-rounding_
      // Don't widen any more if the patches are already too flat to fill the full height.
      if max-height < driver_.height: break
      // Don't widen any more if the patches already cover the whole width.
      if width >= driver_.width: break
      width-target += width-target

    // The algorithm below requires that x aligns with 8 pixels, the resolution
    // of the dirty map.
    start-x := round-down (max 0 dirty-left_) 8

    // Outer loop - the coarse rectangles that are the max size of
    // update patches.
    for y:= 0; y < driver_.height; y += max-height:
      while line-is-clean_ y:
        y = (y + 8) & ~7  // Move on to next factor of 8.
        if y >= driver_.height: break
      if y >= driver_.height: break
      for x := start-x; x < driver_.width; x += width:
        left := x
        right := min (x + width) driver_.width
        top := y
        bottom := min (y + max-height) driver_.height

        // Quick check if the whole rectangle is clean.  This is a little
        // imprecise because the same mask is used for all lines.
        mask := 0
        for iy := top; iy < bottom; iy += 8:
          mask |= 1 << ((iy >> 3) & 0b111)
        idx := (top >> 6) * dirty-bytes-per-line_ + (left >> 3)
        end-idx := ((round-up bottom 64) >> 6) * dirty-bytes-per-line_
        dirty-accumulator_[0] = CLEAN_
        blit dirty_[idx..end-idx] dirty-accumulator_ ((right - left + 7) >> 3) --source-line-stride=dirty-bytes-per-line_ --destination-pixel-stride=0 --destination-line-stride=0 --operation=OR
        if dirty-accumulator_[0] & mask == CLEAN_:
          continue

        // Inner loop.  For each coarse rectangle, find the smallest rectangle
        // that covers all the dirty bits.
        dirty-left := right
        dirty-right := left
        dirty-top := bottom
        dirty-bottom := top
        for iy := top; iy < bottom; iy += 8:
          line-mask := 1 << ((iy >> 3) & 0b111)
          if dirty-accumulator_[0] & line-mask == CLEAN_:
            continue
          for ix := left; ix < right; ix += 8:
            if is-dirty_ ix iy:
              dirty-left = min dirty-left ix
              dirty-right = max dirty-right (ix + 8)
              dirty-top = min dirty-top iy
              dirty-bottom = max dirty-bottom (iy + 8)
        dirty-left = max dirty-left (round-down (max 0 dirty-left_) x-rounding_)
        dirty-right = min dirty-right (round-up (min driver_.width dirty-right_) x-rounding_)
        dirty-top = max dirty-top (round-down (max 0 dirty-top_) y-rounding_)
        dirty-bottom = min dirty-bottom (round-up (min driver_.height dirty-bottom_) y-rounding_)
        if dirty-left <= dirty-right and dirty-top <= dirty-bottom:
          if dirty-top < refresh-dimensions[2]: refresh-dimensions[2] = dirty-top
          if dirty-bottom > refresh-dimensions[3]: refresh-dimensions[3] = dirty-bottom
          if dirty-left < refresh-dimensions[0]: refresh-dimensions[0] = dirty-left
          if dirty-right > refresh-dimensions[1]: refresh-dimensions[1] = dirty-right
          redraw.call dirty-left dirty-top dirty-right dirty-bottom

  redraw-rect_ left/int top/int right/int bottom/int -> none:
    canvas := create-canvas_ (right - left) (bottom - top)
    // For the Elements:
    // To get the translation for this tile in the driver coordinates instead
    // of the display coordinates, we invert the 2d transform, then translate
    // it, then invert it again.
    canvas.transform = (transform_.invert.translate left top).invert

    canvas.set-all-pixels background_
    elements_.do:
      it.draw canvas

    draw_ left top right bottom canvas

  abstract max-canvas-height_ width/int -> int

  abstract create-canvas_ w/int h/int -> Canvas

  abstract draw_ x y w h canvas/Canvas -> none

  clean-rect_ left/int top/int right/int bottom/int -> none:
    driver_.clean left top right bottom

  refresh_ left/int top/int right/int bottom/int -> none:
    driver_.commit left top right bottom

  /// Frees up the display so other process groups can use it.
  /// This happens automatically when the process group exits.
  close -> none:
    driver_.close

/**
Black-and-white pixel-based display connected to a device.
Height and width must be multiples of 8.
This class keeps track of the list of things to draw, and
  which areas need refreshing.  Add components with $add and render to
  the display with $draw.
See https://docs.toit.io/language/sdk/display
*/
class TwoColorPixelDisplay_ extends PixelDisplay:
  constructor driver/AbstractDriver --inverted/bool=false --portrait/bool=false --transform/Transform?=null:
    super driver --inverted=inverted --portrait=portrait --transform=transform
    background_ = two-color.WHITE

  max-canvas-height_ width/int -> int:
    height := 0
    width-rounded := round-up width 8
    height-rounded := round-up driver_.height 8
    if width-rounded * height-rounded >> 3 < 4000:
      // If we can fit both the red and black plane in < 8k then do that.
      height = height-rounded
    else:
      // Some multiple of 8 where each plane fits in one page.
      height = (4000 / width-rounded) << 3
    // We can't work well with canvases that are less than 8 pixels tall.
    return max 8 height

  create-canvas_ w/int h/int -> Canvas:
    return two-color.Canvas_ w h

  draw_ x/int y/int w/int h/int canvas/two-color.Canvas_ -> none:
      driver_.draw-two-color x y w h canvas.pixels_

/**
Pixel-based display with four shades of gray, connected to a device.
Height and width must be multiples of 8.
This class keeps track of the list of things to draw, and
  which areas need refreshing.  Add components with $add and render to
  the display with $draw.
See https://docs.toit.io/language/sdk/display
*/
class FourGrayPixelDisplay_ extends TwoBitPixelDisplay_:
  constructor driver/AbstractDriver --inverted/bool=false --portrait/bool=false --transform/Transform?=null:
    super driver --inverted=inverted --portrait=portrait --transform=transform
    background_ = four-gray.WHITE

  create-canvas_ w/int h/int -> Canvas:
    return four-gray.Canvas_ w h

/**
Pixel-based display with black, white, and red, connected to a device.
Height and width must be multiples of 8.
This class keeps track of the list of things to draw, and
  which areas need refreshing.  Add components with $add and render to
  the display with $draw.
See https://docs.toit.io/language/sdk/display
*/
class ThreeColorPixelDisplay_ extends TwoBitPixelDisplay_:
  constructor driver/AbstractDriver --inverted/bool=false --portrait/bool=false --transform/Transform?=null:
    super driver --inverted=inverted --portrait=portrait --transform=transform
    background_ = three-color.WHITE

  create-canvas_ w/int h/int -> Canvas:
    return three-color.Canvas_ w h

abstract class TwoBitPixelDisplay_ extends PixelDisplay:
  background_ := three-color.WHITE

  constructor driver/AbstractDriver --inverted/bool=false --portrait/bool=false --transform/Transform?=null:
    super driver --inverted=inverted --portrait=portrait --transform=transform

  max-canvas-height_ width:
    width-rounded := round-up width 8
    height-rounded := round-up driver_.height 8
    height := ?
    if width-rounded * height-rounded >> 3 < 4000:
      // If we can fit both the red and black plane in < 8k then do that.
      height = height-rounded
    else:
      // Some multiple of 8 where each plane fits in one page.
      height = (4000 / width-rounded) << 3
    // We can't work well with canvases that are less than 8 pixels tall.
    return max 8 height

  draw_ x/int y/int w/int h/int canvas/two-bit.Canvas_ -> none:
    driver_.draw-two-bit x y w h canvas.plane-0_ canvas.plane-1_

/**
Pixel-based display with up to 256 shades of gray, connected to a device.
Height and width must be multiples of 8.
This class keeps track of the list of things to draw, and
  which areas need refreshing.  Add components with $add and render to
  the display with $draw.
See https://docs.toit.io/language/sdk/display
*/
class GrayScalePixelDisplay_ extends PixelDisplay:
  constructor driver/AbstractDriver --inverted/bool=false --portrait/bool=false --transform/Transform?=null:
    super driver --inverted=inverted --portrait=portrait --transform=transform
    background_ = gray-scale.WHITE

  max-canvas-height_ width:
    height := 0
    // Keep each color component under 2k so you can fit two on a page.
    height = round-down (2000 / width) 8
    // We can't work well with canvases that are less than 4 pixels tall.
    return height < 8 ? 4 : height

  create-canvas_ w/int h/int -> Canvas:
    return gray-scale.Canvas_ w h

  draw_ x/int y/int w/int h/int canvas/gray-scale.Canvas_ -> none:
    driver_.draw-gray-scale x y w h canvas.pixels_

/**
Pixel-based display with up to 256 colors, connected to a device.
Height and width must be multiples of 8.
This class keeps track of the list of things to draw, and
  which areas need refreshing.  Add components with $add and render to
  the display with $draw.
See https://docs.toit.io/language/sdk/display
*/
class SeveralColorPixelDisplay_ extends PixelDisplay:
  constructor driver/AbstractDriver --inverted/bool=false --portrait/bool=false --transform/Transform?=null:
    super driver --inverted=inverted --portrait=portrait --transform=transform
    background_ = 0

  max-canvas-height_ width:
    height := 0
    // Keep each color component under 2k so you can fit two on a page.
    height = round-down (2000 / width) 8
    // We can't work well with canvases that are less than 4 pixels tall.
    return height < 8 ? 4 : height

  create-canvas_ w/int h/int -> Canvas:
    return several-color.Canvas_ w h

  draw_ x/int y/int w/int h/int canvas/several-color.Canvas_ -> none:
    driver_.draw-several-color x y w h canvas.pixels_

/**
Pixel-based display with up to 16 million colors, connected to a device.
Height and width must be multiples of 8.
This class keeps track of the list of things to draw, and
  which areas need refreshing.  Add components with $add and render to
  the display with $draw.
See https://docs.toit.io/language/sdk/display
*/
class TrueColorPixelDisplay_ extends PixelDisplay:
  constructor driver/AbstractDriver --inverted/bool=false --portrait/bool=false --transform/Transform?=null:
    super driver --inverted=inverted --portrait=portrait --transform=transform
    background_ = true-color.WHITE

  max-canvas-height_ width:
    height := 0
    // Keep each color component under 2k then the packed 3-colors-in-2-bytes
    // format is still less than a page.
    height = round-down (2000 / width) 8
    // We can't work well with canvases that are less than 4 pixels tall.
    return max 4 height

  create-canvas_ w/int h/int -> Canvas:
    return true-color.Canvas_ w h

  draw_ x/int y/int w/int h/int canvas/true-color.Canvas_ -> none:
    driver_.draw-true-color x y w h canvas.red_ canvas.green_ canvas.blue_

/**
A display or a window within a display.
You can add and remove element objects to a Window.  They will be drawn
  in the order they were added, where the first elements are at the back
  and are overwritten by elements added later.
*/
interface Window:
  /**
  Add an element to a Window.  Elements are drawn back-to-front in
    the order they are added.
  An element can only be added once a Window, and cannot be
    added to several windows at a time.
  */
  add element/Element -> none

  /**
  Remove an element from a Window.
  Next time the draw method is called on the display, the area
    formerly occupied by the element will be redrawn.
  */
  remove element/Element -> none

  /**
  Remove all elements from a Window.
  See $remove.
  */
  remove-all -> none

  /**
  Called by elements that have been added to this window, when they change
    or move.
  This will cause the area described to be redrawn, next time the draw method
    is called on the display.
  The coordinates are in this instance's coordinate space.
  */
  child-invalidated x/int y/int w/int h/int -> none

  /**
  Finds an Element in the tree with the given id.
  Returns null if no element is found.
  The return type is `any` because you want to be able to assign the result
    to a subtypes of $Element, for example to a variable of type Div.
  */
  get-element-by-id id/string -> any

/**
A canvas to draw on.
When the display is being redrawn, the area that needs updating is
  divided into reasonably-sized rectangles.  Each rectangle
  is represented by an object of this class.
The draw methods of the elements are called with this canvas, and
  they can use methods on the canvas to draw themselves.
The canvas is generally smaller than the display in order to
  reduce peak memory usage.  This means the draw method can be called
  many times on each element.
*/
abstract class Canvas:
  width_ / int
  height_ / int
  transform / Transform? := null

  constructor .width_ .height_:

  /**
  Returns a new canvas with the same dimensions and transform (coordinate
    system) as this one.
  */
  abstract create-similar -> Canvas

  abstract set-all-pixels color/int -> none

  abstract supports-8-bit -> bool
  abstract gray-scale -> bool

  /**
  Returns a sub-canvas of this canvas.  Drawing on the sub-canvas
    automatically clips all drawing operations to the sub-canvas area.
  May return null in case the given dimensions are not easy to produce
    a sub-canvas for.  In that case the caller must use compositing.
  Coordinates are in the same frame as the drawing operations on this
    canvas.  They may be partially outside the canvas.
  If $ignore-x is true, the caller does not worry about clipping in
    the x direction ($x, and $w).  Likewise for $ignore-y.
  */
  abstract subcanvas x/int y/int w/int h/int --ignore-x/bool=false --ignore-y/bool=false-> Canvas?

  /**
  Helper for the $subcanvas method.  See that method for details.
  The block, $create-block takes the arguments y and height, and it is
    expected to return a Canvas that is a view into the current canvas,
    but only for the lines between y and y + height.  It can return null
    if that is not possible.
  */
  subcanvas-helper_ x/int y/int w/int h/int ignore-x/bool ignore-y/bool [create-canvas] -> Canvas?:
    transform.xywh x y w h: | x2 y2 w2 h2 |
      if x2 < 0:
        w2 += x2
        x2 = 0
      if y2 < 0:
        h2 += y2
        y2 = 0
      if x2 + w2 > width_:
        w2 = width_ - x2
      if y2 + h2 > height_:
        h2 = height_ - y2
      if w2 <= 0 or h2 <= 0:
        return NULL-CANVAS_
      if w2 != width_ or x2 != 0:
        transform.xyo 0 0 0: | _ _ orientation |
          if orientation == ORIENTATION-90 or orientation == ORIENTATION-270:
            ignore-x = ignore-y
        if ignore-x:
          w2 = width_
          x2 = 0
        else:
          return null  // Can't do this yet.

      if y2 == 0 and h2 == height_:
        return this

      result := create-canvas.call y2 h2
      if result: result.transform = (transform.invert.translate x2 y2).invert
      return result

    unreachable

  /**
  Returns a new canvas that is either gray-scale or 1-bit.
  The returned canvas is intended for use with masking and
    compositing operations.
  A canvas type that allows mixing and averaging of colors (for example, a
    true-color canvas) generally returns a gray-scale canvas where white
    (0xff) represents an opaque pixel, and black (0) represents a transparent
    pixel.
  A canvas type that does not allow mixing and averaging of colors (for example,
    a black/white/red canvas) returns a one-bit canvas where 1
    represents an opaque pixel, and 0 represents a transparent pixel.
  The returned canvas is larger on all four edges of the canvas by the
    given $padding, defaulting to 0.
  */
  abstract make-alpha-map --padding/int=0 -> Canvas

  /// Result from $bounds-analysis: The area and the canvas are disjoint.
  static DISJOINT           ::= 0
  /// Result from $bounds-analysis: The area is a subset of the canvas.
  static AREA-IN-CANVAS     ::= 1
  /// Result from $bounds-analysis: The canvas is a subset of the area.
  static CANVAS-IN-AREA     ::= 2
  /// Result from $bounds-analysis: The area and the canvas are identical.
  static COINCIDENT         ::= 3
  /// Result from $bounds-analysis: The areas overlap, but neither is a subset of the other.
  static OVERLAP            ::= 4

  /**
  Checks whether the given area overlaps with the canvas.
  This can be used to avoid doing work in an element's draw
    method if the element and the canvas do not overlap.
  If the canvas is wholly within the area of the element,
    then the element can save space and time by not worrying
    about clipping its drawing operations.
  All the drawing operations are automatically clipped to the
    area of the canvas, and this is often sufficient clipping.
  */
  bounds-analysis x/int y/int w/int h/int -> int:
    if h == 0 or w == 0 or width_ == 0 or height_ == 0: return DISJOINT
    transform.xywh x y w h: | x2 y2 w2 h2 |
      right := x2 + w2
      bottom := y2 + h2
      if right <= 0 or bottom <= 0 or x2 >= width_ or y2 >= height_: return DISJOINT
      if x2 >= 0 and y2 >= 0 and right <= width_ and bottom <= height_:
        if x2 == 0 and y2 == 0 and right == width_ and bottom == height_: return COINCIDENT
        return AREA-IN-CANVAS
      if x2 <= 0 and y2 <= 0 and right >= width_ and bottom >= height_: return CANVAS-IN-AREA
    return OVERLAP

  /**
  Constant to indicate that all pixels are transparent.
  For use with $composit.
  */
  static ALL-TRANSPARENT ::= #[0]
  /**
  Constant to indicate that all pixels are opaque.
  For use with $composit.
  */
  static ALL-OPAQUE ::= #[0xff]

  /**
  Mixes the $frame-canvas and the $painting-canvas together and draws
    them on the reciever.
  The opacity arguments determine the transparency (alpha) of the two
    canvas arguments.  They can be either canvases returned from
    $make-alpha-map, or they can be $ALL-OPAQUE or
    $ALL-TRANSPARENT.
  */
  abstract composit frame-opacity frame-canvas/Canvas painting-opacity painting-canvas/Canvas

  /**
  Draws a solid rectangle on the canvas in the given color.
  The rectangle is automatically clipped to the area of the canvas
    so it is not an error for the rectangle to be outside the
    canvas.
  */
  abstract rectangle x/int y/int --w/int --h/int --color/int -> none

  /**
  Draws the given text on the canvas in the given color.
  The background of the text is not drawn, that is, it is transparent.
  The text is automatically clipped to the area of the canvas
    so it is not an error for the text to be outside the
    canvas.
  The orientation is normally $ORIENTATION-0 (from "import bitmap"), but can be
    $ORIENTATION-90, $ORIENTATION-180, or $ORIENTATION-270, representing
    anti-clockwise rotation.
  The $x and $y represent the origin (bottom left corner) of the text.
    The text may extend below and to the left of this point if it contains
    descenders or starts with a character like "J" or "/", which in many fonts
    extend to the left of their origin.
  */
  abstract text x/int y/int --text/string --color/int --font/Font --orientation/int
  abstract text x/int y/int --text/string --color/int --font/Font

  /**
  Draws the given bitmap on the canvas.
  The bit order is as in PNG, so the lines are ordered from top to
    bottom, and within each line the bytes are ordered from left
    to right.  Within each byte, the high bits are on the left, and
    the low bits are on the right.
  Using the $alpha argument, the bitmap can be drawn with transparency.
    For examples if $alpha is #[0, 0xff] then the zeros in the bitmap
    are not drawn (transparent), whereas the the ones are drawn in the
    the color given by the $palette argument.  Other values between
    0 (transparent) and 0xff (opaque) can be used to give partial transparency.
  Using the $palette argument, the colors of the bitmap can be given,
    in rgbrgb order.  For example to draw the 0's in red and the 1's in
    white you would use #[0xff, 0, 0, 0xff, 0xff, 0xff] as the palette.
  The bitmap is automatically clipped to the area of the canvas
    so it is not an error for the bitmap to be outside the
    canvas.
  Using $source-line-stride a number of bytes can be skipped at the
    end of each line.  This is useful if the bitmap is padded, or
    the source is an uncompressed PNG which has a zero at the start
    of each line.
  The $orientation argument can be $ORIENTATION-0, $ORIENTATION-90,
    $ORIENTATION-180, or $ORIENTATION-270, from "import bitmap",
    representing anti-clockwise rotation of the drawn bitmap.
  */
  abstract bitmap x/int y/int -> none
      --pixels/ByteArray
      --alpha/ByteArray          // 2-element byte array.
      --palette/ByteArray        // 6-element byte array.
      --source-width/int         // In pixels.
      --source-line-stride/int   // In bytes.
      --orientation/int=ORIENTATION-0

  /**
  Draws the given 8-bit pixmap on the canvas.
  The source pixmap has one byte per pixel, which is an index into the
    $palette and $alpha arguments.  The order of the pixmap is as in
    PNG, so the lines are ordered from top to bottom, and within each
    line the bytes are ordered from left to right.
  The $alpha argument controls which pixel indexes are transparent.  A
    byte value of 0 means pixels with that index are transparent, and a byte
    value of 0xff means the pixels with that index are opaque.
  If the $alpha argument is shorter than the highest index in the pixmap, then
    pixels with high indices are opaque.
  The palette argument has 3 bytes per color, in rgbrgb order.  For example
    if the pixmap uses 0 to represent transparency, 1 to represent red, and
    2 to represent white, then the $palette should be
    #[0, 0, 0, 0xff, 0, 0, 0xff, 0xff, 0xff] and the $alpha argument should
    be #[0] to make the 0's transparent.
  If the $palette argument is shorter than the highest index in the pixmap,
    then pixels with high indices are assumed to be gray-scale with the
    index representing the gray value (white = 0xff).
  The $orientation argument can be $ORIENTATION-0, $ORIENTATION-90,
    $ORIENTATION-180, or $ORIENTATION-270, from "import bitmap",
    representing anti-clockwise rotation of the drawn pixmap.
  Using $source-line-stride a number of bytes can be skipped at the
    end of each line.  This is useful if the pixmap is padded, or
    the source is an uncompressed PNG which has a zero at the start
    of each line.
  */
  pixmap x/int y/int
      --pixels/ByteArray
      --alpha/ByteArray=#[]
      --palette/ByteArray=#[]
      --source-width/int
      --orientation/int=ORIENTATION-0
      --source-line-stride/int=source-width:
   throw "Unimplemented"

  /**
  Draws the given 24-bit pixmap on the canvas.
  The three source pixmaps ($r, $g, and $b) have one byte per pixel, which is
    the red, green, or blue component of the pixel.  The order of the pixmap
    is as in PNG, so the lines are ordered from top to bottom, and within each
    line the bytes are ordered from left to right.
  The $orientation argument can be $ORIENTATION-0, $ORIENTATION-90,
    $ORIENTATION-180, or $ORIENTATION-270, from "import bitmap",
    representing anti-clockwise rotation of the drawn pixmap.
  This method is only available on true-color canvases.
  */
  rgb-pixmap x/int y/int
      --r/ByteArray
      --g/ByteArray
      --b/ByteArray
      --source-width/int
      --orientation/int=ORIENTATION-0:
    throw "UNSUPPORTED"  // Only on true color canvas.

TRANSFORM-IDENTITY_ ::= Transform.with_ --x1=1 --x2=0 --y1=0 --y2=1 --tx=0 --ty=0
TRANSFORM-90_ ::= Transform.with_ --x1=0 --x2=-1 --y1=1 --y2=0 --tx=0 --ty=0
TRANSFORM-180_ ::= Transform.with_ --x1=-1 --x2=0 --y1=0 --y2=-1 --tx=0 --ty=0
TRANSFORM-270_ ::= Transform.with_ --x1=0 --x2=1 --y1=-1 --y2=0 --tx=0 --ty=0

/**
Classic 3x3 matrix for 2D transformations.
Right column is always 0 0 1, so we don't need to store it.
We don't support scaling so the top left 2x2 block is always 0s, 1s, and -1s.
*/
class Transform:
  // [ x1   y1    0  ]
  // [ x2   y2    0  ]
  // [ tx   ty    1  ]
  x1_/int ::= ?
  y1_/int ::= ?
  x2_/int ::= ?
  y2_/int ::= ?
  tx_/int ::= ?
  ty_/int ::= ?

  constructor.identity:
    return TRANSFORM-IDENTITY_

  constructor.with_ --x1/int --y1/int --x2/int --y2/int --tx/int --ty/int:
    x1_ = x1
    x2_ = x2
    tx_ = tx
    y1_ = y1
    y2_ = y2
    ty_ = ty

  /**
  Applies the other transform to this transform.
  Returns a transform that does both transformations in one transform.
  */
  apply other/Transform -> Transform:
    a0 := x1_
    a1 := y1_
    a2 := x2_
    a3 := y2_
    o0 := other.x1_
    o1 := other.y1_
    o2 := other.x2_
    o3 := other.y2_
    o4 := other.tx_
    o5 := other.ty_
    return Transform.with_
        --x1 = a0 * o0 + a2 * o1
        --y1 = a1 * o0 + a3 * o1
        --x2 = a0 * o2 + a2 * o3
        --y2 = a1 * o2 + a3 * o3
        --tx = a0 * o4 + a2 * o5 + tx_
        --ty = a1 * o4 + a3 * o5 + ty_

  /**
  Inverts this transform, returning a new transform that represents the
    inverse transformation.
  Since we don't support scaling, there always exists an inverse transform.
  */
  invert -> Transform:
    a0 := x1_
    a1 := y1_
    a2 := x2_
    a3 := y2_
    // The scaling of the transform is always 1, so we don't need to do anything about that.
    assert: a0 * a3 - a1 * a2 == 1
    return Transform.with_
        --x1 = a3
        --y1 = -a1
        --x2 = -a2
        --y2 = a0
        --tx = -a3 * tx_ + a2 * ty_
        --ty = a1 * tx_ - a0 * ty_

  /**
  Returns true if the transforms represent the same transformation.
  */
  operator == other/Transform -> bool:
    if x1_ != other.x1_: return false
    if y1_ != other.y1_: return false
    if x2_ != other.x2_: return false
    if y2_ != other.y2_: return false
    if tx_ != other.tx_: return false
    if ty_ != other.ty_: return false
    return true

  /**
  Finds the extent of a rectangle after it has been transformed with the transform.
  - $x-in: The left edge before the transformation is applied.
  - $y-in: The top edge before the transformation is applied.
  - $w-in: The width before the transformation is applied.
  - $h-in: The height before the transformation is applied.
  - $block: A block that is called with arguments left top width height in the transformed coordinate space.
  */
  xywh x-in/int y-in/int w-in/int h-in/int [block]:
    x-transformed := x x-in y-in
    y-transformed := y x-in y-in
    w-transformed := width w-in h-in
    h-transformed := height w-in h-in
    x2 := min
      x-transformed
      x-transformed + w-transformed
    y2 := min
      y-transformed
      y-transformed + h-transformed
    w2 := w-transformed.abs
    h2 := h-transformed.abs
    block.call x2 y2 w2 h2

  /**
  Finds a point and an orientation after it has been transformed with the transform.
  - $x-in: The x coordinate before the transformation is applied.
  - $y-in: The y coordinate before the transformation is applied.
  - $o-in: The orientation before the transformation is applied.
  - $block: A block that is called with arguments x y orientation in the transformed coordinate space.
  */
  xyo x-in/int y-in/int o-in/int [block]:
    x-transformed := x x-in y-in
    y-transformed := y x-in y-in
    o-transformed/int := ?
    if      x1_ > 0: o-transformed = o-in + ORIENTATION-0
    else if y1_ < 0: o-transformed = o-in + ORIENTATION-90
    else if x1_ < 0: o-transformed = o-in + ORIENTATION-180
    else:                  o-transformed = o-in + ORIENTATION-270
    block.call x-transformed y-transformed (o-transformed & 3)

  /**
  Returns a new transform which represents this transform rotated left
    around the origin in the space of this transform.
  */
  rotate-left -> Transform:
    return Transform.with_
        --x1 = -x2_
        --y1 = -y2_
        --x2 = x1_
        --y2 = y1_
        --tx = tx_
        --ty = ty_

  /**
  Returns a new transform which represents this transform rotated right
    around the origin in the space of this transform.
  */
  rotate-right -> Transform:
    return Transform.with_
        --x1 = x2_
        --y1 = y2_
        --x2 = -x1_
        --y2 = -y1_
        --tx = tx_
        --ty = ty_

  /**
  Returns a new transform.  The origin of the new transform is at the point
    $x, $y in the space of this transform.
  */
  translate x/int y/int -> Transform:
    return Transform.with_
      --x1 = x1_
      --y1 = y1_
      --x2 = x2_
      --y2 = y2_
      --tx = tx_ + (width x y)
      --ty = ty_ + (height x y)

  // Used for font rendering.
  orientation_:
    if x1_ > 0: return ORIENTATION-0
    if y1_ < 0: return ORIENTATION-90
    if x1_ < 0: return ORIENTATION-180
    else: return ORIENTATION-270

  /**
  Returns the transformed x coordinate of the given point ($x, $y).
  */
  x x/int y/int -> int:
    return x * x1_ + y * x2_ + tx_

  /**
  Returns the transformed y coordinate of the given point ($x, $y).
  */
  y x/int y/int -> int:
    return x * y1_ + y * y2_ + ty_

  /**
  Returns the transformed width given an unrotated $width and $height.
  A negative result indicates the shape extends to the left of the origin.
  */
  width width/int height/int -> int:
    return width * x1_ + height * x2_

  /**
  Returns the transformed height given an unrotated $width and $height.
  A negative result indicates the shape extends upwards from the origin.
  */
  height width/int height/int -> int:
    return width * y1_ + height * y2_

class TextExtent_:
  x := 0
  y := 0
  w := 0
  h := 0
  displacement := 0

  // Gets the graphical extent of a string nominally positioned at (0, 0),
  // Where the nominal position of the text is relative to the letters depends
  // on the alignment, but it is always somewhere on the textual baseline.
  // Some confusion is caused here by the fact that the y-axis of elements
  // grows towards the bottom, whereas the y-axis of fonts grows towards the
  // top.
  constructor text font alignment:
    box := font.text-extent text
    if alignment != ALIGN-LEFT:
      displacement = -(font.pixel-width text)
      if alignment == ALIGN-CENTER: displacement >>= 1
    w = box[0]
    h = box[1]
    x = box[2] + displacement
    y = -box[1] - box[3]

text-get-bounding-boxes_ old/string new/string alignment/int font/Font [block]:
  left-doesnt-move  := alignment == ALIGN-LEFT
  right-doesnt-move := alignment == ALIGN-RIGHT
  // If the rendered length does not change then both ends don't move.
  pixel-width-old := font.pixel-width old
  if pixel-width-old == (font.pixel-width new):
    left-doesnt-move = true
    right-doesnt-move = true
  length := min old.size new.size
  unchanged-left := 0
  unchanged-right := 0
  if left-doesnt-move:
    // Find out how many bytes are unchanged at the start of the string.
    unchanged-left = length
    for i := 0; i < length; i++:
      if old[i] != new[i]:
        unchanged-left = i
        break
  if right-doesnt-move:
    // Find out how many bytes are unchanged at the end of the string.
    unchanged-right = length
    last-character-start := 0  // Location (counting from end) of the start of the last UTF-8 sequence.
    for i := 0; i < length; i++:
      if old[old.size - 1 - i] != new[new.size - 1 - i]:
        unchanged-right = last-character-start
        break
      else if old[old.size - 1 - i]:
        last-character-start = i + 1
  if unchanged-right != 0 or unchanged-left != 0:
    changed-old := old.copy unchanged-left (old.size - unchanged-right)
    changed-new := new.copy unchanged-left (new.size - unchanged-right)
    changed-extent-old := TextExtent_ changed-old font alignment
    changed-extent-new := TextExtent_ changed-new font alignment
    if alignment == ALIGN-LEFT:
      unchanged-width := font.pixel-width old[..unchanged-left]
      changed-extent-old.x += unchanged-width
      changed-extent-new.x += unchanged-width
    else if alignment == ALIGN-RIGHT:
      unchanged-width := font.pixel-width old[old.size - unchanged-right..]
      // Make x relative to the text origin, which is the right edge.
      changed-extent-old.x -= unchanged-width
      changed-extent-new.x -= unchanged-width
    else:
      assert: alignment == ALIGN-CENTER
      assert: pixel-width-old == (font.pixel-width new)
      // Make x relative to the text origin, which is the middle.
      unchanged-width := ((pixel-width-old + 1) >> 1) - (font.pixel-width old[..unchanged-left])
      changed-extent-old.x -= unchanged-width + changed-extent-old.displacement
      changed-extent-new.x -= unchanged-width + changed-extent-new.displacement
    block.call changed-extent-old changed-extent-new

NULL-CANVAS_ ::= NullCanvas_

class NullCanvas_ extends Canvas:
  supports-8-bit -> bool: return true
  gray-scale -> bool: return false

  constructor:
    super 0 0

  stringify:
    return "true-color.NullCanvas_ $(width_)x$height_"

  set-all-pixels color/int -> none:

  get-pixel_ x y:
    throw "OUT_OF_BOUNDS"

  create-similar: return this

  make-alpha-map --padding/int=0 -> Canvas: return this

  subcanvas x/int y/int w/int h/int --ignore-x/bool=false --ignore-y/bool=false -> Canvas?: return this

  composit frame-opacity frame-canvas/Canvas? painting-opacity painting-canvas/Canvas -> none:

  rectangle x/int y/int --w/int --h/int --color/int:

  text x/int y/int --text/string --color/int --font/Font --orientation/int=ORIENTATION-0 -> none:

  bitmap x/int y/int -> none
      --pixels/ByteArray
      --alpha/ByteArray         // 2-element byte array.
      --palette/ByteArray       // 6-element byte array.
      --source-width/int        // In pixels.
      --source-line-stride/int  // In bytes.
      --orientation/int=ORIENTATION-0:

  pixmap x/int y/int -> none
      --pixels/ByteArray
      --alpha/ByteArray=#[]
      --palette/ByteArray=#[]
      --source-width/int
      --orientation/int=ORIENTATION-0
      --source-line-stride/int=source-width:
