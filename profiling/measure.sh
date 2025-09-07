#!/usr/bin/env bash
# Time-only measurement with optional CPU pinning and stdin redirection.
set -euo pipefail

BIN="${BIN:-}"                 # required: binary path
ARGS="${ARGS:-}"
ARGS_FUNC="${ARGS_FUNC:-$ARGS}"   # used once, not timed, to obtain results
ARGS_TIME="${ARGS_TIME:-$ARGS}"   # used inside the timed loop

INPUT="${INPUT:-}"             # file to feed on stdin
CORES="${CORES:-}"             # e.g. "0-15"; empty = no pin

OUT_RUNS="${OUT_RUNS:-}"       # required: path to write runs.csv
OUT_SUM="${OUT_SUM:-}"         # required: path to write summary.csv
REPEAT="${REPEAT:-100}"        # iterations inside one timed run

PIN_PREFIX=""
if [[ -n "${CORES}" ]]; then
  if command -v taskset >/dev/null 2>&1; then
    PIN_PREFIX="taskset -c ${CORES}"
  elif command -v numactl >/dev/null 2>&1; then
    PIN_PREFIX="numactl --physcpubind=${CORES}"
  fi
fi

echo "run,real_s,user_s,sys_s,peak_kb,rc,colors_used" > "${OUT_RUNS}"

run_once() {
  local idx=1
  local tf_time="time_${idx}.csv"
  local out_log="out_${idx}.log"
  local err_log="err_${idx}.log"
  local rc=0

  # One functional run to capture colors (not timed)
  ${PIN_PREFIX} "${BIN}" ${ARGS_FUNC} < "${INPUT}" > "${out_log}" 2>/dev/null || true

  # Parse "colors_used: K"
  local colors=""
  if [[ -s "${out_log}" ]]; then
    colors="$(awk -F': *' '/^colors_used:/{v=$2} END{if (v!="") print v}' "${out_log}")"
  fi

  # Define the REPEAT loop
  run_cmd() {
    if [[ -n "${INPUT}" ]]; then
      for _i in $(seq 1 "${REPEAT}"); do
        ${PIN_PREFIX} "${BIN}" ${ARGS_TIME} < "${INPUT}" >/dev/null || return 1
      done
    else
      for _i in $(seq 1 "${REPEAT}"); do
        ${PIN_PREFIX} "${BIN}" ${ARGS_TIME} >/dev/null || return 1
      done
    fi
  }

  # Time the whole REPEAT loop; inject function into subshell
  /usr/bin/time -f "%e,%U,%S,%M" -o "${tf_time}" \
    bash -c "$(declare -f run_cmd); run_cmd" 2> "${err_log}" || rc=$?

  # Parse timings
  IFS=, read -r real user sys peak < <(tail -n1 "${tf_time}")

  # Normalize to per-execution if REPEAT>1
  if [[ "${REPEAT}" -gt 1 ]]; then
    real=$(awk -v x="$real" -v r="$REPEAT" 'BEGIN{printf "%.6f", x/r}')
    user=$(awk -v x="$user" -v r="$REPEAT" 'BEGIN{printf "%.6f", x/r}')
    sys=$(awk -v x="$sys" -v r="$REPEAT" 'BEGIN{printf "%.6f", x/r}')
  fi

  printf "%d,%.6f,%.6f,%.6f,%.0f,%d,%s\n" \
    "${idx}" "${real:-0}" "${user:-0}" "${sys:-0}" "${peak:-0}" "${rc}" "${colors:-}" >> "${OUT_RUNS}"

  [[ $rc -eq 0 ]] && rm -f "${err_log}"
  rm -f "${tf_time}" "${out_log}"
}

run_once

summarize_col() {
  local col="$1" name="$2"
  awk -F',' -v c="${col}" -v name="${name}" '
    function quant(qv,    pos,base,frac) {
      if (n<=1) return a[1]
      pos = 1 + (n-1)*qv
      base = int(pos); frac = pos - base
      if (base < 1) base = 1
      if (base >= n) return a[n]
      return a[base] + frac*(a[base+1]-a[base])
    }
    NR==1 { next }
    ($6==0) && ($c!="") { a[++n] = $c + 0 }
    END {
      if (n < 1) { printf("%s,na,na,na\n", name); exit }
      # with one row, median=p25=p75=a[1]
      for (i=1;i<=n;i++) for (j=i+1;j<=n;j++) if (a[i]>a[j]) { t=a[i]; a[i]=a[j]; a[j]=t }
      printf("%s,%.6f,%.6f,%.6f\n", name, quant(0.5), quant(0.25), quant(0.75))
    }
  ' "${OUT_RUNS}"
}

{
  echo "metric,median,p25,p75"
  summarize_col 2 real_s
  summarize_col 3 user_s
  summarize_col 4 sys_s
  summarize_col 5 peak_kb
  summarize_col 7 colors_used
} > "${OUT_SUM}"

echo "Finished files ${OUT_RUNS}, ${OUT_SUM}"
