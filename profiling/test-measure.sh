BIN=../build/optim-greedy INPUT=../data/easy-01.col \
ARGS_FUNC="--dot /tmp/x.dot" ARGS_TIME="" CORES="0-7" REPEAT=1 \
OUT_RUNS=tmp_runs.csv OUT_SUM=tmp_sum.csv ./measure.sh

# grep -n '^colors_used:' out_1.log || echo "no colors_used line"
awk -F, 'NR==2{print "runs.csv colors="$7", rc="$6", real="$2}' tmp_runs.csv
