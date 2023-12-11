#!/bin/sh

#Usage:
# sh tests/visualized.sh toit.run tests/true-color-visualized.toit

set -e

TOIT_EXE=$1
TOIT_PROGRAM=$2

mkdir -p tests/out

$TOIT_EXE -Xenable_asserts tests/$TOIT_PROGRAM tests/out/$TOIT_PROGRAM

$TOIT_EXE tests/toit-png-tools/bin/pngdiff.toit -o tests/out/diff-$TOIT_PROGRAM.png -t tests/out/$TOIT_PROGRAM.png tests/gold/$TOIT_PROGRAM.png
