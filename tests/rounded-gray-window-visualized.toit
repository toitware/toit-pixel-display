// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import bitmap show *
import font show Font
import pixel-display show *
import pixel-display.gradient show *
import .png-visualizer

main args:
  sans10 := Font.get "sans10"

  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  driver := GrayScalePngVisualizer 240 160 args[0] --outline=0x10
  display := PixelDisplay.gray-scale driver
  display.background = 160

  background-gradient := GradientBackground --angle=180
      --specifiers=[
          GradientSpecifier --color=0x20 10,
          GradientSpecifier --color=0x60 90,
      ]
  background-gradient-element := Div --x=0 --y=0 --w=240 --h=160 --background=background-gradient
  display.add background-gradient-element

  win := Div.clipping --x=30 --y=30 --w=180 --h=100 --border=(RoundedCornerBorder --radius=15)
  display.add win

  gradient := GradientBackground --angle=0
      --specifiers=[
          GradientSpecifier --color=0x90 10,
          GradientSpecifier --color=0xe0 90,
      ]
  gradient-element := Div --x=0 --y=0 --w=180 --h=100 --background=gradient
  win.add gradient-element

  text := Label --x=90 --y=55 --text="Hello, World!" --font=sans10 --color=0x10
  win.add text

  display.draw

  text.move-to 120 65

  display.draw

  // Window-relative coordinates.
  text.move-to -10 7

  display.draw

  driver.write-png
