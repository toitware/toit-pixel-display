#!/bin/sh

#Usage:
# sh tests/visualized.sh toit.run tests/true_color_visualized.toit

set -e

TOIT_EXE=$1
TOIT_PROGRAM=$2

mkdir -p tests/out

$TOIT_EXE -Xenable_asserts tests/$TOIT_PROGRAM tests/out/$TOIT_PROGRAM

for outfilename in tests/out/$TOIT_PROGRAM-*.png
do
  echo $outfilename
  goldfilename=${outfilename/out/gold}
  cmp $goldfilename $outfilename
done

for goldfilename in tests/gold/$TOIT_PROGRAM-*.png
do
  outfilename=${goldfilename/gold/out}
  cmp $goldfilename $outfilename
done

