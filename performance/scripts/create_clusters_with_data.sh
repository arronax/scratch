#!/bin/bash
set -euo pipefail

scale="${1}"

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
# data load
fsync = 'off'
wal_level = 'minimal'
autovacuum = 'off'
archive_mode = 'off'
max_wal_senders = 0
EOF
pg_ctlcluster 13 test start
su - postgres -c 'psql -c "CREATE USER sbtest WITH PASSWORD '"'sbtest'"';"'
su - postgres -c 'psql -c "CREATE DATABASE sbtest OWNER sbtest;"'
cd ~/sysbench-tpcc
./tpcc.lua --pgsql-user=sbtest --pgsql-password=sbtest --pgsql-db=sbtest --threads=32 --use_fk=0 --trx_level=RC --db-driver=pgsql --tables=10 --scale="${scale}" prepare
pg_ctlcluster 13 test stop
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
su - postgres -c 'psql -d sbtest -c "VACUUM VERBOSE ANALYZE;"'
su - postgres -c 'psql -d sbtest -c "CHECKPOINT;"'
pg_ctlcluster 13 test stop
#walfile=$(/usr/lib/postgresql/13/bin/pg_controldata /dbdata/datadir | grep "WAL file" | grep -Eo "00.*")
#mv /dbdata/datadir/pg_wal/${walfile} /tmp/
#rm -rf /dbdata/datadir/pg_wal/000*
#mv /tmp/${walfile} /dbdata/datadir/pg_wal/
mv /dbdata/datadir "/dbdata/datadir_scale_${scale}"
