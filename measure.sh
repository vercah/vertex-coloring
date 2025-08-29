#!/usr/bin/env bash
# Time-only measurement with optional CPU pinning and stdin redirection.
set -u

BIN="${BIN:-./app}"          # binary path
ARGS="${ARGS:-}"             # program args (no redirection here)
INPUT="${INPUT:-}"           # file to feed on stdin, e.g. INPUT=data/easy-01.col
RUNS="${RUNS:-5}"            # repeats
CORES="${CORES:-}"           # e.g. "3" or "0-3"; empty = no pin

OUT_RUNS="${OUT_RUNS:-runs.csv}"
OUT_SUM="${OUT_SUM:-summary.csv}"

PIN_PREFIX=""
if [[ -n "${CORES}" ]]; then
  if command -v taskset >/dev/null 2>&1; then
    PIN_PREFIX="taskset -c ${CORES}"
  elif command -v numactl >/dev/null 2>&1; then
    PIN_PREFIX="numactl --physcpubind=${CORES}"
  fi
fi

echo "run,real_s,user_s,sys_s,peak_kb,rc" > "${OUT_RUNS}"

run_once() {
  local idx="$1"
  local tf_time="time_${idx}.csv"
  local rc=0

  if [[ -n "${INPUT}" ]]; then
    /usr/bin/time -f "%e,%U,%S,%M" -o "${tf_time}" \
      ${PIN_PREFIX} "${BIN}" ${ARGS} < "${INPUT}" >/dev/null 2> "err_${idx}.log" || rc=$?
  else
    /usr/bin/time -f "%e,%U,%S,%M" -o "${tf_time}" \
      ${PIN_PREFIX} "${BIN}" ${ARGS} >/dev/null 2> "err_${idx}.log" || rc=$?
  fi

  # last line has the 4 comma-separated numbers
  IFS=, read -r real user sys peak < <(tail -n1 "${tf_time}")
  printf "%d,%.6f,%.6f,%.6f,%.0f,%d\n" "${idx}" "${real:-0}" "${user:-0}" "${sys:-0}" "${peak:-0}" "${rc}" >> "${OUT_RUNS}"

  if [[ $rc -eq 0 ]]; then rm -f "err_${idx}.log"; fi
  rm -f "${tf_time}"
}

for i in $(seq 1 "${RUNS}"); do run_once "${i}"; done

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
    $6==0 { a[++n] = $c + 0 }   # only successful runs (rc==0)
    END {
      if (n < 1) { printf("%s,na,na,na\n", name); exit }
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
} > "${OUT_SUM}"

echo "Done. Files: ${OUT_RUNS}, ${OUT_SUM}"
