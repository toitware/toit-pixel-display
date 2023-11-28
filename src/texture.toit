// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import binary show LITTLE_ENDIAN
import bitmap show *
import .bar_code
import .common
import .true_color as true_color
import .one_byte as one_byte
import font show Font
import math

export Transform

/**
Something you can draw on a canvas.  It could be a text string, a pixmap or
  a geometric figure. They can be stacked up and will be drawn from back to
  front, with transparency.
*/
abstract class Texture extends ElementOrTexture_:

/**
Most $Texture s have a size and know their own position in the scene, and are
  thus SizedTextures.  A sized texture keeps track of the coordinate system that
  it lives in, via the $transform_.  It also tracks the untransformed left,
  top, width and height of the texture, and the transformed left, top, width
  and height of the texture with the current transform.
*/
abstract class SizedTexture extends Texture:
  x_ /int := 0
  y_ /int := 0
  w_ /int := 0
  h_ /int := 0
  transform_ /Transform := Transform.identity

  transform -> Transform: return transform_

  /**
  Create a new SizedTexture with the given position and size in the
    coordinate system of the given transform.
  $x_: The left of the texture.
  $y_: The top of the texture.
  $w_: The width of the texture.
  $h_: The height of the texture.
  $transform_: The coordinate system of the texture.
  */
  constructor .x_ .y_ .w_ .h_ .transform_:

  /**
  Returns the left edge of the texture in the display coordinates.
  */
  display_x -> int:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      return x2
    unreachable

  /**
  Returns the top edge of the texture in the display coordinates.
  */
  display_y -> int:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      return y2
    unreachable

  /**
  Returns the width of the texture in the display coordinates.
  */
  display_w -> int:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      return w2
    unreachable

  /**
  Returns the height of the texture in the display coordinates.
  */
  display_h -> int:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      return h2
    unreachable

  /**
  Returns the left edge of the texture in the coordinate system of the transform.
  */
  x -> int:
    return x_

  /**
  Returns the top edge of the texture in the coordinate system of the transform.
  */
  y -> int:
    return y_

  /**
  Invalidates (mark for redrawing) the entire area of this texture.
  */
  invalidate:
    if change_tracker:
      transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
        change_tracker.child_invalidated x2 y2 w2 h2

  /**
  Sets a new coordinate system for the texture.  This can cause it to move or rotate.
  */
  set_transform new_transform/Transform -> none:
    invalidate
    transform_ = new_transform
    invalidate

  /**
  Invalidates (mark for redrawing) a part of this texture.  Coordinates are
    in the transforms coordinate system.
  $x: The left edge of the area to redraw.
  $y: The top edge of the area to redraw.
  $w: The width of the area to redraw.
  $h: The height of the area to redraw.
  */
  invalidate x/int y/int w/int h/int -> none:
    if change_tracker:
      transform_.xywh x y w h: | x2 y2 w2 h2 |
        change_tracker.child_invalidated x2 y2 w2 h2

  /**
  Moves to a new position in the coordinate system of the texture's transform.
  $new_x: New left edge in the texture's own coordinate system.
  $new_y: New top edge in the texture's own coordinate system.
  */
  move_to new_x/int new_y/int -> none:
    if new_x != x_ or new_y != y_:
      invalidate
      x_ = new_x
      y_ = new_y
      invalidate

  // Redraws in a tile that will be copied to a part of the display.
  write_ canvas/Canvas -> none:
    win_w := canvas.width_
    win_h := canvas.height_
    win_x := canvas.x_offset_
    win_y := canvas.y_offset_
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      if win_x + win_w <= x2: return  // Right hand side of window is to the left of this texture.
      if win_x >= x2 + w2: return     // Left hand side of window is to the right of this texture.
      if win_y + win_h <= y2: return  // Bottom of window is above this texture.
      if win_y >= y2 + h2: return     // Top of window is below this texture.
    write2_ canvas

  /**
  # Inheritance
  Override with method that will redraw in a file that will be copied to a
    part of the display.  Is not called for tiles that are wholly disjoint
    with the texture.
  */
  abstract write2_ canvas

abstract class ResizableTexture extends SizedTexture:
  constructor x/int y/int w/int h/int transform/Transform:
    super x y w h transform

  width= new_width/int:
    if new_width != w_:
      invalidate
      w_ = new_width
      invalidate

  height= new_height/int:
    if new_height != h_:
      invalidate
      h_ = new_height
      invalidate

