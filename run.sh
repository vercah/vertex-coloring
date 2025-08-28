#!/bin/bash

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input-file.col>"
    exit 1
fi

INPUT="$1"
BASENAME=$(basename "$INPUT" .col)
BUILD_DIR="build"
DATA_DIR="data"
OUT_DOT="$DATA_DIR/${BASENAME}.dot"
OUT_PNG="$DATA_DIR/${BASENAME}.png"

# Ensure build dir exists
mkdir -p "$BUILD_DIR"
mkdir -p "$DATA_DIR"

echo "[1/3] Compiling src/greedy.cpp ..."
g++ -O2 -std=c++17 src/greedy.cpp -o "$BUILD_DIR/greedy"

# Run greedy coloring
echo "[2/3] Running greedy algorithm on $INPUT ..."
"$BUILD_DIR/greedy" --dot "$OUT_DOT" < "$INPUT"

echo "[3/3] Generating PNG with Graphviz ..."
neato -Tpng "$OUT_DOT" -o "$OUT_PNG"

echo "Done! Output image: $OUT_PNG"
