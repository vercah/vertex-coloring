# Build normal binary
make

# time only
BIN=build/greedy INPUT=data/DSJC125.1.col ARGS="--dot data/out.dot" CORES=3 RUNS=5 ./measure.sh

# Add gprof once, same args, pinned
#make gprof-build
#./measure.sh BIN=./build/greedy ARGS="--dot data/out.dot" CORES=3 RUNS=5 GPROF=1 GPROF_BIN=./app_gprof < data/easy-01.col

# If you want the script to compile the gprof binary itself:
#./measure.sh BIN=./app ARGS="--dot data/out.dot" CORES=3 RUNS=5 GPROF=1 GPROF_BIN=./app_gprof SRC=src/greedy.cpp < data/easy-01.col
