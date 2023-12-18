// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests for Label that the change box is smaller when we only
// change part of the text.

import bitmap show *
import expect show *
import font show *
import pixel-display show *
import pixel-display.gradient show *
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := TrueColorPngVisualizer 240 220 args[0] --outline=0x4040ff
  display := PixelDisplay.true-color driver
  display.background = 0x808080

  gradient-elements := []

  16.repeat:
    angle := it * 45
    w := ?
    h := ?
    if it < 8:
      w = 23
      h = 31
    else:
      w = 31
      h = 23
    x := 20 + (it % 4) * 50
    y := 20 + (it / 4) * 50
    gradient := GradientBackground --angle=angle --specifiers=[
        GradientSpecifier --color=0xff0000 0,
        GradientSpecifier --color=0x00ff00 100,
        ]
    gradient-element := Div --x=x --y=y --w=w --h=h --background=gradient
    display.add gradient-element
    gradient-elements.add gradient-element
    dot1 := Div --x=(x - 1) --y=(y - 1) --w=1 --h=1 --background=0xffffff
    display.add dot1
    dot2 := Div --x=(x + w) --y=(y + h) --w=1 --h=1 --background=0xffffff
    display.add dot2
    dot3 := Div --x=(x - 1) --y=(y + h) --w=1 --h=1 --background=0xffffff
    display.add dot3
    dot4 := Div --x=(x + w) --y=(y - 1) --w=1 --h=1 --background=0xffffff
    display.add dot4

  display.draw

  // Rotate all gradient-elements 30 degrees.
  angle := 30
  gradient-elements.do:
    it.background = GradientBackground --angle=angle --specifiers=it.background.specifiers
    angle = (angle + 45) % 360

  display.draw

  driver.write-png