// Texture that draws a standard EAN-13 bar code.  TODO: Other scales.
abstract class BarCodeEan13_ extends SizedTexture:
  sans10_ ::= Font.get "sans10"
  number_height_ := EAN_13_BOTTOM_SPACE

  code_ := ?  // 13 digit code as a string.

  /**
  $code_: The 13 digit product code.
  $x: The left edge of the barcode in the coordinate system of the transform.
  $y: The top edge of the barcode in the coordinate system of the transform.
  $transform: The coordinate system of the barcode.
  */
  constructor .code_/string x/int y/int transform/Transform:
    // The numbers go below the bar code in a way that depends on the size
    // of the digits, so we need to take that into account when calculating
    // the bounding box.
    number_height_ = (sans10_.text_extent "8")[1]
    height := EAN_13_HEIGHT + number_height_ - EAN_13_BOTTOM_SPACE
    w := EAN_13_WIDTH
    h := height + 1
    super x y w h transform

  l_ digit:
    return EAN_13_L_CODES_[digit & 0xf]

  g_ digit:
    return EAN_13_G_CODES_[digit & 0xf]

  r_ digit:
    return (l_ digit) ^ 0x7f

  // Make a white background behind the bar code and draw the digits along the bottom.
  draw_background_ canvas/Canvas:
    // Background of a bar code is always white (0 color).
    transform_.xywh x y w_ h_: | x2 y2 w2 h2 |
      white_square_
          x2 - canvas.x_offset_
          y2 - canvas.y_offset_
          w2
          h2
          canvas

    text_orientation := transform_.orientation_

    // Bar code coordinates.
    text_x := x + EAN_13_QUIET_ZONE_WIDTH + EAN_13_START_WIDTH
    text_y := y + EAN_13_HEIGHT + number_height_ - EAN_13_BOTTOM_SPACE + 1

    // Canvas coordinates.
    canvas_x := (transform_.x x + 1 text_y) - canvas.x_offset_
    canvas_y := (transform_.y x + 1 text_y) - canvas.y_offset_
    digit_ (code_.copy 0 1) canvas_x canvas_y canvas text_orientation

    canvas_x = (transform_.x text_x text_y) - canvas.x_offset_
    canvas_y = (transform_.y text_x text_y) - canvas.y_offset_
    step_x := (transform_.width 1 0)
    step_y := (transform_.height 1 0)
    (code_.copy 1 7).split "":
      if it != "":
        digit_ it canvas_x canvas_y canvas text_orientation
        canvas_x += EAN_13_DIGIT_WIDTH * step_x
        canvas_y += EAN_13_DIGIT_WIDTH * step_y
    canvas_x += (EAN_13_MIDDLE_WIDTH - 1) * step_x
    canvas_y += (EAN_13_MIDDLE_WIDTH - 1) * step_y
    (code_.copy 7 13).split "":
      if it != "":
        digit_ it canvas_x canvas_y canvas text_orientation
        canvas_x += EAN_13_DIGIT_WIDTH * step_x
        canvas_y += EAN_13_DIGIT_WIDTH * step_y
    marker_width := (sans10_.text_extent ">")[0]
    canvas_x += (EAN_13_START_WIDTH + EAN_13_QUIET_ZONE_WIDTH - marker_width) * step_x
    canvas_y += (EAN_13_START_WIDTH + EAN_13_QUIET_ZONE_WIDTH - marker_width) * step_y
    digit_ ">" canvas_x canvas_y canvas text_orientation

  // Draw a black rectangle from x,y sized width,height in canvas coordinates.
  abstract block_ x y width height canvas

  // Draw a white background rectangle from x,y sized width,height in canvas
  // coordinates.
  abstract white_square_ x y w h canvas

  // Draw a digit at x,y in canvas coordinates.
  abstract digit_ digit x y canvas orientation

  // Line in transform coordinates.
  line_ x top bottom canvas/Canvas transform:
    height := bottom - top
    transform.xywh x top 1 height: | x y w h |
      block_ x - canvas.x_offset_ y - canvas.y_offset_ w h canvas

  // Redraw routine.
  write2_ canvas/Canvas:
    win_x := canvas.x_offset_
    win_y := canvas.y_offset_
    draw_background_ canvas

    x := x_ + EAN_13_QUIET_ZONE_WIDTH
    top := y_

    bottom := y_ + EAN_13_HEIGHT
    y := bottom - EAN_13_BOTTOM_SPACE
    // Start bars: 101.
    line_ x     top bottom canvas transform_
    line_ x + 2 top bottom canvas transform_
    x += 3
    first_code := EAN_13_FIRST_CODES_[code_[0] & 0xf]
    // Left digits using the L or G mapping.
    for i := 1; i < 7; i++:
      digit := code_[i]
      code := ((first_code >> (6 - i)) & 1) == 0 ? (l_ digit) : (g_ digit)
      for b := 6; b >= 0; b--:
        if ((1 << b) & code) != 0:
          line_ x top y canvas transform_
        x++
    // Middle bars: 01010
    line_ x + 1 top bottom canvas transform_
    line_ x + 3 top bottom canvas transform_
    x += 5
    // Left digits using the R mapping.
    for i := 7; i < 13; i++:
      digit := code_[i]
      code := r_ digit
      for b := 6; b >= 0; b--:
        if ((1 << b) & code) != 0:
          line_ x top y canvas transform_
        x++
    // End bars: 101.
    line_ x     top bottom canvas transform_
    line_ x + 2 top bottom canvas transform_

