// Copyright (C) 2018 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import bitmap show *
import .texture
import .two_color as two_color
import .three_color as three_color
import font show Font
import icons show Icon
import .four_gray as four_gray
import .true_color as true_color

FLAG_2_COLOR ::=         0b1
FLAG_3_COLOR ::=         0b10
FLAG_4_COLOR ::=         0b100
FLAG_GRAY_SCALE ::=      0b1000
FLAG_TRUE_COLOR ::=      0b10000
FLAG_PARTIAL_UPDATES ::= 0b100000

abstract class AbstractDriver:
  abstract width -> int
  abstract height -> int
  abstract flags -> int
  start_partial_update speed/int -> none:
  start_full_update speed/int -> none:
  clean left/int top/int right/int bottom/int -> none:
  commit left/int top/int right/int bottom/int -> none:
  draw_two_color x/int y/int w/int h/int pixels/ByteArray:
    throw "Not a two-color driver"
  draw_two_bit x/int y/int w/int h/int plane0/ByteArray plane1/ByteArray:
    throw "Not a two-bit driver"
  draw_true_color x/int y/int w/int h/int red/ByteArray green/ByteArray blue/ByteArray:
    throw "Not a true-color driver"
  close -> none:

class GraphicsContext:
  alignment/int ::= TEXT_TEXTURE_ALIGN_LEFT
  color/int ::= 0
  background/int ::= 0
  font/Font? ::= null
  transform/Transform ::= Transform.identity

  constructor:

  constructor.private_ .alignment .color .font .transform .background:

  /// Returns a copy of this GraphicsContext, but with the given changes.
  with --alignment/int=alignment --font/Font?=font --color/int=color --transform/Transform?=transform --translate_x/int=0 --translate_y/int=0 --rotation/int=0 --background/int=background:
    if rotation != 0:
      rotation %= 360
      if rotation < 0: rotation += 360
      if rotation % 90 != 0: throw "INVALID_ARGUMENT"
      while rotation != 0:
        transform = transform.rotate_left
        rotation -= 90
    if translate_x != 0 or translate_y != 0:
      transform = transform.translate translate_x translate_y
    return GraphicsContext.private_ alignment color font transform background

