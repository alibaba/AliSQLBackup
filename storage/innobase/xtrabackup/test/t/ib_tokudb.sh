########################################################################
# Test support for TokuDB
########################################################################

. inc/common.sh

require_tokudb

MYSQLD_EXTRA_MY_CNF_OPTS="
innodb_file_per_table"

start_server
load_sakila

$MYSQL $MYSQL_ARGS test <<EOF
CREATE TABLE t(id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, c INT) ENGINE=TokuDB;
INSERT INTO t(c) VALUES (1),(2),(3),(4),(5),(6),(7),(8);
SET AUTOCOMMIT=0;
INSERT INTO t(c) SELECT c FROM t;
INSERT INTO t(c) SELECT c FROM t;
INSERT INTO t(c) SELECT c FROM t;
INSERT INTO t(c) SELECT c FROM t;
COMMIT;
EOF

checksum_a=`checksum_table test t`

# Full backup
vlog "Starting backup"

innobackupex  --no-timestamp $topdir/backup

if ! egrep -q "TokuDB storage engine is enabled" $OUTFILE; then
      die "TokuDB check error"
fi

if ! egrep -q ".*Copying.*\.tokulog[[:digit:]]+" $OUTFILE; then
      die "Not backup TokuDB log"
fi

if ! egrep -q ".*Copying.*\.tokudb" $OUTFILE; then
      die "Not backup TokuDB data"
fi

vlog "Preparing backup"
innobackupex --apply-log $topdir/backup

# Destroying mysql data
stop_server
rm -rf $mysql_datadir/*
vlog "Data destroyed"

# Restore backup
vlog "Copying files to their original locations"
innobackupex --copy-back $topdir/backup
vlog "Data restored"

start_server

checksum_b=`checksum_table test t`

if [ "$checksum_a" != "$checksum_b" ]; then
    die "Checksums do not match"
fi

vlog "Checksums are OK"