TEXT_TEXTURE_ALIGN_LEFT ::= 0
TEXT_TEXTURE_ALIGN_CENTER ::= 1
TEXT_TEXTURE_ALIGN_RIGHT ::= 2

/**
A texture that represents the graphical display of a string.
*/
abstract class TextTexture_ extends SizedTexture:
  // Position in the coordinate system of the transform of the textual origin.
  // The actual text may extend below and to the left of this point, especially
  // with an alignment that is not TEXT_TEXTURE_ALIGN_LEFT.
  text_x_ := 0
  text_y_ := 0
  alignment_ := 0
  displacement := 0
  string_ := ?
  font_ := ?

  /**
  $text_x_: The X coordinate of the origin of the text string.  For left aligned
    text this is the left of the text string (though some characters may overhang the left
    edge, depending on the font).
  $text_y_: The Y coordinate of the origin of the text string.  This is the baseline
    of the text string (though some characters extend below the baseline).
  $transform: The coordinate system in which the string is placed.
  $string_: The actual text to be displayed.
  $font_: The font to display the string with.
  */
  constructor .text_x_/int .text_y_/int transform/Transform .alignment_/int .string_/string .font_/Font:
    extent := TextExtent_ string_ font_ alignment_
    displacement = extent.displacement
    super
      text_x_ + extent.x
      text_y_ + extent.y
      extent.w
      extent.h
      transform

  /**
  Returns the current text being displayed.
  */
  text -> string:
    return string_

  /**
  Returns the current alignment of the string, either
    TEXT_TEXTURE_ALIGN_LEFT, TEXT_TEXTURE_ALIGN_CENTER, or
    TEXT_TEXTURE_ALIGN_RIGHT.
  */
  alignment:
    return alignment_

  /**
  Set a new string for this TextTexture to display.  If the string
    is related to the previous string, it tries to find the minimum screen
    area that needs updating.
  */
  text= new_string/string -> none:
    if new_string == string_: return
    if not change_tracker:
      string_ = new_string
      fix_bounding_box_
      return

    text_get_bounding_boxes_ string_ new_string alignment_ font_: | changed_extent_old/TextExtent_ changed_extent_new/TextExtent_ |
      invalidate_extent_ changed_extent_old
      invalidate_extent_ changed_extent_new
      string_ = new_string
      fix_bounding_box_
      return
    string_ = new_string
    update_

  invalidate_extent_ ex:
    invalidate
      text_x_ + ex.x
      text_y_ + ex.y
      ex.w
      ex.h

  /**
  Sets a new alignment for this TextTexture to display.
  */
  alignment= new_alignment/int -> none:
    if new_alignment == alignment_: return
    alignment_ = alignment
    update_

  /**
  Sets a new font for this TextTexture to display.
  */
  font= new_font/Font -> none:
    if new_font == font_: return
    font_ = new_font
    update_

  /**
  Sets the alignment of this TextTexture to "center".
  */
  center -> none:
    alignment = TEXT_TEXTURE_ALIGN_CENTER

  /**
  Sets the alignment of this TextTexture to "right".
  */
  align_right -> none:
    alignment = TEXT_TEXTURE_ALIGN_RIGHT

  /**
  Sets the alignment of this TextTexture to "left".
  */
  align_left -> none:
    alignment = TEXT_TEXTURE_ALIGN_LEFT

  /**
  Moves the text origin to new coordinates.
  */
  move_to new_x/int new_y/int -> none:
    if new_x == text_x_ and new_y == text_y_: return
    text_x_ = new_x
    text_y_ = new_y
    update_

  fix_bounding_box_:
    extent := TextExtent_ string_ font_ alignment_
    displacement = extent.displacement
    x_ = text_x_ + extent.x
    y_ = text_y_ + extent.y
    w_ = extent.w
    h_ = extent.h

  update_ -> none:
    invalidate
    fix_bounding_box_
    invalidate

  // After the textures under us have drawn themselves, we draw on top.
  write2_ canvas/Canvas:
    x2 := transform_.x text_x_ + displacement text_y_
    y2 := transform_.y text_x_ + displacement text_y_
    draw_
      x2 - canvas.x_offset_
      y2 - canvas.y_offset_
      transform_.orientation_
      canvas

  abstract draw_ bx by orientation canvas

