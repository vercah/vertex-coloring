#!/usr/bin/env bash
set -e

# binary paths
PARALLEL=../build/parallel
OPTIM=../build/optim-greedy
GREEDY=../build/greedy

INPUT=../data/latin_square_10.col
CORES=3
RUNS=10

# compile
g++ -O2 -fopenmp ../src/parallel.cpp -o "$PARALLEL"
g++ -O2 ../src/optim-greedy.cpp -o "$OPTIM"
g++ -O2 ../src/greedy.cpp -o "$GREEDY"

# measure runs
BIN="$PARALLEL" INPUT="$INPUT" ARGS="--dot ../data/parallel-out.dot" CORES=$CORES RUNS=$RUNS \
  OUT_RUNS=parallel-runs.csv OUT_SUM=parallel-summary.csv ./measure.sh

BIN="$OPTIM" INPUT="$INPUT" ARGS="--dot ../data/optim-out.dot" CORES=$CORES RUNS=$RUNS \
  OUT_RUNS=optim-runs.csv OUT_SUM=optim-summary.csv ./measure.sh

BIN="$GREEDY" INPUT="$INPUT" ARGS="--dot ../data/greedy-out.dot" CORES=$CORES RUNS=$RUNS \
  OUT_RUNS=greedy-runs.csv OUT_SUM=greedy-summary.csv ./measure.sh
