#!/bin/bash

# shellcheck disable=SC1091
. /home/vagrant/.env
# These env vars are coming from that file:
# DISK_COUNT
# NODE_COUNT
# CEPH_RELEASE
# NODE


env
exit 0

# TODO finish the install of Ceph script
#ceph-deploy new {initial-monitor-node(s)}
# See http://docs.ceph.com/docs/mimic/start/quick-ceph-deploy/.
