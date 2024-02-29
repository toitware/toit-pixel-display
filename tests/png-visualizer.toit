// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import binary show BIG-ENDIAN byte-swap-32
import bitmap show *
import bytes show Buffer
import crypto.crc show *
import host.file
import monitor show Latch
import pixel-display show *
import pixel-display.png
import png-tools.png-writer
import png-tools.png-reader show *
import zlib

class TwoColorPngVisualizer extends PngVisualizingDriver_:
  flags ::= FLAG-2-COLOR | FLAG-PARTIAL-UPDATES
  constructor width height basename --outline/int?=null: super width height basename --outline=outline
  width-to-byte-width w: return (round-up w 8) >> 3
  x-rounding := 8  // 8 pixels per byte in PNG.
  y-rounding := 8  // 8 pixels per byte in canvas.

class ThreeColorPngVisualizer extends PngVisualizingDriver_:
  flags ::= FLAG-3-COLOR | FLAG-PARTIAL-UPDATES
  constructor width height basename --outline/int?=null: super width height basename --outline=outline
  width-to-byte-width w: return (round-up w 4) >> 2
  x-rounding := 4  // 4 pixels per byte.
  y-rounding := 8  // 8 pixels per byte in canvas.

class FourGrayPngVisualizer extends PngVisualizingDriver_:
  flags ::= FLAG-4-COLOR | FLAG-PARTIAL-UPDATES
  constructor width height basename --outline/int?=null: super width height basename --outline=outline
  width-to-byte-width w: return (round-up w 4) >> 2
  x-rounding := 4  // 4 pixels per byte.
  y-rounding := 8  // 8 pixels per byte in canvas.

class TrueColorPngVisualizer extends PngVisualizingDriver_:
  flags ::= FLAG-TRUE-COLOR | FLAG-PARTIAL-UPDATES
  constructor width height basename --outline/int?=null: super width height basename --outline=outline
  width-to-byte-width w: return w * 3
  x-rounding := 1
  y-rounding := 1

class GrayScalePngVisualizer extends PngVisualizingDriver_:
  flags ::= FLAG-GRAY-SCALE | FLAG-PARTIAL-UPDATES
  constructor width height basename --outline/int?=null: super width height basename --outline=outline
  width-to-byte-width w: return w
  x-rounding := 1
  y-rounding := 1

class SeveralColorPngVisualizer extends PngVisualizingDriver_:
  flags ::= FLAG-SEVERAL-COLOR | FLAG-PARTIAL-UPDATES
  constructor width height basename --outline/int?=null: super width height basename --outline=outline
  width-to-byte-width w: return w
  x-rounding := 1
  y-rounding := 1

