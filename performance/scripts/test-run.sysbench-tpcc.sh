#!/bin/bash
set -euo pipefail

arch="${1}"

log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&1
}

setup_cluster() {
  log "Creating a cluster"
  pg_createcluster -d /dbdata/datadir 13 test
  cat > /dbdata/datadir/postgresql.auto.conf <<EOF
# Do not edit this file manually!
# It will be overwritten by the ALTER SYSTEM command.
port = '5432'
max_connections = '200'
shared_buffers = '32GB'
checkpoint_timeout = '1h'
max_wal_size = '96GB'
checkpoint_completion_target = '0.9'
archive_mode = 'on'
archive_command = '/bin/true'
random_page_cost = '1.0'
effective_cache_size = '80GB'
maintenance_work_mem = '2GB'
autovacuum_vacuum_scale_factor = '0.4'
bgwriter_lru_maxpages = '1000'
bgwriter_lru_multiplier = '10.0'
wal_compression = 'ON'
log_checkpoints = 'ON'
log_autovacuum_min_duration = '0'
EOF
  pg_ctlcluster 13 test start
  ##### sysbench DB setup
  log "Creating sysbench users"
  su - postgres -c 'psql -c "CREATE USER sbtest WITH PASSWORD '"'sbtest'"';"'
  su - postgres -c 'psql -c "CREATE DATABASE sbtest OWNER sbtest;"'
}

setup_cluster_copy() {
  local scale="${1}"
  rm -rf /dbdata/datadir
  log "Copying the cluster from pre-created copy"
  cp -rip "/dbdata/datadir_scale_${scale}" /dbdata/datadir
  pg_ctlcluster 13 test start
}

post_run_cluster() {
  log "Shutting down the cluster"
  pg_ctlcluster 13 test stop
  cp -ip /var/log/postgresql/postgresql-13-test.log "/opt/performance/postgres.${arch}.$(date +%F_%H%M%S).log"
  pg_dropcluster 13 test
}

post_run_cluster_copy() {
  log "Shutting down the cluster"
  pg_ctlcluster 13 test stop
  cp -ip /var/log/postgresql/postgresql-13-test.log "/opt/performance/postgres.${arch}.$(date +%F_%H%M%S).log"
  rm -rf /dbdata/datadir
}

sysbench_load_data() {
  local scale="${1}"
  log "Loading sysbench data with scale ${scale}"
  cd /root/sysbench-tpcc/ && \
  ./tpcc.lua --pgsql-user=sbtest --pgsql-password=sbtest --pgsql-db=sbtest \
    --threads=16 --use_fk=0 --trx_level=RC --db-driver=pgsql \
    --tables=10 --scale="${scale}" \
    prepare 1>/dev/null
}

sysbench_run_test() {
  local scale="${1}"
  local distribution="${2}"
  local threads="${3}"
  local duration="${4}"
  local label="${5}"
  local datetime="$(date +%F_%H%M%S)"
  log "Running sysbench-tpcc test with following arguments"
  log "scale: ${scale}; distribution: ${distribution}; threads: ${threads}; duration: ${duration}; label: ${label}"
  log "logfile: /opt/performance/${label}.${arch}.${datetime}.log"
  cd /root/sysbench-tpcc/ && \
  ./tpcc.lua --pgsql-user=sbtest --pgsql-password=sbtest --pgsql-db=sbtest \
    --report-interval=1 --report_csv=yes \
    --use_fk=0 --trx_level=RC --db-driver=pgsql \
    --time="${duration}" --threads="${threads}" \
    --tables=10 --scale="${scale}" --rand-type="${distribution}" \
    run 1>"/opt/performance/${label}.${arch}.${datetime}.log" 2>&1
}

main() {
  ## in-memory
  scale=10
  for threads in {16,32,64,128}; do
    log "============================================================"
    log " Starting test run: in-memory ${threads} threads"
    log "============================================================"
    setup_cluster_copy ${scale}
    #####sysbench_load_data ${scale} #### using pre-created copy instead
    sysbench_run_test ${scale} "pareto" "${threads}" 600 "warmup"
    su - postgres -c 'psql -c "CHECKPOINT;"'
    sysbench_run_test ${scale} "pareto" "${threads}" 3600 "in-memory_${threads}"
    post_run_cluster_copy
  done
  ## io-bound
  scale=200
  for threads in {16,32,64,128}; do
    log "============================================================"
    log " Starting test run: io-bound ${threads} threads"
    log "============================================================"
    setup_cluster_copy ${scale}
    #####sysbench_load_data ${scale} #### using pre-created copy instead
    sysbench_run_test ${scale} "uniform" "${threads}" 600 "warmup"
    su - postgres -c 'psql -c "CHECKPOINT;"'
    sysbench_run_test ${scale} "uniform" "${threads}" 3600 "io-bound_${threads}"
    post_run_cluster
  done
}

main