/**
A rectangle in a solid color.
*/
abstract class FilledRectangle_ extends ResizableTexture:
  constructor x/int y/int w/int h/int transform/Transform:
    super x y w h transform

  // Draw a colored rectangle at x,y on the canvas.
  write2_ canvas/Canvas:
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      start_x := x2 - canvas.x_offset_
      start_y := y2 - canvas.y_offset_
      translated_write_ start_x start_y w2 h2 canvas

  // Takes canvas coordinates.
  abstract translated_write_ x y w h canvas

  // A helper method to make lines out of our rectangle primitives.
  static line_ x1 y1 x2 y2 [build]:
    if x1 == x2:
      if y1 <= y2:
        return build.call x1 y1 1 y2 - y1
      else:
        return build.call x1 y2 1 y1 - y2
    else if y1 == y2:
      if x1 <= x2:
        return build.call x1 y1 x2 - x1 1
      else:
        return build.call x2 y1 x1 - x2 1
    else:
      throw "LINE_NOT_HORIZONTAL_OR_VERTICAL"


/**
A collections of textures which can be added to a display as a single texture.
  It is not visible, only the textures it contains are visible.  It has no
  dimensions.  Textures added to this group are drawn in the order they were
  added, so the first-added textures are at the back and the last-added are
  at the front.
*/
class TextureGroup extends Texture implements Window:
  elements_ := []
  inner_width -> int?: unreachable  // Not used by textures, only elements.
  inner_height -> int?: unreachable

  add element -> none:
    elements_.add element
    element.change_tracker = this
    element.invalidate

  remove element -> none:
    element.invalidate
    elements_.remove element
    element.change_tracker = null

  remove_all -> none:
    elements_.do:
      it.invalidate
      it.change_tracker = null
    elements_ = []

  // After the textures under us have drawn themselves, we draw on top.
  write_ canvas/Canvas -> none:
    elements_.do: it.write canvas

  // We don't crop anything, just pass on the invalidation to the next higher Window.
  child_invalidated x/int y/int w/int h/int -> none:
    if change_tracker:
      change_tracker.child_invalidated x y w h

  child_invalidated_element x/int y/int w/int h/int -> none:
    throw "NOT_IMPLEMENTED"

  invalidate -> none:
    elements_.do: it.invalidate

abstract class BorderlessWindow_ extends ResizableTexture implements Window:
  elements_ := {}
  inner_width -> int?: unreachable  // Not used by textures, only elements.
  inner_height -> int?: unreachable

  constructor x/int y/int w/int h/int transform:
    this.transform = transform.translate x y
    super x y w h transform

  add element/Texture -> none:
    elements_.add element
    element.change_tracker = this
    element.invalidate

  remove element/Texture -> none:
    elements_.remove element
    element.invalidate
    element.change_tracker = null

  remove_all -> none:
    elements_.do:
      it.invalidate
      it.change_tracker = null
    elements_.remove_all

  transform /Transform := ?

  child_invalidated_element x/int y/int w/int h/int -> none:
    throw "NOT_IMPLEMENTED"

  child_invalidated x/int y/int w/int h/int -> none:
    right := x + w
    bottom := y + h
    // We got the dimensions of the invalidation in driver frame of reference.
    // We must trim them to fit the window, and pass them on.
    transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
      // Now we have our own coordinates in driver frame of reference.
      left2 := max x x2
      top2 := max y y2
      right2 := min right (x2 + w2)
      bottom2 := min bottom (y2 + h2)
      if right2 > left2 and bottom2 > top2:
        if change_tracker:
          change_tracker.child_invalidated left2 top2 (right2 - left2) (bottom2 - top2)