abstract class PngVisualizingDriver_ extends AbstractDriver:
  width /int ::= ?
  height /int ::= ?
  width_ := 0  // Rounded up depending on the bit depth.
  height_ := 0  // Rounded up depending on the bit depth.
  outline-buffer_ /ByteArray? := null
  buffer_ /ByteArray := #[]
  temp-buffer_/ByteArray := #[]
  temps_ := List 8
  // Optional outliner to see update locations.
  outline/int? := null
  // How many bytes make up one strip of image data.
  abstract width-to-byte-width w/int -> int

  static INVERT_ := ByteArray 0x100: 0xff - it

  constructor .width .height basename/string --.outline/int?=null:
    png-basename_ = basename
    width_ = round-up width x-rounding
    height_ = round-up height y-rounding
    buffer_ = ByteArray
        (width-to-byte-width width_) * height_
    if outline:
      outline-buffer_ = buffer_.copy

  snapshots_ := []

  draw-true-color left/int top/int right/int bottom/int red/ByteArray green/ByteArray blue/ByteArray -> none:
    patch-width := right - left
    top-left := min buffer_.size (3 * (left + width_ * top))

    if outline:
      red2 := red.copy
      green2 := green.copy
      blue2 := blue.copy
      draw-byte-outline_ (outline >> 16) red2 patch-width
      draw-byte-outline_ ((outline >> 16) & 0xff) green2 patch-width
      draw-byte-outline_ (outline & 0xff) blue2 patch-width

      // Pack 3 pixels in three consecutive bytes.  Since we receive the data in
      // three one-byte-per-pixel buffers we have to shuffle the bytes.
      blit red2   outline-buffer_[top-left..]     patch-width --destination-pixel-stride=3 --destination-line-stride=(width_ * 3)
      blit green2 outline-buffer_[top-left + 1..] patch-width --destination-pixel-stride=3 --destination-line-stride=(width_ * 3)
      blit blue2  outline-buffer_[top-left + 2..] patch-width --destination-pixel-stride=3 --destination-line-stride=(width_ * 3)

    // Pack 3 pixels in three consecutive bytes.  Since we receive the data in
    // three one-byte-per-pixel buffers we have to shuffle the bytes.
    blit red   buffer_[top-left..]     patch-width --destination-pixel-stride=3 --destination-line-stride=(width_ * 3)
    blit green buffer_[top-left + 1..] patch-width --destination-pixel-stride=3 --destination-line-stride=(width_ * 3)
    blit blue  buffer_[top-left + 2..] patch-width --destination-pixel-stride=3 --destination-line-stride=(width_ * 3)

  draw-gray-scale left/int top/int right/int bottom/int pixels/ByteArray -> none:
    patch-width := right - left
    top-left := min buffer_.size (left + width_ * top)
    if outline:
      pixels2 := pixels.copy
      draw-byte-outline_ outline pixels2 patch-width --dotted

      blit pixels2 outline-buffer_[top-left..] patch-width --destination-line-stride=width_

    blit pixels buffer_[top-left..] patch-width --destination-line-stride=width_

  draw-several-color left/int top/int right/int bottom/int pixels/ByteArray -> none:
    draw-gray-scale left top right bottom pixels

  draw-two-color left/int top/int right/int bottom/int pixels/ByteArray -> none:
    if outline:
      patch-width := right - left
      pixels2 := pixels.copy
      draw-bit-outline_ outline pixels2 patch-width
      write-png-two-color outline-buffer_ left top right bottom pixels2

    write-png-two-color buffer_ left top right bottom pixels

  write-png-two-color buffer/ByteArray left/int top/int right/int bottom/int pixels/ByteArray -> none:
    if temp-buffer_.size < pixels.size:
      temp-buffer_ = ByteArray pixels.size
    8.repeat:
      temps_[it] = temp-buffer_[it..pixels.size]

    assert: left == (round-up left 8)
    assert: top == (round-up top 8)
    assert: right == (round-up right 8)
    assert: bottom == (round-up bottom 8)

    patch-width := right - left
    patch-height := bottom - top

    // Writes the patch to the buffer.  The patch is arranged as height/8
    // strips of width bytes, where each byte represents 8 vertically stacked
    // pixels, lsbit at the top.  PNG requires these be transposed so that each
    // line is represented by consecutive bytes, from top to bottom, msbit on
    // the left.

    pixels-0 := pixels[0..]
    pixels-1 := pixels[1..]
    pixels-2 := pixels[2..]
    pixels-4 := pixels[4..]

    // We start by reflecting each 8x8 block.
    // Reflect each 2x2 pixel block.
    blit pixels-0 temps_[0] patch-width/2 --source-pixel-stride=2 --destination-pixel-stride=2 --mask=0xaa
    blit pixels-1 temps_[1] patch-width/2 --source-pixel-stride=2 --destination-pixel-stride=2 --mask=0x55
    blit pixels-0 temps_[1] patch-width/2 --source-pixel-stride=2 --destination-pixel-stride=2 --shift=-1 --mask=0xaa --operation=OR
    blit pixels-1 temps_[0] patch-width/2 --source-pixel-stride=2 --destination-pixel-stride=2 --shift=1 --mask=0x55 --operation=OR
    // Reflect each 4x4 pixel block.  Blit is treating each 4x8 block as a line for this operation.
    blit temps_[0] pixels-0 2 --source-line-stride=4 --destination-line-stride=4 --mask=0xcc
    blit temps_[2] pixels-2 2 --source-line-stride=4 --destination-line-stride=4 --mask=0x33
    blit temps_[0] pixels-2 2 --source-line-stride=4 --destination-line-stride=4 --shift=-2 --mask=0xcc --operation=OR
    blit temps_[2] pixels-0 2 --source-line-stride=4 --destination-line-stride=4 --shift=2 --mask=0x33 --operation=OR
    // Reflect each 8x8 pixel block.  Blit is treating each 8x8 block as a line for this operation.
    blit pixels-0 temps_[0] 4 --source-line-stride=8 --destination-line-stride=8 --mask=0xf0
    blit pixels-4 temps_[4] 4 --source-line-stride=8 --destination-line-stride=8 --mask=0x0f
    blit pixels-0 temps_[4] 4 --source-line-stride=8 --destination-line-stride=8 --shift=-4 --mask=0xf0 --operation=OR
    blit pixels-4 temps_[0] 4 --source-line-stride=8 --destination-line-stride=8 --shift=4 --mask=0x0f --operation=OR

    // Now we need to spread the 8x8 blocks out over the lines they belong on.
    // First line is bytes 0, 8, 16..., next line is bytes 1, 9, 17... etc.
    8.repeat:
      index := left + (width_ * (top + 7 - it)) >> 3
      blit temps_[it] buffer[index..] (patch-width >> 3) --source-pixel-stride=8 --destination-line-stride=width_ --lookup-table=INVERT_

  draw-bit-outline_ outline/int pixels/ByteArray patch-width/int -> none:
    bottom-left := pixels.size - patch-width
    // Dotted line along top and bottom.
    for x := 0; x < patch-width; x += 2:
      if outline == 0:
        pixels[x] &= ~1
        pixels[bottom-left + x] &= ~0x80
      else:
        pixels[x] |= 1
        pixels[bottom-left + x] |= 0x80
    // Dotted line along left and right.
    for y := 0; y < pixels.size; y += patch-width:
      if outline == 0:
        pixels[y] &= ~0b01010101
        pixels[y + patch-width - 1] &= ~0b01010101
      else:
        pixels[y] |= 0b01010101
        pixels[y + patch-width - 1] |= 0b01010101

  draw-byte-outline_ outline/int pixels/ByteArray patch-width/int --dotted=false -> none:
    bottom-left := pixels.size - patch-width
    // Dotted line along top and bottom.
    x-step := dotted ? 2 : 1
    for x := 0; x < patch-width; x += x-step:
      pixels[x] = outline
      pixels[bottom-left + x] = outline
    // Dotted line along left and right.
    y-step := patch-width * (dotted ? 2 : 1)
    for y := 0; y < pixels.size; y += y-step:
      pixels[y] = outline
      pixels[y + patch-width - 1] = outline

  draw-two-bit left/int top/int right/int bottom/int plane-0/ByteArray plane-1/ByteArray -> none:
    if outline:
      patch-width := right - left
      plane-0-2 := plane-0.copy
      plane-1-2 := plane-1.copy
      draw-bit-outline_ (outline & 1) plane-0-2 patch-width
      draw-bit-outline_ (outline >> 1) plane-1-2 patch-width
      write-png-two-bit outline-buffer_ left top right bottom plane-0-2 plane-1-2
    write-png-two-bit buffer_ left top right bottom plane-0 plane-1

  write-png-two-bit buffer/ByteArray left/int top/int right/int bottom/int plane-0/ByteArray plane-1/ByteArray -> none:
    patch-width := right - left
    assert: patch-width == (round-up patch-width 4)
    patch-height := bottom - top
    assert: patch-height == (round-up patch-height 8)

    byte-width := width-to-byte-width width_

    // Writes part of the patch to the compressor.  The patch is arranged as
    // height/8 strips of width bytes, where each byte represents 8 vertically
    // stacked pixels.  PNG requires these be transposed so that each
    // line is represented by consecutive bytes, from top to bottom, msbit on
    // the left.
    // This implementation is not as optimized as the two-color version.
    row := 0
    ppb := 4  // Pixels per byte.
    for y := 0; y < patch-height; y += 8:
      for in-bit := 0; in-bit < 8 and y + top + in-bit < height; in-bit++:
        out-index := (left >> 2) + (top + y + in-bit) * byte-width
        for x := 0; x < patch-width; x += ppb:
          out := 0
          byte-pos := row + x + ppb - 1
          for out-bit := ppb - 1; out-bit >= 0; out-bit--:
            out |= ((plane-0[byte-pos - out-bit] >> in-bit) & 1) << (out-bit * 2)
            out |= ((plane-1[byte-pos - out-bit] >> in-bit) & 1) << (out-bit * 2 + 1)
          buffer[out-index + (width-to-byte-width x)] = out
      row += patch-width

  png-basename_/string

  static HEADER ::= #[0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n']

  static write-chunk stream name/string data/ByteArray -> none:
    length := ByteArray 4
    if name.size != 4: throw "invalid name"
    BIG-ENDIAN.put-uint32 length 0 data.size
    write_ stream length
    write_ stream name
    write_ stream data
    crc := Crc32
    crc.add name
    crc.add data
    write_ stream
      byte-swap_
        crc.get

  static write_ stream byte-array -> none:
    done := 0
    while done != byte-array.size:
      done += stream.write byte-array[done..]

  commit left/int top/int right/int bottom/int -> none:
    if outline:
      write-snapshot outline-buffer_
      outline-buffer_.replace 0 buffer_
    write-snapshot buffer_

  write-snapshot buffer/ByteArray -> none:
    snapshots_.add buffer.copy

  write-png -> none:
    true-color := flags & FLAG-TRUE-COLOR != 0
    gray := flags & FLAG-4-COLOR != 0
    three-color := flags & FLAG-3-COLOR != 0
    gray-scale := flags & FLAG-GRAY-SCALE != 0
    several-color := flags & FLAG-SEVERAL-COLOR != 0

    writeable := file.Stream.for-write "$(png-basename_).png"

    frames-across := 2
    frames-down := snapshots_.size / frames-across

    padding := 32

    mega-width := frames-across * width_ + (frames-across + 1) * padding
    mega-height := frames-down * height_ + (frames-down + 1) * padding

    mega-buffer := ByteArray
        (width-to-byte-width mega-width) * mega-height

    bit-depth := ?
    color-type := ?
    if true-color:
      bit-depth = 8
      color-type = COLOR-TYPE-TRUECOLOR
    else if gray-scale:
      bit-depth = 8
      color-type = COLOR-TYPE-GRAYSCALE
    else if three-color:
      bit-depth = 2
      color-type = COLOR-TYPE-INDEXED
    else if several-color:
      bit-depth = 8
      color-type = COLOR-TYPE-INDEXED
    else if gray:
      bit-depth = 2
      color-type = COLOR-TYPE-GRAYSCALE
    else:
      bit-depth = 1
      color-type = COLOR-TYPE-GRAYSCALE

    for y := 0; y < frames-down; y++:
      for x := 0; x < frames-across; x++:
        snapshot-index := y * frames-across + x
        if snapshot-index >= snapshots_.size: continue
        snapshot/ByteArray := snapshots_[snapshot-index]
        bits-per-line-raw := bit-depth * width_
        bits-per-line-rounded := round-up bits-per-line-raw 8
        if bits-per-line-rounded != bits-per-line-raw:
          // Zap the bits at the end of each line.
          for y2 := 0; y2 < height_; y2++:
            // Index of last byte of the line.
            index := (y2 + 1) * (width-to-byte-width width_) - 1
            // Mask out the bits that are beyond the last real pixel.
            snapshot[index] &= 0xff << (bits-per-line-rounded - bits-per-line-raw)
        pixel-index := (y * (height_ + padding) + padding) * (width-to-byte-width mega-width) + (width-to-byte-width (x * (width_ + padding) + padding))
        blit
            snapshot                          // Source.
            mega-buffer[pixel-index..]        // Destination.
            width-to-byte-width width_        // Bytes per line
            --destination-line-stride=(width-to-byte-width mega-width)
            --source-line-stride=(width-to-byte-width width_)

    png-writer := png-writer.PngWriter
        writeable
        mega-width
        mega-height
        --bit-depth=bit-depth
        --color-type=color-type

    if three-color:
      png-writer.write-chunk "PLTE" #[  // Palette.
          0xff, 0xff, 0xff,         // 0 is white.
          0, 0, 0,                  // 1 is black.
          0xff, 0, 0,               // 2 is red.
        ]
    else if several-color:
      // Use color palette of 7-color epaper display.
      png-writer.write-chunk "PLTE" #[  // Palette.
          0xff, 0xff, 0xff,         // 0 is white.
          0, 0, 0,                  // 1 is black.
          0xff, 0, 0,               // 2 is red.
          0, 0xff, 0,               // 3 is green.
          0, 0, 0xff,               // 4 is blue.
          0xff, 0xff, 0,            // 5 is yellow.
          0xff, 0xc0, 0,            // 6 is orange.
          // The next three are not available on the 7-color e-paper display.
          0x40, 0x40, 0x40,         // 7 is dark gray.
          0x80, 0x80, 0x80,         // 8 is gray.
          0xc0, 0xc0, 0xc0,         // 9 is light gray.
        ]

    zero-byte := #[0]
    line-size := width-to-byte-width mega-width
    line-step := width-to-byte-width mega-width
    mega-height.repeat: | y |
      png-writer.write-uncompressed zero-byte  // Adaptive scheme.
      index := y * line-step
      line := mega-buffer[index..index + line-size]
      if gray:
        line = ByteArray line.size: line[it] ^ 0xff
      else if several-color:
        line = ByteArray line.size: min SEVERAL-MAX-COLOR_ line[it]
      png-writer.write-uncompressed line

    png-writer.close
    writeable.close

SEVERAL-WHITE ::= 0
SEVERAL-BLACK ::= 1
SEVERAL-RED ::= 2
SEVERAL-GREEN ::= 3
SEVERAL-BLUE ::= 4
SEVERAL-YELLOW ::= 5
SEVERAL-ORANGE ::= 6
SEVERAL-DARK-GRAY ::= 7
SEVERAL-GRAY ::= 8
SEVERAL-LIGHT-GRAY ::= 9
SEVERAL-MAX-COLOR_ ::= 9

byte-swap_ ba/ByteArray -> ByteArray:
  result := ba.copy
  byte-swap-32 result
  return result

class SwapRedAndBlack implements png.PaletteTransformer:
  transform palette/ByteArray -> none:
    if palette[0] >= 0x80:
      palette[0] = 0
    else:
      palette[0] = 0xff
    palette[1] = 0
    palette[2] = 0
