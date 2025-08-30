#!/bin/bash
set -euo pipefail

# Run this from the profiling directory
PROFILE_DIR="."
BUILD_DIR="$PROFILE_DIR/../build"
SRC="$PROFILE_DIR/../src/greedy.cpp"
BIN="$BUILD_DIR/greedy"
INPUT="$PROFILE_DIR/../data/latin_square_10.col"
OUT_DOT="$PROFILE_DIR/../data/out.dot"

mkdir -p "$BUILD_DIR"

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Compile with -pg and -O0"
g++ -O0 -pg -o "$BIN" "$SRC"

echo "Run with input (gmon.out will be created in $PROFILE_DIR)"
"$BIN" --dot "$OUT_DOT" < "$INPUT"

echo "gmon.out:"
ls -l "$PROFILE_DIR/gmon.out"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

echo "Creating reports..."
gprof -b -p "$BIN" "$PROFILE_DIR/gmon.out" > "$PROFILE_DIR/flat.txt"
gprof -b -q "$BIN" "$PROFILE_DIR/gmon.out" > "$PROFILE_DIR/callgraph.txt"

echo "Recompile with debug info for annotation"
g++ -O0 -pg -g -o "$BIN" "$SRC"
"$BIN" --dot "$OUT_DOT" < "$INPUT"
gprof -b -A "$BIN" "$PROFILE_DIR/gmon.out" > "$PROFILE_DIR/annotated.txt"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

echo "Saved:"
echo "  $PROFILE_DIR/flat.txt"
echo "  $PROFILE_DIR/callgraph.txt"
echo "  $PROFILE_DIR/annotated.txt"

echo "Clean up gmon.out"
rm -v "$PROFILE_DIR/gmon.out"
