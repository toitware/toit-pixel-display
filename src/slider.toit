// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .element
import .element show Element
import .pixel-display
import .style

/**
A vertical or horizontal slider that can indicate a value between a minimum and
  a maximum.
You can provide a background to draw when the slider is above a certain level,
  and a different one for when the slider is below that level.  If either
  background is omitted the slider is transparent in that section.
Currently no thumb is drawn, so the indication is the boundary between
  the two backgrounds.
*/
class Slider extends CustomElement:
  value_/num? := ?
  min_/num? := ?
  max_/num? := ?
  background-lo_ := ?
  background-hi_ := ?
  horizontal_ := ?

  thumb-min_/int
  thumb-max_/int?
  boundary_/int := 0

  type -> string: return "slider"

  /**
  Constructs a new slider element.
  You can provide a background to draw when the slider is above a certain level
    ($background-hi), and a different one for when the slider is below that
    level ($background-lo).  If either background is omitted the slider is
    transparent in that section.
  The initial level of the slider is given by $value, and it should be between
    the values of $min and $max, which default to 0 and 100, respectively.
  The boundary between the two backgrounds is drawn in a linear position
    between $thumb-min and $thumb-max, which default to 0, and height or width
    of the element, respectively.
  The slider supports the extra $Style keys "background-lo", "background-hi",
    "horizontal", "min", "max", and "value".
  See also $Element.constructor.
  */
  constructor
      --x/int?=null
      --y/int?=null
      --w/int?=null
      --h/int?=null
      --style/Style?=null
      --classes/List?=null
      --id/string?=null
      --border/Border?=null
      --background-hi=null
      --background-lo=null
      --value/num?=null
      --min/num?=0
      --max/num?=100
      --thumb-min/int=0
      --thumb-max/int?=null
      --horizontal/bool=false:
    value_ = value
    min_ = min
    max_ = max
    background-lo_ = background-lo
    background-hi_ = background-hi
    thumb-min_ = thumb-min
    thumb-max_ = thumb-max
    horizontal_ = horizontal
    super
        --x=x
        --y=y
        --w=w
        --h=h
        --style = style
        --classes = classes
        --id = id
        --border = border
    recalculate_

  thumb-max: return thumb-max_ or (horizontal_ ? w : h)

  recalculate_ -> none:
    if not (min_ and max_ and value_ and h): return
    if (min_ == max_): return
    value_ = max value_ min_
    value_ = min value_ max_
    old-boundary := boundary_
    boundary_ = ((value_ - min_).to-float / (max_ - min_) * (thumb-max - thumb-min_) + 0.1).to-int + thumb-min_
    if boundary_ != old-boundary:
      top := max old-boundary boundary_
      bottom := min old-boundary boundary_
      if horizontal_:
        invalidate
            --x = x + w - top
            --w = top - bottom
      else:
        invalidate
            --y = y + h - top
            --h = top - bottom

  h= value/int -> none:
    if value != h:
      invalidate
      h_ = value
      recalculate_
      invalidate

  w= value/int -> none:
    if value != w:
      invalidate
      w_ = value
      recalculate_
      invalidate

  custom-draw canvas/Canvas -> none:
    blend := false
    if background-lo_ and boundary_ > thumb-min_:
      analysis := ?
      if horizontal_:
        analysis = canvas.bounds-analysis 0 0 (w - boundary_) h
      else:
        analysis = canvas.bounds-analysis 0 0 w (h - boundary_)
      if analysis != Canvas.DISJOINT:
        if analysis == Canvas.CANVAS-IN-AREA or analysis == Canvas.COINCIDENT:
          background-lo_.draw canvas 0 0 w h --autoclipped
        else:
          blend = true
    if background-hi_ and boundary_ < thumb-max:
      analysis := ?
      if horizontal_:
        analysis = canvas.bounds-analysis (w - boundary_) 0 w h
      else:
        analysis = canvas.bounds-analysis 0 (h - boundary_) w h
      if analysis != Canvas.DISJOINT:
        if analysis == Canvas.CANVAS-IN-AREA or analysis == Canvas.COINCIDENT:
          background-hi_.draw canvas 0 0 w h --autoclipped
        else:
          blend = true
    if not blend: return

    lo-alpha := background-lo_ ? canvas.make-alpha-map : Canvas.ALL-TRANSPARENT
    hi-alpha := background-hi_ ? canvas.make-alpha-map : Canvas.ALL-TRANSPARENT
    lo := canvas.create-similar
    hi := canvas.create-similar

    if background-lo_:
      if horizontal_:
        lo-alpha.rectangle 0 0 --w=(w - boundary_) --h=h --color=0xff
      else:
        lo-alpha.rectangle 0 0 --w=w --h=(h - boundary_) --color=0xff
      Background.draw background-lo_ lo 0 0 w h --autoclipped
    if background-hi_:
      if horizontal_:
        hi-alpha.rectangle (w - boundary_) 0 --w=boundary_ --h=h --color=0xff
      else:
        hi-alpha.rectangle 0 (h - boundary_) --w=w --h=boundary_ --color=0xff
      Background.draw background-hi_ hi 0 0 w h --autoclipped

    canvas.composit hi-alpha hi lo-alpha lo

  set-attribute_ key/string value -> none:
    if key == "value":
      value_ = value
      recalculate_
    else if key == "min":
      min_ = value
      recalculate_
    else if key == "max":
      max_ = value
      recalculate_
    else if key == "background-lo":
      background-lo_ = value
      invalidate
    else if key == "background-hi":
      background-hi_ = value
      invalidate
    else if key == "horizontal":
      invalidate
      horizontal_ = value
      recalculate_
      invalidate
    else:
      super key value

  value= value/num -> none:
    if value != value_:
      value_ = value
      recalculate_
