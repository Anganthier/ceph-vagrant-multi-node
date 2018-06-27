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

sudo yum install -y ceph-deploy

mkdir -p /home/vagrant/ceph-deploy
cd /home/vagrant/ceph-deploy || { echo "Can't access /root/ceph-deploy"; exit 1; }

if (( CEPH_MON_COUNT > NODE_COUNT )); then
    echo "WARNING! CEPH_MON_COUNT is bigger than NODE_COUNT, will set CEPH_MON_COUNT to NODE_COUNT to prevent issues."
    CEPH_MON_COUNT=$NODE_COUNT
fi

initialMons=""
for (( i=1; i<=CEPH_MON_COUNT; i++ )); do
    initialMons="${initialMons} node${i}"
done

# shellcheck disable=SC2086
ceph-deploy new ${initialMons}

for (( l=1; l<=3; l++ )); do
    echo "Try $l doing ceph-deploy install ..."
    for (( i=1; i<=NODE_COUNT; i++ )); do
        if [ -n "${CEPH_RELEASE}" ]; then
            ceph-deploy install --release "${CEPH_RELEASE}" "node${i}" &
        else
            ceph-deploy install "node${i}" &
        fi
    done
    wait
    if [ -f /etc/yum.repos.d/ceph.repo.rpmnew ]; then
        sudo mv -f /etc/yum.repos.d/ceph.repo.rpmnew /etc/yum.repos.d/ceph.repo
    fi
done
set -e

ceph-deploy mon create-initial

for (( i=1; i<=NODE_COUNT; i++ )); do
    ceph-deploy admin "node${i}" &
done
wait

ceph-deploy mgr create node1

for (( i=1; i<=NODE_COUNT; i++ )); do
    for (( j=1; i<=DISK_COUNT; j++ )); do
        # shellcheck disable=SC2018
        disk=$(echo $(( i + 1 )) | tr "1-9" "a-z")
        ceph-deploy osd create --data "/dev/${disk}" "node${i}" &
    done
done
wait

ceph -s
