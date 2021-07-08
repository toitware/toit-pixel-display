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
      first_inval := 10000000
      last_inval := -1
      top_inval := 10000000
      bottom_inval := -1
      (values_.size).repeat:
        coord_old := sample_to_coordinate_ values_[it]
        new := (it + 1 < values_.size) ? values_[it + 1] : sample
        values_[it] = new
        coord_new := sample_to_coordinate_ new
        if coord_old != coord_new:
          top_inval = min top_inval (min coord_old coord_new)
          bottom_inval = max bottom_inval (max coord_old coord_new)
          first_inval = min first_inval it
          last_inval = max last_inval it
      if first_inval <= last_inval and top_inval <= bottom_inval:
        invalidate (x + first_inval) (y + top_inval) (last_inval + 1 - first_inval) (bottom_inval + 1 - top_inval)
    else:
      coord := sample_to_coordinate_ sample
      invalidate (x + fullness_) (y + coord) 1 (h_ - coord)
      values_[fullness_++] = sample

  sample_to_coordinate_ sample:
    scaled := (scale_ * sample).to_int
    clamped := max 0 (min h_ scaled)
    return h_ - clamped

  write2_ win_x win_y canvas:
    fullness_.repeat:
      wx := x + it
      coord := y + (sample_to_coordinate_ values_[it])
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
