// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the TESTS_LICENSE file.

import expect show *

import pixel_display.common show Canvas
import pixel_display.element show Element
import pixel_display.style show *

toit_doc_examples_test:
  style := Style
      --type-map={
          "button": Style --color=0xffffff --background=0x606060,
      }
      --class-map={
          "box": Style --border-color=0xff0000,
      }
      --id-map={
          "fish": Style --color=0x00ff00,
      }

  style2 := Style
      --class-map={
          "box": Style
              --type-map={
                  "p": Style --color=0xffffff,
              },
      }

  FISH-OR-FOWL-STYLE ::= Style --color=0xffffff --background=0x606060

  style3 := Style
      --class-map={
          "fish": FISH-OR-FOWL-STYLE,
          "fowl": FISH-OR-FOWL-STYLE,
      }

  style4 := Style
      --class-map={
          "fish-or-fowl": Style --color=0xffffff --background=0x606060,
      }

element_tree_test:

abstract class TestElement extends Element:
  constructor --style/Style?=null --element_class/string?=null --classes/List?=null --id/string?=null children/List?=null:
    super --style=style --element_class=element_class --classes=classes --id=id children

  invalidate -> none:
    unreachable

  draw canvas/Canvas -> none:
    unreachable

  min_w -> int:
    unreachable

  min_h -> int:
    unreachable

class Square extends TestElement:
  type -> string: return "square"
  w/int? := null
  h/int? := null

  constructor --style/Style?=null --element_class/string?=null --classes/List?=null --id/string?=null:
    super --style=style --element_class=element_class --classes=classes --id=id

  set_attribute key/string value -> none:
    if key == "width":
      w = value
    else if key == "height":
      h = value

main:
  toit_doc_examples_test
  element_tree_test
