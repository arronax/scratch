# Assessing impact of jemalloc profiling on MySQL performance

A series of basic testing aimed at understanding whether enabling profiling in jemalloc has a significant impact on performance. Inspired by https://www.percona.com/blog/2012/07/05/impact-of-memory-allocators-on-mysql-performance/

### HW, OS, MySQL setup

* AWS EC2 instance m5d.8xlarge: 32 vCPU, 128GiB RAM, 2x600 local NVMe SSD
* CentOS 7 AMI: ami-0b850cf02cc00fdc8
* Percona Server 8.0.22-13.1.el7.x86\_64 package from Percona repo

Disk setup:
```
mdadm --create --verbose /dev/md0 --level=0 --name=dbdata_raid --raid-devices=2 /dev/nvme1n1 /dev/nvme2n1
mkfs.ext4 -L dbdata /dev/md0
echo 'LABEL=dbdata /dbdata ext4 data=writeback,noatime,barrier=0,nofail 0 2' >> /etc/fstab
mount -a
```

MySQL configuration:
```
[mysqld]
datadir=/dbdata/mysql
socket=/dbdata/mysql/mysql.sock
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
innodb_buffer_pool_size=60G
innodb_log_file_size=4G
innodb_flush_method=O_DIRECT
max_connections=10000
max_prepared_stmt_count=1048576
[client]
socket=/dbdata/mysql/mysql.sock
```
