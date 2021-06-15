#!/bin/bash
set -euo pipefail

global_label="${1}"
tables=4
table_size=50000000
user="sbuser"
password="sbPass1234#"
database="sysbench"
mysqlcmd="mysql --user=${user} --password=${password} --host=127.0.0.1 ${database}"

log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&1
}

sysbench_run_test() {
  local label="${1}"
  local test="${2}"
  local duration="${3}"
  local threads="${4}"
  local datetime="$(date +%F_%H%M%S)"

  log "Running sysbench test with following arguments"
  log "test: ${test}; threads: ${threads}; duration: ${duration}; label: ${label}"
  log "logfile: /opt/performance/${global_label}.${label}.${test}.${threads}.${datetime}.log"

  sysbench \
	"/usr/share/sysbench/${test}.lua" \
	--db-driver=mysql \
    --mysql-host=127.0.0.1 \
	--mysql-user="${user}" \
	--mysql-password="${password}" \
	--mysql-db="${database}" \
	--mysql-ignore-errors=all \
	--tables="${tables}" \
	--table_size="${table_size}" \
	--report-interval=1 \
	--threads="${threads}" \
	--time="${duration}" \
	run 1>"/opt/performance/${global_label}.${label}.${test}.${threads}.${datetime}.log"
}

warmup() {
  log "Warming up the instance after restart"
  for i in $(seq 1 ${tables}); do
    log "Running select avg(id) from sbtest${i} FORCE KEY (PRIMARY)"
    ${mysqlcmd} -e "select avg(id) from sbtest${i} FORCE KEY (PRIMARY)"
  done
  log "Running OLTP_RO for 600 seconds"
  sysbench_run_test warmup oltp_read_only 600 16
}

main() {
  warmup
  ## oltp_ro
  test="oltp_read_only"
  for threads in {16,64,128,256,512,1024,1536}; do
    log "============================================================"
    log " Starting test run: ${test} at ${threads} threads"
    log "============================================================"
    sysbench_run_test run "${test}" 300 "${threads}"
  done
  ## point_select
  test="oltp_point_select"
  for threads in {16,64,128,256,512,1024,1536}; do
    log "============================================================"
    log " Starting test run: ${test} at ${threads} threads"
    log "============================================================"
    sysbench_run_test run "${test}" 300 "${threads}"
  done
}

main