// Common code for pixel-based displays connected to devices.  Height and width
// are 8-aligned, and this class keeps track of the list of things to draw, and
// which areas need refreshing.  Add components with 'add' and render to
// the display with 'draw'.
abstract class PixelDisplay:
  // The image to display.
  textures_ := {}
  background_ := null
  handle_ := null
  width_ := 0
  height_ := 0
  flags_ := 0

  // Need-to-redraw is tracked as a bit array of dirty bits, arranged in
  // SSD1306 layout so we can use bitmap_rectangle to invalidate areas.
  // One bit in the dirty map covers an area of 8x8 pixels of the display.
  CLEAN ::= 1
  DIRTY ::= 0
  dirty_bytes_per_line_ := 0
  dirty_ := null

  driver_/AbstractDriver := ?
  speed_ := 50  // Speed-quality of current screen update.
  default_color_ := 0
  default_transform_ := Transform.identity

  constructor .driver_:
    width_ = driver_.width
    height_ = driver_.height
    flags_ = driver_.flags
    if width_ & 7 != 0: throw "Width must be multiple of 8"
    height := round_up height_ 8
    if flags_ & FLAG_PARTIAL_UPDATES != 0:
      dirty_bytes_per_line_ = (width_ >> 3) + 1
      dirty_strips := (height >> 6) + 1  // 8-tall strips of dirty bits.
      dirty_ = ByteArray dirty_bytes_per_line_ * dirty_strips  // Initialized to DIRTY, which is 0.

  abstract default_draw_color_ -> int
  abstract default_background_color_ -> int

  /**
  Returns a graphics context for the screen.
  With `--landscape=false` the context will use the display in landscape mode (wider than tall).
  With `--landscape=true` the context will use the display in portrait mode (taller than wide).
  With `--inverted=true` the context will use the display rotated 180 degrees.
  The default $color depends on the display.
  */
  context --landscape/bool?=null --inverted/bool=false --color/int=default_draw_color_ --alignment/int=TEXT_TEXTURE_ALIGN_LEFT --font/Font?=null --translate_x/int=0 --translate_y/int=0 --background/int=default_background_color_ -> GraphicsContext:
    transform/Transform ::= ?
    if landscape == null:
      transform = Transform.identity
      if inverted: throw "INVALID_ARGUMENT"
    else if landscape:
      if inverted:
        transform = inverted_landscape
      else:
        transform = this.landscape
    else:
      if inverted:
        transform = inverted_portrait
      else:
        transform = portrait
    translated := transform
    if translate_x != 0 or translate_y != 0:
      translated = transform.translate translate_x translate_y
    return GraphicsContext.private_ alignment color font translated background

  /** Returns a transform that uses the display in portrait mode.  */
  portrait -> Transform:
    if not portrait_:
      if height_ >= width_:
        portrait_ = Transform.identity
      else:
        portrait_ = (Transform.identity.translate 0 height_).rotate_left
    return portrait_
  portrait_ := null

  /**
  Returns a transform that uses the display in portrait mode, but rotated
    180 degrees relative to the portrait method.
  */
  inverted_portrait -> Transform:
    if not inverted_portrait_:
      if height_ >= width_:
        inverted_portrait_ = (Transform.identity.translate width_ height_).rotate_left.rotate_left
      else:
        inverted_portrait_ = (Transform.identity.translate width_ 0).rotate_right
    return inverted_portrait_
  inverted_portrait_ := null

  /** Returns a transform that uses the display in landscape mode.  */
  landscape -> Transform:
    if not landscape_:
      if height_ < width_:
        landscape_ = Transform.identity
      else:
        landscape_ = (Transform.identity.translate 0 height_).rotate_left
    return landscape_
  landscape_ := null

  /**
  Returns a transform that uses the display in landscape mode, but rotated
    180 degrees relative to the landscape method.  Sometimes called 'seascape'.
  */
  inverted_landscape -> Transform:
    if not inverted_landscape_:
      if height_ < width_:
        inverted_landscape_ = (Transform.identity.translate width_ height_).rotate_left.rotate_left
      else:
        inverted_landscape_ = (Transform.identity.translate width_ 0).rotate_right
    return inverted_landscape_
  inverted_landscape_ := null

  abstract background= color/int -> none

  /**
  Adds a texture to a display.  The next time the display is refreshed, this
    texture will be drawn.  Textures added to this display are drawn in the
    order they were added, so the first-added textures are at the back and the
    last-added are at the front.  However you can add textures via a
    TextureGroup.  This enables you to later add textures that are not at the
    front, by adding them to a TextureGroup that is not at the front.

  Adding an InfiniteBackground texture removes a previous InfiniteBackground
    texture.  This is deprecated: The preferred method is to set the background
    color with $background=.
  */
  add texture:
    if texture is InfiniteBackground_:
      background_ = texture
      invalidate 0 0 width_ height_
    else:
      textures_.add texture
      if texture is SizedTexture:
        texture.change_tracker = this
        texture.invalidate
      else:
        invalidate 0 0 width_ height_

  /**
  Removes a texture that was previously added.  You cannot remove a background
    texture.  Instead you should set a new background with @background=.
  */
  remove texture:
    if texture == background_:
      throw "BACKGROUND_REMOVED"
    textures_.remove texture
    texture.invalidate
    texture.change_tracker = null

  /** Removes all textures.  */
  remove_all:
    textures_.do: it.change_tracker = null
    if textures_.size != 0: invalidate 0 0 width_ height_
    textures_ = {}

  invalidate x y w h:
    if not dirty_: return  // Some devices don't use the dirty array to track changes.

    // Round up the invalidated area.
    rx := x & 7
    x = (x - rx) >> 3
    w = (w + rx + 7) >> 3
    ry := y & 7
    y = (y - ry) >> 3
    h = (h + ry + 7) >> 3

    // x, y, w, h now measured in 8x8 blocks.
    bitmap_rectangle x y DIRTY w h dirty_ dirty_bytes_per_line_

  line_is_clean_ y:
    idx := (y >> 6) * dirty_bytes_per_line_
    mask := 1 << ((y >> 3) & 0b111)
    dirty_bytes_per_line_.repeat: | byte |
      if dirty_[idx + byte] & mask == DIRTY: return false  // Only works because DIRTY == 0
    return true

  is_dirty_ x y:
    idx := (y >> 6) * dirty_bytes_per_line_
    mask := 1 << ((y >> 3) & 0b111)
    byte := x >> 3
    return dirty_[idx + byte] & mask == DIRTY  // Only works because DIRTY == 0

  /// For displays that don't support any form of partial update.
  abstract draw_entire_display_

  /**
  Draws the texture.

  After changing the display, for example by adding, removing or moving
    textures, call this to refresh the screen.  Optionally give a $speed
    between 0 and 100 to indicate the speed-image quality tradeoff.
  */
  draw --speed/int=50 -> none:
    speed_ = speed
    if speed < 10 or flags_ & FLAG_PARTIAL_UPDATES == 0:
      draw_entire_display_
      return

    // Send data for the whole screen, even if only part of it changed.
    if speed < 50: bitmap_zap dirty_ DIRTY

    // TODO(kasper): Once we've started a partial update, we need to make sure we refresh,
    // because otherwise the lock in the display code in the kernel will not be released.
    driver_.start_partial_update speed
    refreshed := false
    try:
      refresh_dimensions ::= [width_, 0, height_, 0]
      update_frame_buffer false refresh_dimensions
      refresh_ refresh_dimensions[0] refresh_dimensions[2] refresh_dimensions[1] refresh_dimensions[3]
      refreshed = true
    finally:
      if not refreshed: refresh_ 0 0 0 0

    bitmap_zap dirty_ CLEAN

  // Clean determines if we should clean or draw the dirty area.
  update_frame_buffer clean/bool refresh_dimensions:
    width := min width_ 128
    max_height := round_down (max_canvas_height_ width) 8

    for y:= 0; y < height_; y += max_height:
      while line_is_clean_ y:
        y += 8
        if y >= height_: break
      for x := 0; x < width_; x += width:
        left := x
        right := min x + width width_
        top := y
        bottom := min y + max_height height_
        dirty_left := right
        dirty_right := left
        dirty_top := bottom
        dirty_bottom := top
        for iy := top; iy < bottom; iy += 8:
          for ix := left; ix < right; ix += 8:
            if is_dirty_ ix iy:
              dirty_left = min dirty_left ix
              dirty_right = max dirty_right ix
              dirty_top = min dirty_top iy
              dirty_bottom = max dirty_bottom iy
        if dirty_left <= dirty_right:
          if dirty_top < refresh_dimensions[2]: refresh_dimensions[2] = dirty_top
          if dirty_bottom > refresh_dimensions[3]: refresh_dimensions[3] = dirty_bottom
          if dirty_left < refresh_dimensions[0]: refresh_dimensions[0] = dirty_left
          if dirty_right > refresh_dimensions[1]: refresh_dimensions[1] = dirty_right
          if clean:
            clean_rect_ dirty_left dirty_top dirty_right+8 dirty_bottom+8
          else:
            redraw_rect_ dirty_left dirty_top dirty_right+8 dirty_bottom+8

  abstract max_canvas_height_ width/int -> int

  abstract redraw_rect_ left/int top/int right/int bottom/int -> none

  clean_rect_ left/int top/int right/int bottom/int -> none:
    driver_.clean left top right bottom

  refresh_ left/int top/int right/int bottom/int -> none:
    driver_.commit left top right bottom

  /// Frees up the display so other process groups can use it.  
  /// This happens automatically when the process group exits.
  close -> none:
    driver_.close

