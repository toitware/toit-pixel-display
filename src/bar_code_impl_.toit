// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

EAN_13_QUIET_ZONE_WIDTH ::= 9
EAN_13_START_WIDTH ::= 3
EAN_13_MIDDLE_WIDTH ::= 5
EAN_13_DIGIT_WIDTH ::= 7
EAN_13_BOTTOM_SPACE ::= 5
EAN_13_WIDTH ::= 2 * EAN_13_QUIET_ZONE_WIDTH + 2 * EAN_13_START_WIDTH + EAN_13_MIDDLE_WIDTH + 12 * EAN_13_DIGIT_WIDTH
EAN_13_HEIGHT ::= 83
// Encoding of L digits.  R digits are the bitwise-not of this and G digits are
// the R digits in reverse order.
EAN_13_L_CODES_ ::= [0x0d, 0x19, 0x13, 0x3d, 0x23, 0x31, 0x2f, 0x3b, 0x37, 0x0b]
EAN_13_G_CODES_ ::= [0x27, 0x33, 0x1b, 0x21, 0x1d, 0x39, 0x05, 0x11, 0x09, 0x17]
// Encoding of the first (invisible) digit.
EAN_13_FIRST_CODES_ ::= [0x00, 0x0b, 0x0d, 0x0e, 0x13, 0x19, 0x1c, 0x15, 0x16, 0x1a]

