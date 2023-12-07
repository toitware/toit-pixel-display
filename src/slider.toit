// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .common
import .element
import .style

/**
A vertical slider that can indicate a value between a minimum and a maxiumum.
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
  background_lo_ := ?
  background_hi_ := ?
  horizontal_ := ?

  thumb_min_/int
  thumb_max_/int?
  boundary_/int := 0

  type -> string: return "vertical-slider"

  constructor --x/int?=null --y/int?=null --w/int?=null --h/int?=null --background-hi=null --background-lo=null --value/num?=null --min/num?=0 --max/num?=100 --thumb_min/int=0 --thumb_max/int?=null --horizontal/bool=false:
    value_ = value
    min_ = min
    max_ = max
    background_lo_ = background_lo
    background_hi_ = background_hi
    thumb_min_ = thumb_min
    thumb_max_ = thumb_max
    horizontal_ = horizontal
    super --x=x --y=y --w=w --h=h
    recalculate_

  thumb_max: return thumb_max_ or (horizontal_ ? w : h)

  recalculate_ -> none:
    if not (min_ and max_ and value_ and h): return
    if (min_ == max_): return
    value_ = max value_ min_
    value_ = min value_ max_
    old_boundary := boundary_
    boundary_ = ((value_ - min_).to_float / (max_ - min_) * (thumb_max - thumb_min_) + 0.1).to_int + thumb_min_
    if boundary_ != old_boundary:
      top := max old_boundary boundary_
      bottom := min old_boundary boundary_
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

  custom_draw canvas/Canvas -> none:
    blend := false
    if background_lo_ and boundary_ > thumb_min_:
      analysis := ?
      if horizontal_:
        analysis = canvas.bounds_analysis 0 0 (w - boundary_) h
      else:
        analysis = canvas.bounds_analysis 0 0 w (h - boundary_)
      if analysis != Canvas.DISJOINT:
        if analysis == Canvas.CANVAS_IN_AREA or analysis == Canvas.COINCIDENT:
          background_lo_.draw canvas 0 0 w h --autocropped
        else:
          blend = true
    if background_hi_ and boundary_ < thumb_max:
      analysis := ?
      if horizontal_:
        analysis = canvas.bounds_analysis (w - boundary_) 0 w h
      else:
        analysis = canvas.bounds_analysis 0 (h - boundary_) w h
      if analysis != Canvas.DISJOINT:
        if analysis == Canvas.CANVAS_IN_AREA or analysis == Canvas.COINCIDENT:
          background_hi_.draw canvas 0 0 w h --autocropped
        else:
          blend = true
    if not blend: return

    lo_alpha := background_lo_ ? canvas.make_alpha_map : Canvas.ALL_TRANSPARENT
    hi_alpha := background_hi_ ? canvas.make_alpha_map : Canvas.ALL_TRANSPARENT
    lo := canvas.create_similar
    hi := canvas.create_similar

    if background_lo_:
      if horizontal_:
        lo_alpha.rectangle 0 0 --w=(w - boundary_) --h=h --color=0xff
      else:
        lo_alpha.rectangle 0 0 --w=w --h=(h - boundary_) --color=0xff
      Background.draw background_lo_ lo 0 0 w h --autocropped
    if background_hi_:
      if horizontal_:
        hi_alpha.rectangle (w - boundary_) 0 --w=boundary_ --h=h --color=0xff
      else:
        hi_alpha.rectangle 0 (h - boundary_) --w=w --h=boundary_ --color=0xff
      Background.draw background_hi_ hi 0 0 w h --autocropped

    canvas.composit hi_alpha hi lo_alpha lo

  set_attribute key/string value -> none:
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
      background_lo_ = value
      invalidate
    else if key == "background-hi":
      background_hi_ = value
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
