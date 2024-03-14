// Copyright (C) 2024 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests that using the same gradient on two elements with different
// sizes works as expected.  A new GradientRendering is used for the
// second element.

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
  driver := TrueColorPngVisualizer 192 120 args[0] --outline=0x4040ff
  display := PixelDisplay.true-color driver
  display.background = 0x808080

  border := SolidBorder --color=0x000000 --width=3

  gradient := GradientBackground --angle=30 --specifiers=[
      GradientSpecifier --color=0xffff00 10,
      GradientSpecifier --color=0xffc000 50,
      GradientSpecifier --color=0x808000 90,
      ]
  gradient-element := Div --x=10 --y=10 --w=50 --h=50 --background=gradient --border=border
  display.add gradient-element

  gradient-2-element := Div --x=70 --y=10 --w=100 --h=100 --background=gradient --border=border
  display.add gradient-2-element

  display.draw

  driver.write-png