/**
A WindowTexture_ is a collections of textures.  It is modeled like a painting hung on
  a wall.  It consists (from back to front) of a wall, a frame and the painting
  itself. The optional frame extends around and behind the picture, and can be
  partially transparent on true-color displays, which enables drop shadows.  The
  painting can also be partially transparent.
*/
abstract class WindowTexture_ extends BorderlessWindow_ implements Window:
  inner_x_ /int := ?
  inner_y_ /int := ?
  inner_w_ /int := ?
  inner_h_ /int := ?

  /**
  Changes the inner width (without any borders) of the window.
  */
  width= new_width/int:
    if new_width != inner_w_:
      inner_w_ = new_width
      update_

  /**
  Changes the inner height (without any borders) of the window.
  */
  height= new_height/int:
    if new_height != inner_h_:
      inner_h_ = new_height
      update_

  /**
  Changes the top left corner (without any borders) of the window.
  */
  move_to new_x/int new_y/int -> none:
    if new_x != inner_x_ or new_y != inner_y_:
      inner_x_ = new_x
      inner_y_ = new_y
      update_

  update_ -> none:
    invalidate
    fix_bounding_box_
    invalidate

  abstract fix_bounding_box_ -> none

  static ALL_TRANSPARENT ::= ByteArray 1: 0
  static ALL_OPAQUE ::= ByteArray 1: 0xff

  static is_all_transparent opacity/ByteArray -> bool:
    return opacity.size == 1 and opacity[0] == 0

  static is_all_opaque opacity/ByteArray -> bool:
    return opacity.size == 1 and opacity[0] == 0xff

  /**
  Returns a canvas that is an alpha map for the given area that describes where
    the wall around this window shines through.  This defines the edges and
    shadows of a window frame.  For 2-color and 3-color textures this is a
    bitmap with 0 for transparent and 1 for opaque.  For true-color and
    gray-scale textures it is a bytemap with 0 for transparent and 0xff for
    opaque.  As a special case it may return a single-entry byte array, which
    means all pixels have the same transparency.
  */
  abstract frame_map canvas/Canvas -> ByteArray

  /**
  Returns a canvas that is an alpha map for the given area that describes where
    the painting is visible.  This defines the edges of the content of this
    window.  For 2-color and 3-color textures this is a bitmap with 0 for
    transparent and 1 for opaque.  For true-color and gray-scale textures it is
    a bytemap with 0 for transparent and 0xff for opaque.  As a special case it
    may return a single-entry byte array, which means all pixels have the same
    transparency.
  */
  abstract painting_map canvas/Canvas -> ByteArray

  /**
  Draws the background on the canvas.  This represents the interior wall color
    and other interior objects will be draw on top of this.  Does not need to
    take the frame_map or painting_map into account: The canvas this function
    draws on will be composited using them afterwards.
  */
  abstract draw_background canvas/Canvas -> none

  /**
  Expected to draw the frame on the canvas.  This represents the window frame
    color.  Does not need to take the frame_map or painting_map into account: The
    return value from this function will be composited using them afterwards.
  */
  abstract draw_frame canvas

  constructor .inner_x_ .inner_y_ .inner_w_ .inner_h_ x/int y/int w/int h/int transform:
    super x y w h transform

  // After the textures under us have drawn themselves, we draw on top.
  write2_ canvas/Canvas:
    win_w := canvas.width_
    win_h := canvas.height_

    painting_opacity := painting_map canvas

    // If the window is 100% painting at these coordinates then we can draw the
    // elements of the window and no compositing is required.  We merely draw
    // the window background color and then draw the textures.
    if is_all_opaque painting_opacity:
      draw_background canvas
      elements_.do: it.write_ canvas
      return

    frame_opacity := frame_map canvas

    // The complicated case where we have to composite the tile from the wall,
    // the frame, and the painting_opacity.
    frame_canvas := null
    if not is_all_transparent frame_opacity:
      frame_canvas = canvas.create_similar
      frame_canvas.x_offset_ = canvas.x_offset_
      frame_canvas.y_offset_ = canvas.y_offset_
      draw_frame frame_canvas

    painting_canvas := canvas.create_similar
    painting_canvas.x_offset_ = canvas.x_offset_
    painting_canvas.y_offset_ = canvas.y_offset_
    draw_background painting_canvas
    elements_.do: it.write_ painting_canvas

    canvas.composit frame_opacity frame_canvas painting_opacity painting_canvas

