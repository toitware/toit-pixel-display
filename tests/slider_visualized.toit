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
import pixel_display.gradient show *
import pixel_display.style show *
import .png_visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  WIDTH ::= 220
  HEIGHT ::= 140
  driver := TrueColorPngVisualizer WIDTH HEIGHT args[0] --outline=0x4040ff
  display := TrueColorPixelDisplay driver
  display.background = 0x808080

  heat := GradientBackground --angle=0 --specifiers=[
      GradientSpecifier --color=0xc0c000 0,
      GradientSpecifier --color=0xff8000 100,
      ]

  cold := GradientBackground --angle=90 --specifiers=[
      GradientSpecifier --color=0xa0a0a0 0,
      GradientSpecifier --color=0x404040 10,
      GradientSpecifier --color=0x404040 90,
      GradientSpecifier --color=0xa0a0a0 100,
      ]

  sliders := List 5:
      VerticalSlider --x=(20 + 40 * it) --y=10 --value=(10 + it * 20)
  labels := List 5:
      Label --x=(30 + 40 * it) --y=125 --label="$(%c 'A' + it)" --alignment=ALIGN_CENTER

  content := Div --x=0 --y=0 --w=WIDTH --h=HEIGHT --background=0x202020 (sliders + labels)

  display.add content

  sans10 := Font.get "sans10"

  style := Style
      --type-map={
          "vertical-slider": Style {
              "background-hi": heat,
              "background-lo": cold,
              "width": 20,
              "height": 100,
          },
          "label": Style --font=sans10 --color=0xffffff,
      }

  content.set_styles [style]

  display.draw
  driver.write_png

  sliders[0].value = 50
  sliders[1].value = 70
  sliders[2].value = 10
  sliders[3].value = 90
  sliders[4].value = 30

  display.draw
  driver.write_png