class TwoColorPixelDisplay extends PixelDisplay:

  constructor driver/AbstractDriver:
    super driver
    background_ = two_color.InfiniteBackground two_color.WHITE

  default_draw_color_ -> int:
    return two_color.BLACK

  default_background_color_ -> int:
    return two_color.WHITE

  background= color/int -> none:
    if not background_ or background_.color != color:
      background_ = two_color.InfiniteBackground color
      invalidate 0 0 width_ height_

  text context/GraphicsContext x/int y/int text/string -> two_color.TextTexture:
    if context.font == null: throw "NO_FONT_GIVEN"
    texture := two_color.TextTexture x y context.transform context.alignment text context.font context.color
    add texture
    return texture

  icon context/GraphicsContext x/int y/int icon/Icon -> two_color.IconTexture:
    texture := two_color.IconTexture x y context.transform context.alignment icon icon.font_ context.color
    add texture
    return texture

  filled_rectangle context/GraphicsContext x/int y/int width/int height/int -> two_color.FilledRectangle:
    texture := two_color.FilledRectangle context.color x y width height context.transform
    add texture
    return texture

  /// A line from $x1,$y1 to $x2,$y2.
  /// The line must be horizontal or vertical.
  line context/GraphicsContext x1/int y1/int x2/int y2/int -> two_color.FilledRectangle:
    texture := two_color.FilledRectangle.line context.color x1 y1 x2 y2 context.transform
    add texture
    return texture

  /**
  A texture that contains an uncompressed 2-color image.  Initially all
    pixels are transparent, but pixels can be given the color from the context
    with set_pixel.
  */
  bitmap context/GraphicsContext x/int y/int width/int height/int -> two_color.BitmapTexture:
    texture := two_color.BitmapTexture x y width height context.transform context.color
    add texture
    return texture

  /**
  A texture that contains an uncompressed 2-color image.  Initially all
    pixels have the background color from the context.  Pixels can be set to
    the context color with set_pixel, or set to the context background color
    with clear_pixel.
  */
  opaque_bitmap context/GraphicsContext x/int y/int width/int height/int -> two_color.OpaqueBitmapTexture:
    texture := two_color.OpaqueBitmapTexture x y width height context.transform context.color context.background
    add texture
    return texture

  /**
  A texture backed by a P4 (binary two-level) PBM file.  The white areas
    (zeros) are rendered transparent and the black areas (ones) are rendered in
    an the color from the context.  This is normally more efficient than the
    Pbm class, but it cannot scale the image.
  */
  pbm context/GraphicsContext x/int y/int bytes/ByteArray:
    texture := two_color.PbmTexture x y context.transform context.color bytes
    add texture
    return texture

  /**
  A texture backed by a P4 (binary two-level) PBM file.  The colors in the
    context are ignored, and pixels are rendered with the colors they have in
    the file.  This is normally more efficient than the Pbm class, but it
    cannot scale the image.
  */
  opaque_pbm context/GraphicsContext x/int y/int bytes/ByteArray:
    texture := two_color.OpaquePbmTexture x y context.transform bytes
    add texture
    return texture

  max_canvas_height_ width/int -> int:
    height := 0
    width_rounded := round_up width 8
    height_rounded := round_up height_ 8
    if width_rounded * height_rounded >> 3 < 4000:
      // If we can fit both the red and black plane in < 8k then do that.
      height = height_rounded
    else:
      // Some multiple of 8 where each plane fits in one page.
      height = (4000 / width_rounded) << 3
    // We can't work well with canvases that are less than 8 pixels tall.
    return max 8 height

  draw_entire_display_:
    driver_.start_full_update speed_
    w := width_
    step := max_canvas_height_ width_
    canvas := two_color.Canvas w (min step (round_up height_ 8))
    pixels := canvas.pixels_
    for y := 0; y < height_; y += step:
      background_.write 0 y canvas
      textures_.do: it.write 0 y canvas
      driver_.draw_two_color 0 y width_ (min (y + step) height_) pixels
    driver_.commit 0 0 width_ height_

  redraw_rect_ left/int top/int right/int bottom/int -> none:
    canvas := two_color.Canvas (right - left) (bottom - top)
    background_.write left top canvas
    textures_.do: it.write left top canvas
    driver_.draw_two_color left top right bottom canvas.pixels_

