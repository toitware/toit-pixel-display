// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests for Label that the change box is smaller when we only
// change part of the text.

import bitmap show *
import expect show *
import font show *
import pixel_display show *
import pixel_display.element show *
import .png_visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := TrueColorPngVisualizer 240 220 args[0] --outline=0x4040ff
  display := TrueColorPixelDisplay driver
  display.background = 0x808080

  gradient_elements := []

  16.repeat:
    angle := it * 45
    w := ?
    h := ?
    if it < 8:
      w = 20
      h = 30
    else:
      w = 30
      h = 20
    x := 20 + (it % 4) * 50
    y := 20 + (it / 4) * 50
    gradient := Gradient --angle=angle --specifiers=[
        GradientSpecifier --color=0xff0000 0,
        GradientSpecifier --color=0x00ff00 100,
        ]
    gradient_element := GradientElement --x=x --y=y --w=w --h=h --gradient=gradient
    display.add gradient_element
    gradient_elements.add gradient_element
    dot1 := Div --x=(x - 1) --y=(y - 1) --w=1 --h=1 --background=0xffffff
    display.add dot1
    dot2 := Div --x=(x + w) --y=(y + h) --w=1 --h=1 --background=0xffffff
    display.add dot2
    dot3 := Div --x=(x - 1) --y=(y + h) --w=1 --h=1 --background=0xffffff
    display.add dot3
    dot4 := Div --x=(x + w) --y=(y - 1) --w=1 --h=1 --background=0xffffff
    display.add dot4

  display.draw

  // Rotate all gradient_elements 30 degrees.
  angle := 30
  gradient_elements.do:
    it.gradient = Gradient --angle=angle --specifiers=it.gradient.specifiers
    angle = (angle + 45) % 360

  display.draw

  driver.write_png
