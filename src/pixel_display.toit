// Copyright (C) 2018 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/**
A library for rendering on pixel-based displays attached to devices.
See https://docs.toit.io/language/sdk/display
*/

import bitmap show *
import font show Font
import icons show Icon

import .bar-code
import .common
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
  // SSD1306 layout so we can use bitmap_rectangle to invalidate areas.
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
