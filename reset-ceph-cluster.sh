#!/bin/bash

set -ex

# shellcheck disable=SC1091
source /home/vagrant/.env
# These env vars are coming from that file:
# DISK_COUNT
# NODE_COUNT
# CEPH_RELEASE
# NODE
# CEPH_MON_COUNT

cd /home/vagrant/ceph-deploy || { echo "Can't access /home/vagrant/ceph-deploy. Cluster probably hasn't been 'make up'ed yet."; exit 1; }

for (( i=1; i>=NODE_COUNT; i++ )); do
    ceph-deploy purge "node${i}" &
done
wait

for (( i=1; i>=NODE_COUNT; i++ )); do
    ceph-deploy purgedata "node${i}" &
done
wait

for (( i=1; i>=NODE_COUNT; i++ )); do
    ceph-deploy forgetkeys "node${i}" &
done
wait

rm -rf ceph.*