class FourGrayPixelDisplay extends TwoBitPixelDisplay_:
  constructor driver/AbstractDriver:
    super driver
    background_ = four_gray.InfiniteBackground four_gray.WHITE

  background= color/int -> none:
    if not background_ or background_.color != color:
      background_ = four_gray.InfiniteBackground color
      invalidate 0 0 width_ height_

  default_draw_color_ -> int:
    return four_gray.BLACK

  default_background_color_ -> int:
    return four_gray.WHITE

  text context/GraphicsContext x/int y/int text/string -> four_gray.TextTexture:
    if context.font == null: throw "NO_FONT_GIVEN"
    texture := four_gray.TextTexture x y context.transform context.alignment text context.font context.color
    add texture
    return texture

  icon context/GraphicsContext x/int y/int icon/Icon -> four_gray.IconTexture:
    texture := four_gray.IconTexture x y context.transform context.alignment icon icon.font_ context.color
    add texture
    return texture

  filled_rectangle context/GraphicsContext x/int y/int width/int height/int -> four_gray.FilledRectangle:
    texture := four_gray.FilledRectangle context.color x y width height context.transform
    add texture
    return texture

  /// A line from x1,y1 to x2,y2.  The line must be horizontal or vertical.
  line context/GraphicsContext x1/int y1/int x2/int y2/int -> four_gray.FilledRectangle:
    texture := four_gray.FilledRectangle.line context.color x1 y1 x2 y2 context.transform
    add texture
    return texture

  /**
  A texture that contains an uncompressed 2-color image.  Initially all
    pixels are transparent, but pixels can be given the color from the
    context with set_pixel.
  */
  bitmap context/GraphicsContext x/int y/int width/int height/int -> four_gray.BitmapTexture:
    texture := four_gray.BitmapTexture x y width height context.transform context.color
    add texture
    return texture

  /**
  A texture that contains an uncompressed 2-color image.  Initially all
    pixels have the background color from the context.  Pixels can be set to
    the context color with set_pixel, or set to the context background color
    with clear_pixel.
  */
  opaque_bitmap context/GraphicsContext x/int y/int width/int height/int -> four_gray.OpaqueBitmapTexture:
    texture := four_gray.OpaqueBitmapTexture x y width height context.transform context.color context.background
    add texture
    return texture

  /**
  A texture that contains an uncompressed 4-gray image.  Initially all
    pixels have the background color from the context.  Pixels can be set to
    any gray level with the context color with set_pixel, or set to the context
    background color with clear_pixel.
  */
  pixmap context/GraphicsContext x/int y/int width/int height/int -> four_gray.OpaquePixmapTexture:
    texture := four_gray.OpaquePixmapTexture x y width height context.transform context.background
    add texture
    return texture

