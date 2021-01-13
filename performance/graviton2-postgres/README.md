# Comparing m6gd to m5d with PostgreSQL 13

Trying to see whether Graviton2 instances are really that good. Basic testing idea: use sysbench-tpcc running against PostgreSQL 13 to compare two instances side by side.

### Instances picked

|Instance Type|CPU|Memory|Disk|
|---|:---:|:---:|---|
|m5d.8xlarge|32|128|2x600 local NVMe<sup>\*</sup>|
|m6gd.8xlarge|32|128|1x1900 local NVMe|

<sup>\*</sup>Two local drives on m5 were made into a single raid0 device.

### OS and config

Ubuntu 20.04 AMI, no configuration on OS side apart from creating the FS on ephemeral drives.

|Instance Type|AMI|
|---|---|
|m5d.8xlarge|ami-0885b1f6bd170450c|
|m6gd.8xlarge|ami-054e49cb26c2fd312|

No packages were updated, new ones installed as required (for PG).

#### Disk setup

##### For m5d

```
mdadm --create --verbose /dev/md0 --level=0 --name=dbdata_raid --raid-devices=2 /dev/nvme1n1 /dev/nvme2n1
mkfs.ext4 -L dbdata /dev/md0
echo 'LABEL=dbdata /dbdata ext4 data=writeback,noatime,barrier=0,nofail 0 2' >> /etc/fstab
mount -a
```

##### For m6gd
```
mkfs.ext4 -L dbdata /dev/nvme1n1
echo 'LABEL=dbdata /dbdata ext4 data=writeback,noatime,barrier=0,nofail 0 2' >> /etc/fstab
mount -a
```

### PostgreSQL config

PGDG package used.

```
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
```

#### addition for data load
```
# data load
fsync = 'off'
wal_level = 'minimal'
autovacuum = 'off'
archive_mode = 'off'
max_wal_senders = 0
```

### Testing

Two sets of tests: In-memory with 10 warehouses (\~10G dataset size), IO-bound with 200 warehouses (\~200G dataset size). 16, 32, 64, 128 threads. 1-hour long. In-memory tests use pareto distribution, while IO-bound tests use uniform distribution.

Each test follows the next procedure:
1. Restore the data directory of necessary scale (10/200).
1. Run 10-minute warmup test with the same parameters as the large test.
1. Checkpoint on PG side.
1. Run the actual test.

### Results

TL;DR PostgreSQL 13 on Graviton2-based m6gd.8xlarge shows good performance benefits on in-memory workload, and shows some notable issues only in highly saturated 64 and 128 threads IO-bound tests. At 25% lower price, it's an interesting option to pick and test for a database server.

Some todo: investigate the meltdown of m6gd.8xlarge under 64/128 threads IO-bound test. Is it RAID0 of two local nvme drives helping m5d.8xlarge?

#### in-memory

Instances side by side

![in-memory 16 threads](./graviton2-postgres/images/tpcc.in-memory.16.png)
![in-memory 32 threads](./graviton2-postgres/images/tpcc.in-memory.32.png)
![in-memory 64 threads](./graviton2-postgres/images/tpcc.in-memory.64.png)
![in-memory 128 threads](./graviton2-postgres/images/tpcc.in-memory.128.png)

All tests for an instance together

![in-memory all m6gd.8xlarge](./graviton2-postgres/images/tpcc.in-memory.m6gd.8xlarge.png)
![in-memory all m5d.8xlarge](./graviton2-postgres/images/tpcc.in-memory.m5d.8xlarge.png)

Load with 128 threads is way past the saturation point for both instances, so they show worse results than with 64 threads. Difference over the saturation point is negligible between m5d.8xlarge and m6gd.8xlarge

#### io-bound

Instances side by side

![io-bound 16 threads](./graviton2-postgres/images/tpcc.io-bound.16.png)
![io-bound 32 threads](./graviton2-postgres/images/tpcc.io-bound.32.png)
![io-bound 64 threads](./graviton2-postgres/images/tpcc.io-bound.64.png)
![io-bound 128 threads](./graviton2-postgres/images/tpcc.io-bound.128.png)

All tests for an instance together

![io-bound all m6gd.8xlarge](./graviton2-postgres/images/tpcc.io-bound.m6gd.8xlarge.png)
![io-bound all m5d.8xlarge](./graviton2-postgres/images/tpcc.io-bound.m5d.8xlarge.png)

m6gd experiences performance falloff at 64 threads, getting more pronounced at 128. At this moment the cause is not clear. Storage is not equal between the two instances, with m5d having 2x local drives in raid0, which is likely playing in its hand.
