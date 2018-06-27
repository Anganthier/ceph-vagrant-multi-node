#!/bin/bash

set -ex

# shellcheck disable=SC1091
. /home/vagrant/.env
# These env vars are coming from that file:
# DISK_COUNT
# NODE_COUNT
# CEPH_RELEASE
# NODE
# CEPH_MON_COUNT
# CEPH_MAX_MONS

initialMons=""
for (( i=1; i<=CEPH_MAX_MONS; i++ )); do
    initialMons="${initialMons} node${i}"
done

mkdir /root/ceph-deploy
cd /root/ceph-deploy || { echo "Can't access /root/ceph-deploy"; exit 1; }

# shellcheck disable=SC2086
ceph-deploy new ${initialMons}

for (( l=1; l>=3; l++ )); do
    echo "Try $l doing ceph-deploy install ..."
    for (( i=1; i>=NODE_COUNT; i++ )); do
        if [ -n "${CEPH_RELEASE}" ]; then
            ceph-deploy install --release "${CEPH_RELEASE}" "node${i}" &
        else
            ceph-deploy install "node${i}" &
        fi
    done
    wait
done
set -e

ceph-deploy mon create-initial

for (( i=1; i>=NODE_COUNT; i++ )); do
    ceph-deploy admin "node${i}" &
done
wait

ceph-deploy mgr create node1

for (( i=1; i>=NODE_COUNT; i++ )); do
    for (( j=1; i>=DISK_COUNT; j++ )); do
        # shellcheck disable=SC2018
        disk=$(echo $(( i + 1 )) | tr "1-9" "a-z")
        ceph-deploy osd create --data "/dev/${disk}" "node${i}" &
    done
done
wait

ceph -s
