#!/usr/bin/env bash
set -e

GRAPHS_DIR="${1:-../data}"
OUTPUT_DIR="${2:-../data/final-dots}"

# binary paths
PARALLEL=../build/parallel
OPTIM=../build/optim-greedy
GREEDY=../build/greedy

INPUT=../data/latin_square_10.col
CORES=3
RUNS=10

mkdir -p ../build results ../data/final-dots

# compile
g++ -O2 -fopenmp ../src/parallel.cpp -o "$PARALLEL"
g++ -O2 ../src/optim-greedy.cpp -o "$OPTIM"
g++ -O2 ../src/greedy.cpp -o "$GREEDY"

for COL in "$GRAPHS_DIR"/*.col; do
  [ -e "$COL" ] || continue # ensures sth exists
  BASE="$(basename "${COL%.col}")"

  # parallel
  BIN="$PARALLEL" INPUT="$COL" ARGS="--dot ${OUTPUT_DIR}/${BASE}-parallel.dot" CORES=$CORES RUNS=$RUNS \
    OUT_RUNS="results/${BASE}-parallel-runs.csv" OUT_SUM="results/${BASE}-parallel-summary.csv" \
    ./measure.sh

  # optim-greedy
  BIN="$OPTIM" INPUT="$COL" ARGS="--dot ${OUTPUT_DIR}/${BASE}-optim-greedy.dot" CORES=$CORES RUNS=$RUNS \
    OUT_RUNS="results/${BASE}-optim-greedy-runs.csv" OUT_SUM="results/${BASE}-optim-greedy-summary.csv" \
    ./measure.sh

  # greedy
  BIN="$GREEDY" INPUT="$COL" ARGS="--dot ${OUTPUT_DIR}/${BASE}-greedy.dot" CORES=$CORES RUNS=$RUNS \
    OUT_RUNS="results/${BASE}-greedy-runs.csv" OUT_SUM="results/${BASE}-greedy-summary.csv" \
    ./measure.sh
done