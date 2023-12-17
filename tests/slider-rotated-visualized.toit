// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

// Tests some simple vertical sliders where there is a movable boundary between
// two different backgrounds.

import bitmap show *
import expect show *
import font show *
import pixel-display show *
import pixel-display.gradient show *
import pixel-display.slider show *
import .png-visualizer

main args:
  if args.size != 1:
    print "Usage: script.toit png-basename"
    exit 1
  WIDTH ::= 220
  HEIGHT ::= 140
  driver := TrueColorPngVisualizer HEIGHT WIDTH args[0] --outline=0x4040ff
  display := PixelDisplay.true-color driver --no-portrait
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
      Slider --x=(20 + 40 * it) --y=10 --value=0
  labels := List 5:
      Label --x=(30 + 40 * it) --y=125 --alignment=ALIGN-CENTER

  set [10, 30, 50, 70, 90] sliders labels

  content := Div --x=0 --y=0 --w=WIDTH --h=HEIGHT --background=0x202020 (sliders + labels)

  display.add content

  sans10 := Font.get "sans10"

  style := Style
      --type-map={
          "slider": Style --w=20 --h=100 {
              "background-hi": heat,
              "background-lo": cold,
          },
          "label": Style --font=sans10 --color=0xffffff,
      }

  content.set-styles [style]
  display.draw

  set [50, 70, 10, 90, 30] sliders labels
  display.draw

  content.set-styles [Style --type-map={"slider": Style {"inverted": true}}]
  display.draw

  set [100, 0, 45, 90, 30] sliders labels
  display.draw

  driver.write-png

set values/List sliders/List labels/List:
  i := 0
  values.do:
    sliders[i].value = it
    labels[i].label = it.stringify
    i++
