#!/bin/bash

set -ex

ceph_deploy_install() {
    local node=$1
    if [ -f "/home/vagrant/.ceph-node-status/node${node}" ]; then
        echo "==> node${node}: ceph-deploy install already done."
        return
    fi
    local l
    for (( l=1; l<=3; l++ )); do
        echo "==> node${node}: Try $l running 'ceph-deploy install' ..."
        if [ -n "${CEPH_RELEASE}" ]; then
            ceph-deploy --overwrite-conf install --release "${CEPH_RELEASE}" "node${node}"
            rc=$?
        else
            ceph-deploy --overwrite-conf install "node${node}"
            rc=$?
        fi
        # shellcheck disable=SC2181
        if [[ $rc == 0 ]]; then
            echo "ceph-deploy install succeeded! Breaking loop."
            touch "/home/vagrant/.ceph-node-status/node${node}"
            return
        fi
        if [ -e /etc/yum.repos.d/ceph.repo.rpmnew ]; then
            sudo cp -f /etc/yum.repos.d/ceph.repo.rpmnew /etc/yum.repos.d/ceph.repo
        fi
    done
}
ceph_deploy_osd() {
    local node=$1
    local j
    for (( j=1; j<=DISK_COUNT; j++ )); do
        # shellcheck disable=SC2018
        disk=$(echo $(( j + 1 )) | tr "1-9" "a-z")
        if [ "${disk}" = "a" ]; then
            echo "node${node}: SOMETHING WENT WRONG! Disk can't be 'a' as 'a' is the system disk. Exiting here for this node."
            return 1
        fi
        # shellcheck disable=SC2140
        ceph_deploy_osd_create "node${node}:/dev/sd${disk}" &
    done
    wait
}
ceph_deploy_osd_create() {
    echo "$1: 'ceph-deploy osd create' running ..."
    ceph-deploy osd create "$1"
}

# shellcheck disable=SC1091
source /home/vagrant/.env
# These env vars are coming from that file:
# DISK_COUNT
# NODE_COUNT
# CEPH_RELEASE
# NODE
# CEPH_MON_COUNT
# CEPH_RBD_CREATE
# CEPH_RBD_POOL_PG
# CEPH_RBD_POOL_SIZE

sudo yum install -y ceph-deploy

mkdir -p /home/vagrant/.ceph-node-status

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

if [ -z "$(ls -A /home/vagrant/ceph-deploy)" ]; then
    # shellcheck disable=SC2086
    ceph-deploy new ${initialMons}
fi

set +e
for (( i=1; i<=NODE_COUNT; i++ )); do
    ceph_deploy_install $i &
done
wait
set -e

ceph-deploy --overwrite-conf mon create-initial

for (( i=1; i<=NODE_COUNT; i++ )); do
    ceph-deploy admin "node${i}" &
done
wait

ceph-deploy mgr create node1 || \
    echo "WARNING! Ceph mgr install failed, ignoring as Ceph jewel release does not have mgr and is the default from the 'normal' repos. Continuing ..."

for (( i=1; i<=NODE_COUNT; i++ )); do
    ceph_deploy_osd "$i" &
done
wait

echo "'Correcting' /etc/ceoh permission so every use can access ceph.conf for ease of use ..."
sudo chmod 666 -R /etc/ceph/
sudo chmod 777 /etc/ceph/

ceph osd pool delete rbd rbd --yes-i-really-really-mean-it
if [ "$CEPH_RBD_CREATE" = "true" ]; then
    ceph osd pool create rbd "$CEPH_RBD_POOL_PG" "$CEPH_RBD_POOL_PG" replicated
    # check if 'ceph osd pool application enable' is available and
    # if so enable rbd application on 'rbd' pool
    set +e
    ceph osd pool application enable > /dev/null 2>&1
    rc=$?
    set -e
    if (( rc != 22 )); then
        ceph osd pool application enable rbd rbd
    fi
    ceph osd pool set set rbd min_size 1
    ceph osd pool set set rbd size "$CEPH_RBD_POOL_SIZE"
fi

sudo ceph -s
echo "'ceph -s' exited with $?. Done."