/**
A rectangular window with a fixed width colored border.  The border is
  added to the visible area inside the window.
*/
abstract class SimpleWindow_ extends WindowTexture_:
  border_width_ := 0
  abstract make_alpha_map_ canvas
  abstract make_opaque_ x y w h map map_width

  constructor x y w h transform .border_width_:
    super x y w h  // Inner dimensions.
        // Actual dimensions.
        x - border_width_
        y - border_width_
        w + border_width_ * 2
        h + border_width_ * 2
        transform

  border_width -> int: return border_width_

  border_width= new_width/int -> none:
    if new_width != border_width_:
      border_width_ = new_width
      update_

  fix_bounding_box_ -> none:
    // The border is on the outside of the drawable area.
    x_ = inner_x_ - border_width_
    y_ = inner_y_ - border_width_
    w_ = inner_w_ + border_width_ * 2
    h_ = inner_h_ + border_width_ * 2

  // Draws 100% opacity for the frame shape, a filled rectangle.
  // (The frame is behind the painting, so this doesn't mean we only
  // see the frame.)
  frame_map canvas/Canvas:
    if border_width_ == 0: return WindowTexture_.ALL_TRANSPARENT  // The frame is not visible anywhere.
    // Transform inner dimensions not including border
    transform_.xywh inner_x_ inner_y_ inner_w_ inner_h_: | x y w2 h2 |
      x2 := x - canvas.x_offset_
      y2 := y - canvas.y_offset_
      if x2 <= 0 and y2 <= 0 and x2 + w2 >= canvas.width_ and y2 + h2 >= canvas.height_:
        // In the middle, the window content is 100% opaque and draw on top of the
        // frame.  There is no need to provide a frame alpha map, so for efficiency we
        // just return 0 which indicates the frame is 100% transparent.
        return WindowTexture_.ALL_TRANSPARENT
    // Transform outer dimensions including border.
    transform_.xywh x_ y_ w_ h_: | x y w2 h2 |
      x2 := x - canvas.x_offset_
      y2 := y - canvas.y_offset_
      // We need to create a bitmap to describe the frame's extent.
      transparency_map := make_alpha_map_ canvas
      // Declare the whole area inside the frame's extent opaque.  The window content will
      // draw on top of this as needed.
      make_opaque_ x2 y2 w2 h2 transparency_map canvas.width_
      return transparency_map
    unreachable

  // Draws 100% opacity for the window content, a filled rectangle.
  painting_map canvas/Canvas:
    transform_.xywh inner_x_ inner_y_ inner_w_ inner_h_: | x y w2 h2 |
      x2 := x - canvas.x_offset_
      y2 := y - canvas.y_offset_
      if x2 <= 0 and y2 <= 0 and x2 + w2 >= canvas.width_ and y2 + h2 >= canvas.height_:
        return WindowTexture_.ALL_OPAQUE  // The content is 100% opaque in the middle.
      // We need to create a bitmap to describe the content's extent.
      transparency_map := make_alpha_map_ canvas
      make_opaque_ x2 y2 w2 h2 transparency_map canvas.width_
      return transparency_map
    unreachable

