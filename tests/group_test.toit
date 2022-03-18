// Copyright (C) 2022 Toitware ApS.  All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import pixel_display show *
import pixel_display.texture show *
import pixel_display.true_color show *

class TestDriver extends AbstractDriver:
  width ::= 128
  height ::= 64
  flags ::= FLAG_TRUE_COLOR | FLAG_PARTIAL_UPDATES

main:
  driver := TestDriver
  display := TrueColorPixelDisplay driver
  display.background = 1

  group := TextureGroup
  tex := FilledRectangle 0 0 0 1 1 display.landscape
  // Make sure we can add a texture when the group doesn't have a window yet.
  group.add tex

  // Make sure we can add group as a texture.
  display.add group