class ThreeColorPixelDisplay extends TwoBitPixelDisplay_:
  constructor driver/AbstractDriver:
    super driver
    background_ = three_color.InfiniteBackground three_color.WHITE

  background= color/int -> none:
    if not background_ or background_.color != color:
      background_ = three_color.InfiniteBackground color
      invalidate 0 0 width_ height_

  default_draw_color_ -> int:
    return three_color.BLACK

  default_background_color_ -> int:
    return three_color.WHITE

  text context/GraphicsContext x/int y/int text/string -> three_color.TextTexture:
    if context.font == null: throw "NO_FONT_GIVEN"
    texture := three_color.TextTexture x y context.transform context.alignment text context.font context.color
    add texture
    return texture

  icon context/GraphicsContext x/int y/int icon/Icon -> three_color.IconTexture:
    texture := three_color.IconTexture x y context.transform context.alignment icon icon.font_ context.color
    add texture
    return texture

  filled_rectangle context/GraphicsContext x/int y/int width/int height/int -> three_color.FilledRectangle:
    texture := three_color.FilledRectangle context.color x y width height context.transform
    add texture
    return texture

  /// A line from x1,y1 to x2,y2.  The line must be horizontal or vertical.
  line context/GraphicsContext x1/int y1/int x2/int y2/int -> three_color.FilledRectangle:
    texture := three_color.FilledRectangle.line context.color x1 y1 x2 y2 context.transform
    add texture
    return texture

  /**
  A texture that contains an uncompressed 2-color image.  Initially all
    pixels are transparent, but pixels can be given the color from the context
    with set_pixel.
  */
  bitmap context/GraphicsContext x/int y/int width/int height/int -> three_color.BitmapTexture:
    texture := three_color.BitmapTexture x y width height context.transform context.color
    add texture
    return texture

  /**
  A texture that contains an uncompressed 2-color image.  Initially all
    pixels have the background color from the context.  Pixels can be set to
    the context color with set_pixel, or set to the context background color
    with clear_pixel.
  */
  opaque_bitmap context/GraphicsContext x/int y/int width/int height/int -> three_color.OpaqueBitmapTexture:
    texture := three_color.OpaqueBitmapTexture x y width height context.transform context.color context.background
    add texture
    return texture

