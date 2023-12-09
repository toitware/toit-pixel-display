// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// TODO: Absorb this into pixel_display.toit now that textures are gone.

import font show Font
import bitmap show ORIENTATION-0 ORIENTATION-90 ORIENTATION-180 ORIENTATION-270

import .element show Element
import .style

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
      if right < 0 or bottom < 0 or x2 >= width_ or y2 >= height_: return DISJOINT
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
