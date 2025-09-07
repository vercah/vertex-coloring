#!/usr/bin/env bash
# Time-only measurement with optional CPU pinning and stdin redirection.
set -u

BIN="${BIN:-}"          # binary path
ARGS="${ARGS:-}"             # program args (no redirection here)
INPUT="${INPUT:-}"           # file to feed on stdin, e.g. INPUT=data/easy-01.col
RUNS="${RUNS:-5}"            # repeats
CORES="${CORES:-}"           # e.g. "3" or "0-3"; empty = no pin

OUT_RUNS="${OUT_RUNS:-}"
OUT_SUM="${OUT_SUM:-}"

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
  local idx="$1"
  local tf_time="time_${idx}.csv"
  local out_log="out_${idx}.log"
  local err_log="err_${idx}.log"
  local rc=0

  if [[ -n "${INPUT}" ]]; then
    /usr/bin/time -f "%e,%U,%S,%M" -o "${tf_time}" \
      ${PIN_PREFIX} "${BIN}" ${ARGS} < "${INPUT}" >"${out_log}" 2> "${err_log}" || rc=$?
  else
    /usr/bin/time -f "%e,%U,%S,%M" -o "${tf_time}" \
      ${PIN_PREFIX} "${BIN}" ${ARGS} >"${out_log}" 2> "${err_log}" || rc=$?
  fi

  # parse timings
  IFS=, read -r real user sys peak < <(tail -n1 "${tf_time}")

  # parse last "colors_used: K" from stdout
  local colors=""
  if [[ -s "${out_log}" ]]; then
    colors="$(awk -F': *' '/colors_used:/ {v=$2} END{if (v!="") print v}' "${out_log}")"
  fi

  printf "%d,%.6f,%.6f,%.6f,%.0f,%d,%s\n" \
    "${idx}" "${real:-0}" "${user:-0}" "${sys:-0}" "${peak:-0}" "${rc}" "${colors}" >> "${OUT_RUNS}"

  [[ $rc -eq 0 ]] && rm -f "${err_log}"
  rm -f "${tf_time}" "${out_log}"
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
    ($6==0) && ($c!="") { a[++n] = $c + 0 } 
    END {
      if (n < 1) { printf("%s,na,na,na\n", name); exit }
      # sort a[]
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
