#!/usr/bin/env bash
set -euo pipefail

mode="${1:-all}"   # all | run | merge

GRAPHS_DIR="../data"
OUTPUT_DIR="../data/final-dots"
RESULTS_DIR="results"
OUT="final.csv"

PARALLEL=../build/parallel
OPTIM=../build/optim-greedy
GREEDY=../build/greedy

CORES="${CORES:-}"           # empty = no pin
REPEAT="${REPEAT:-100}"      # iterations inside timed run

run_part() {
  mkdir -p ../build "$RESULTS_DIR" "$OUTPUT_DIR"

  g++ -O3 -fopenmp ../src/parallel.cpp -o "$PARALLEL"
  g++ -O3 ../src/optim-greedy.cpp -o "$OPTIM"
  g++ -O3 ../src/greedy.cpp -o "$GREEDY"

  for COL in "$GRAPHS_DIR"/*.col; do
    [ -e "$COL" ] || continue
    BASE="$(basename "${COL%.col}")"

    # parallel
    BIN="$PARALLEL" INPUT="$COL" ARGS="--dot ${OUTPUT_DIR}/${BASE}-parallel.dot" CORES="$CORES" \
      REPEAT="$REPEAT" OUT_RUNS="results/${BASE}-parallel-runs.csv" OUT_SUM="results/${BASE}-parallel-summary.csv" \
      ./measure.sh

    # optim-greedy
    BIN="$OPTIM" INPUT="$COL" ARGS="--dot ${OUTPUT_DIR}/${BASE}-optim-greedy.dot" CORES="$CORES" \
      REPEAT="$REPEAT" OUT_RUNS="results/${BASE}-optim-greedy-runs.csv" OUT_SUM="results/${BASE}-optim-greedy-summary.csv" \
      ./measure.sh

    # greedy (keep disabled if not needed)
    # BIN="$GREEDY" INPUT="$COL" ARGS="--dot ${OUTPUT_DIR}/${BASE}-greedy.dot" CORES="$CORES" \
    #   REPEAT="$REPEAT" OUT_RUNS="results/${BASE}-greedy-runs.csv" OUT_SUM="results/${BASE}-greedy-summary.csv" \
    #   ./measure.sh
  done
  echo "----- Done computing, start merging -----"
}

merge_part() {
  metric_median() { awk -F',' -v m="$2" 'NR>1 && $1==m{print $2; exit}' "$1"; }

  echo "graph,parallel_real_s_median,optim_greedy_real_s_median,parallel_colors_used,optim_greedy_colors_used,speedup,parallel_efficiency" > "$OUT"

  shopt -s nullglob
  for p_sum in "$RESULTS_DIR"/*-parallel-summary.csv; do
    base="${p_sum%-parallel-summary.csv}"
    graph="$(basename "$base")"
    og_sum="${base}-optim-greedy-summary.csv"
    [[ -f "$og_sum" ]] || continue

    par_t="$(metric_median "$p_sum" real_s)"
    par_c="$(metric_median "$p_sum" colors_used)"
    og_t="$(metric_median "$og_sum" real_s)"
    og_c="$(metric_median "$og_sum" colors_used)"

    if [[ -z "$par_t" || -z "$og_t" || "$par_t" == "0" ]]; then
      speedup=""
      eff=""
    else
      speedup="$(awk -v a="$og_t" -v b="$par_t" 'BEGIN{ if(b==0){print ""} else {printf "%.6f", (a+0)/(b+0)} }')"
      eff="$(awk -v s="$speedup" -v p="${P:-0}" 'BEGIN{if(p=="" || p+0==0 || s==""){print ""} else {printf "%.6f", (s+0)/(p+0)} }')"
    fi

    printf "%s,%s,%s,%s,%s,%s,%s\n" \
      "$graph" "$par_t" "$og_t" "$par_c" "$og_c" "$speedup" "$eff" >> "$OUT"
  done
  echo "Done merging, wrote $OUT"
}

case "$mode" in
  all)   run_part; merge_part ;;
  run)   run_part ;;
  merge) merge_part ;;
  *) echo "usage: $0 [all|run|merge]"; exit 2 ;;
esac