abstract class TwoBitPixelDisplay_ extends PixelDisplay:
  background_ := three_color.InfiniteBackground three_color.WHITE

  constructor driver/AbstractDriver:
    super driver

  max_canvas_height_ width:
    height := 0
    width_rounded := round_up width 8
    height_rounded := round_up height 8
    if width_rounded * height_rounded >> 3 < 4000:
      // If we can fit both the red and black plane in < 8k then do that.
      height = height_rounded
    else:
      // Some multiple of 8 where each plane fits in one page.
      height = (4000 / width_rounded) << 3
    // We can't work well with canvases that are less than 8 pixels tall.
    return max 8 height

  draw_entire_display_:
    driver_.start_full_update speed_
    w := width_
    step := max_canvas_height_ width_
    canvas := three_color.Canvas w (min step (round_up height_ 8))
    List.chunk_up 0 height_ step: | y y_end |
      background_.write 0 y canvas
      textures_.do: it.write 0 y canvas
      driver_.draw_two_bit 0 y width_ y_end canvas.plane_0_ canvas.plane_1_
    driver_.commit 0 0 width_ height_

  redraw_rect_ left/int top/int right/int bottom/int -> none:
    canvas := three_color.Canvas (right - left) (bottom - top)
    background_.write left top canvas
    textures_.do: it.write left top canvas
    driver_.draw_two_bit left top right bottom canvas.plane_0_ canvas.plane_1_

class TrueColorPixelDisplay extends PixelDisplay:
  constructor driver/AbstractDriver:
    super driver
    background_ = true_color.InfiniteBackground true_color.WHITE

  background= color/int -> none:
    if not background_ or background_.color != color:
      background_ = true_color.InfiniteBackground color
      invalidate 0 0 width_ height_

  text context/GraphicsContext x/int y/int text/string -> true_color.TextTexture:
    if context.font == null: throw "NO_FONT_GIVEN"
    texture := true_color.TextTexture x y context.transform context.alignment text context.font context.color
    add texture
    return texture

  icon context/GraphicsContext x/int y/int icon/Icon -> true_color.IconTexture:
    texture := true_color.IconTexture x y context.transform context.alignment icon icon.font_ context.color
    add texture
    return texture

  filled_rectangle context/GraphicsContext x/int y/int width/int height/int -> true_color.FilledRectangle:
    texture := true_color.FilledRectangle context.color x y width height context.transform
    add texture
    return texture

  /// A line from x1,y1 to x2,y2.  The line must be horizontal or vertical.
  line context/GraphicsContext x1/int y1/int x2/int y2/int -> true_color.FilledRectangle:
    texture := true_color.FilledRectangle.line context.color x1 y1 x2 y2 context.transform
    add texture
    return texture

  /**
  A texture that contains an uncompressed 2-color image.  Initially all
    pixels are transparent, but pixels can be given the color from the context
    with set_pixel.
  */
  bitmap context/GraphicsContext x/int y/int width/int height/int -> true_color.BitmapTexture:
    texture := true_color.BitmapTexture x y width height context.transform context.color
    add texture
    return texture

  /**
  A texture that contains an uncompressed 2-color image.  Initially all
    pixels have the background color from the context.  Pixels can be set to
    the context color with set_pixel, or set to the context background color
    with clear_pixel.
  */
  opaque_bitmap context/GraphicsContext x/int y/int width/int height/int -> true_color.OpaqueBitmapTexture:
    texture := true_color.OpaqueBitmapTexture x y width height context.transform context.color context.background
    add texture
    return texture

  default_draw_color_ -> int:
    return true_color.BLACK

  default_background_color_ -> int:
    return true_color.WHITE

  max_canvas_height_ width:
    height := 0
    // Keep each color component under 2k then the packed 3-colors-in-2-bytes
    // format is still less than a page.
    height = round_down (2000 / width) 8
    // We can't work well with canvases that are less than 8 pixels tall.
    return max 8 height

  draw_entire_display_:
    driver_.start_full_update speed_
    w := width_
    canvas := true_color.Canvas w 8
    for y := 0; y < height_; y += 8:
      background_.write 0 y canvas
      textures_.do: it.write 0 y canvas
      driver_.draw_true_color 0 y width_ 8 canvas.red_ canvas.green_ canvas.blue_
    driver_.commit 0 0 width_ height_

  redraw_rect_ left/int top/int right/int bottom/int -> none:
    canvas := true_color.Canvas (right - left) (bottom - top)
    background_.write left top canvas
    textures_.do: it.write left top canvas
    driver_.draw_true_color left top right bottom canvas.red_ canvas.green_ canvas.blue_