/** A rectangular window with rounded corners.  */
abstract class RoundedCornerWindow_ extends WindowTexture_:
  corner_radius_ := 0
  opacities_ := null
  abstract make_alpha_map_ canvas/Canvas padding
  abstract make_opaque_ x y w h map map_width --frame/bool
  abstract set_opacity_ x y opacity map map_width --frame/bool

  constructor x y w h transform .corner_radius_:
    if corner_radius_ > TABLE_SIZE_: throw "OUT_OF_RANGE"
    super x y w h x y w h transform

  constructor.protected_ inner_x inner_y inner_w inner_h x y w h transform .corner_radius_:
    if corner_radius_ > TABLE_SIZE_: throw "OUT_OF_RANGE"
    super inner_x inner_y inner_w inner_h x y w h transform

  corner_radius -> int: return corner_radius_

  corner_radius= new_radius/int -> none:
    if not 0 <= new_radius <= TABLE_SIZE_: throw "OUT_OF_RANGE"
    if new_radius != corner_radius_:
      invalid_radius := max corner_radius_ new_radius
      corner_radius_ = new_radius
      if change_tracker:
        transform_.xywh x_ y_ w_ h_: | x2 y2 w2 h2 |
          change_tracker.child_invalidated x2                       y2                       invalid_radius invalid_radius
          change_tracker.child_invalidated x2 + w2 - invalid_radius y2                       invalid_radius invalid_radius
          change_tracker.child_invalidated x2                       y2 + h2 - invalid_radius invalid_radius invalid_radius
          change_tracker.child_invalidated x2 + w2 + invalid_radius y2 + h2 - invalid_radius invalid_radius invalid_radius

  fix_bounding_box_ -> none:
    // There's no border outside the drawable area.
    x_ = inner_x_
    y_ = inner_y_
    w_ = inner_w_
    h_ = inner_h_

  ensure_opacities_:
    if opacities_: return
    opacities_ = ByteArray corner_radius_ * corner_radius_
    downsample := TABLE_SIZE_ / corner_radius_  // For example 81 for a corner_radius of 3.
    steps := List corner_radius_:
      (it * TABLE_SIZE_) / corner_radius
    corner_radius_.repeat: | j |
      b := steps[j]
      corner_radius_.repeat: | i |
        a := steps[i]
        idx := j * corner_radius_ + i
        // Set the opacity according to whether the downsample x downsample
        // square is fully outside the circle, fully inside the circle or on
        // the edge.
        if QUARTER_CIRCLE_[b + downsample - 1] >= a + downsample:
          opacities_[idx] = 0xff  // Inside quarter circle.
        else if QUARTER_CIRCLE_[b] < a:
          opacities_[idx] = 0  // Outside quarter circle.
        else:
          // Edge of quarter circle.
          total := 0
          downsample.repeat: | small_y |
            extent := QUARTER_CIRCLE_[b + small_y]
            if extent >= a + downsample:
              total += downsample
            else if extent > a:
              total += extent - a
          opacities_[idx] = (0xff * total) / (downsample * downsample)

  frame_map canvas/Canvas:
    return WindowTexture_.ALL_TRANSPARENT  // No frame on these windows.

  static TABLE_SIZE_ ::= 256
  // The heights of a top-right quarter circle of radius [TABLE_SIZE_].
  static QUARTER_CIRCLE_ ::= create_quarter_circle_array_ TABLE_SIZE_

  static create_quarter_circle_array_ size:
    array := ByteArray size
    hypotenuse := (size - 1) * (size - 1)
    size.repeat:
      array[it] = (hypotenuse - it * it).sqrt.to_int
    return array

  // Draws 100% opacity for the window content, a filled rounded-corner rectangle.
  painting_map canvas/Canvas:
    transform_.xywh inner_x_ inner_y_ inner_w_ inner_h_: | x y w2 h2 |
      x2 := x - canvas.x_offset_
      y2 := y - canvas.y_offset_
      if x2 + corner_radius_ <= 0 and y2 + corner_radius_ <= 0 and x2 + w2 - corner_radius_ >= canvas.width_ and y2 + h2 - corner_radius_ >= canvas.height_:
        return WindowTexture_.ALL_OPAQUE  // The content is 100% opaque in the middle.
      // We need to create a bitmap to describe the content's extent.
      transparency_map := make_alpha_map_ canvas 0
      draw_rounded_corners_ transparency_map canvas.width_ x2 y2 w2 h2 --frame=false
      return transparency_map
    unreachable

  draw_rounded_corners_ transparency_map map_width x2 y2 w2 h2 --frame/bool:
    // Part 1 of a cross of opacity (the rounded rectangle minus its corners).
    make_opaque_ (x2 + corner_radius_) y2 (w2 - 2 * corner_radius_) h2 transparency_map map_width --frame=frame
    if corner_radius_ <= 0: return
    ensure_opacities_
    // Part 2 of the cross.
    make_opaque_ x2 (y2 + corner_radius_) w2 (h2 - 2 * corner_radius_) transparency_map map_width --frame=frame
    // The rounded corners:
    left := x2 + corner_radius_ - 1
    right := x2 + w2 - corner_radius_
    top := y2 + corner_radius_ - 1
    bottom := y2 + h2 - corner_radius_
    corner_radius_.repeat: | j |
      corner_radius_.repeat: | i |
        opacity := opacities_[i + j * corner_radius_]
        set_opacity_ (left - i) (top - j) opacity transparency_map map_width --frame=frame
        set_opacity_ (right + i) (top - j) opacity transparency_map map_width --frame=frame
        set_opacity_ (left - i) (bottom + j) opacity transparency_map map_width --frame=frame
        set_opacity_ (right + i) (bottom + j) opacity transparency_map map_width --frame=frame

