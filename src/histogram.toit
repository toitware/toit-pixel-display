import bitmap show *
import .texture show *
import .true_color as true_color

abstract class Histogram extends SizedTexture:
  values_ := ?
  fullness_ := 0
  scale_ := 0
  h_ := 0

  // All samples are multiplied by the scale.
  // The histogram is plotted in the color with one pixel of width per sample.
  // When you have added <width> samples, the histogram starts scrolling.
  constructor x/int y/int width/int .h_/int transform/Transform .scale_/num:
    values_ = List width 0
    super x y width h_ transform

  add sample -> none:
    if values_.size == 0: return
    if fullness_ == values_.size:
      update_: | x |
        (x + 1 < values_.size) ? values_[x + 1] : sample
    else:
      coord := sample_to_coordinate_ sample
      invalidate (x + fullness_) (y + coord) 1 (h_ - coord)
      values_[fullness_++] = sample

  update_ [new_value_block] -> none:
    List.chunk_up 0 values_.size 16: | from to size |
      first_inval := 10000000
      last_inval := -1
      top_inval := 10000000
      bottom_inval := -1
      for x := from; x < to; x++:
        coord_old := sample_to_coordinate_ values_[x]
        new := new_value_block.call x
        values_[x] = new
        coord_new := sample_to_coordinate_ new
        if coord_old != coord_new:
          top_inval = min top_inval (min coord_old coord_new)
          bottom_inval = max bottom_inval (max coord_old coord_new)
          first_inval = min first_inval x
          last_inval = max last_inval x
      if first_inval <= last_inval and top_inval <= bottom_inval:
        invalidate (x + first_inval) (y + top_inval) (last_inval + 1 - first_inval) (bottom_inval + 1 - top_inval)

  /**
  Adjust all samples up or down by a fixed amount.  This allows you
    to change the Y axis without redrawing the whole histogram.
  */
  adjust_all adjustment/int -> none:
    if adjustment == 0: return
    update_: | x | values_[x] + adjustment

  sample_to_coordinate_ sample:
    scaled := (scale_ * sample).to_int
    clamped := max 0 (min h_ scaled)
    return h_ - clamped

  write2_ win_x win_y canvas:
    List.chunk_up 0 fullness_ 16: | from to size |
      worth_plotting := false
      get_transform.xywh (x + from) y size h_: | x2 y2 w2 h2 |
        if w2 > 0 and h2 > 0 and x2 - win_x + w2 > 0 and x2 - win_x < canvas.width:
          worth_plotting = true
      if worth_plotting:
        for hx := from; hx < to; hx++:
          wx := x + hx
          coord := y + (sample_to_coordinate_ values_[hx])
          wy1 := coord
          wy2 := y + h_
          get_transform.xywh wx wy1 1 (wy2 - wy1): | x2 y2 w2 h2 |
            if w2 > 0 and h2 > 0:
              draw_rectangle
                x2 - win_x
                y2 - win_y
                w2
                h2
                canvas

  abstract draw_rectangle x y w h canvas

class TwoColorHistogram extends Histogram:
  color_ := 0

  constructor x/int y/int width/int height/int transform/Transform scale/num .color_:
    super x y width height transform scale

  draw_rectangle x y w h canvas:
    bitmap_rectangle
      x
      y
      color_
      w
      h
      canvas.pixels_
      canvas.width

class TwoBitColorHistogram_ extends Histogram:
  color_ := 0

  constructor x/int y/int width/int height/int transform/Transform scale/num .color_:
    super x y width height transform scale

  draw_rectangle x y w h canvas:
    bitmap_rectangle
      x
      y
      color_ & 1
      w
      h
      canvas.plane_0_
      canvas.width
    bitmap_rectangle
      x
      y
      (color_ & 2) >> 1
      w
      h
      canvas.plane_1_
      canvas.width

class ThreeColorHistogram extends TwoBitColorHistogram_:
  constructor x/int y/int width/int height/int transform/Transform scale/num color/int:
    assert: color != 3
    super x y width height transform scale color

class FourGrayHistogram extends TwoBitColorHistogram_:
  constructor x/int y/int width/int height/int transform/Transform scale/num color/int:
    super x y width height transform scale color

class TrueColorHistogram extends Histogram:
  color_ := 0

  constructor x/int y/int width/int height/int transform/Transform scale/num .color_:
    super x y width height transform scale

  draw_rectangle x y w h canvas:
    c := color_
    if bytemap_rectangle x y (true_color.red_component c)   w h canvas.red_   canvas.width:
       bytemap_rectangle x y (true_color.green_component c) w h canvas.green_ canvas.width
       bytemap_rectangle x y (true_color.blue_component c)  w h canvas.blue_  canvas.width