/** A rectangular window with rounded corners and a drop shadow  */
abstract class DropShadowWindow_ extends RoundedCornerWindow_:
  blur_radius := 0
  drop_distance_x := 0
  drop_distance_y := 0

  constructor x y w h transform corner_radius .blur_radius .drop_distance_x .drop_distance_y:
    if not 0 <= blur_radius <= 6: throw "OUT_OF_RANGE"
    extension_left := blur_radius > drop_distance_x ?  blur_radius - drop_distance_x : 0
    extension_top := blur_radius > drop_distance_y ?  blur_radius - drop_distance_y : 0
    extension_right := blur_radius > -drop_distance_x ? blur_radius + drop_distance_x : 0
    extension_bottom := blur_radius > -drop_distance_y ? blur_radius + drop_distance_y : 0
    super.protected_
      x
      y
      w
      h
      x - extension_left
      y - extension_top
      w + extension_left + extension_right
      h + extension_top + extension_bottom
      transform
      corner_radius

  frame_map canvas/Canvas:
    win_x := canvas.x_offset_
    win_y := canvas.y_offset_

    // Transform inner dimensions excluding shadow to determine if the canvas
    // is wholly inside the window.
    transform_.xywh inner_x_ inner_y_ inner_w_ inner_h_: | x y w2 h2 |
      x2 := x - win_x
      y2 := y - win_y
      if x2 + corner_radius_ <= 0 and y2 + corner_radius_ <= 0 and x2 + w2 - corner_radius_ >= canvas.width_ and y2 + h2 - corner_radius_ >= canvas.height_:
        // In the middle, the window content is 100% opaque and draw on top of the
        // frame.  There is no need to provide a frame alpha map, so for efficiency we
        // just return 0 which indicates the frame is 100% transparent.
        return WindowTexture_.ALL_TRANSPARENT

    // Transform outer dimensions including border to determine if the canvas
    // is wholly outside the window and its shadow.
    transform_.xywh x_ y_ w_ h_: | x y w2 h2 |
      x2 := x - win_x
      y2 := y - win_y
      if x2 + w2 <= 0 or y2 + h2 <= 0 or x2 >= canvas.width_ or y2 >= canvas.height_:
        return WindowTexture_.ALL_TRANSPARENT  // The frame is not opaque outside the shadow

    // Create a bitmap to describe the frame's extent.  It needs to be padded
    // relative to the canvas size so we can use the Gaussian blur.
    transparency_map := make_alpha_map_ canvas blur_radius * 2
    map_width := canvas.width_ + blur_radius * 2

    transform_.xywh (inner_x_ + drop_distance_x) (inner_y_ + drop_distance_y) inner_w_ inner_h_: | x y w2 h2 |
      x2 := x + blur_radius - win_x
      y2 := y + blur_radius - win_y

      // Transform the unblurred dimensions of the shadow so we can plot that on the
      // transparency map.
      draw_rounded_corners_ transparency_map map_width x2 y2 w2 h2 --frame=true

    if blur_radius == 0: return transparency_map

    // Blur the shadow.
    bytemap_blur transparency_map map_width blur_radius

    // Crop off the extra that was added to blur.
    transparency_map_unpadded := make_alpha_map_ canvas 0
    canvas.height_.repeat:
      source_index := (it + blur_radius) * map_width + blur_radius
      transparency_map_unpadded.replace (it*canvas.width_) transparency_map source_index source_index + canvas.width_
    return transparency_map_unpadded
abstract class BitmapTextureBase_ extends SizedTexture:
  w := 0
  h := 0
  bytes_per_line_ /int

  constructor x/int y/int .w .h transform/Transform:
    bytes_per_line_ = (w + 7) >> 3  // Divide by 8, rounding up.
    super x y w h transform

  index_and_mask_ x y [block]:
    if not 0 <= x < w: throw "OUT_OF_RANGE"
    if not 0 <= y < h: throw "OUT_OF_RANGE"
    index := (x >> 3) + (y * bytes_per_line_)
    bit := 0x80 >> (x & 7)
    block.call index bit

  // After the textures under us have drawn themselves, we draw on top.
  write2_ canvas/Canvas:
    if w == 0 or h == 0: return
    x2 := transform_.x x_ y_
    y2 := transform_.y x_ y_
    draw_
      x2 - canvas.x_offset_
      y2 - canvas.y_offset_
      transform_.orientation_
      canvas

  abstract draw_ bx by orientation canvas

abstract class BitmapTexture_ extends BitmapTextureBase_:
  bytes_ /ByteArray? ::= null

  constructor x/int y/int w/int h/int transform/Transform:
    bytes_per_line := (w + 7) >> 3  // Divide by 8, rounding up.
    bytes_ = ByteArray h * bytes_per_line
    super x y w h transform

  constructor.no_allocate_ x/int y/int w/int h/int transform/Transform:
    super x y w h transform

  pixel_is_set x/int y/int -> bool:
    index_and_mask_ x y: | index bit |
      return (bytes_[index] & bit) != 0
    unreachable

  set_pixel x/int y/int -> none:
    index_and_mask_ x y: | index bit |
      bytes_[index] |= bit

  clear_pixel x/int y/int -> none:
    index_and_mask_ x y: | index bit |
      bytes_[index] &= 0xff ^ bit

  set_all_pixels -> none:
    bitmap_zap bytes_ 1

  clear_all_pixels -> none:
    bitmap_zap bytes_ 0

abstract class PixmapTexture_ extends SizedTexture:
  w /int
  h /int

  constructor x/int y/int .w .h transform/Transform:
    super x y w h transform

  // After the textures under us have drawn themselves, we draw on top.
  write2_ canvas/Canvas:
    if w == 0 or h == 0: return
    x2 := transform_.x x_ y_
    y2 := transform_.y x_ y_
    draw_
      x2 - canvas.x_offset_
      y2 - canvas.y_offset_
      transform_.orientation_
      canvas

  abstract draw_ bx by orientation canvas

class PbmParser_:
  static INVALID_PBM_ ::= "INVALID PBM"

  bytes_ /ByteArray
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
