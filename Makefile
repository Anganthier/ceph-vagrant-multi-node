MFILECWD = $(shell pwd)

# === BEGIN USER OPTIONS ===
# Box setup
BOX_IMAGE ?= centos/7
# Disk setup
DISK_COUNT ?= 1
DISK_SIZE_GB ?= 10
# VM Resources
NODE_CPUS ?= 1
NODE_MEMORY_SIZE_GB ?= 1

NODE_COUNT ?= 3
# Network
NODE_IP_NW ?= 192.168.25.

CLUSTER_NAME ?= $(shell basename $(MFILECWD))

# Ceph
CEPH_RELEASE ?=
CEPH_MON_COUNT ?= 3
CEPH_RBD_CREATE ?= true
CEPH_RBD_POOL_PG ?= 64
CEPH_RBD_POOL_SIZE ?= 3
# === END USER OPTIONS ===

preflight: ssh-keygen

ssh-keygen: ## Generate ssh key for `ceph-deploy` command used for the actual Ceph cluster deployment.
	if [ ! -f "$(MFILECWD)/data/id_rsa" ]; then \
		ssh-keygen -f "$(MFILECWD)/data/id_rsa" -t rsa -b 2048 -N ''; \
	fi

# Readd preflight
up: preflight start-nodes ## Start Ceph Vagrant multi-node cluster. Creates, starts and bootsup the node VMs.
	make init-ceph-cluster

init-ceph-cluster: ## Run the init-ceph-cluster.sh script to deploy the Ceph cluster (automatically done by `up` target).
	echo 'source /home/vagrant/.env && /home/vagrant/init-ceph-cluster.sh' | make ssh-node-1

reset-ceph-cluster: ## Run "Starting Over" commands to "reset" the Ceph cluster.
	echo 'source /home/vagrant/.env && /home/vagrant/reset-ceph-cluster.sh' | make ssh-node-1

start-nodes: $(shell for i in $(shell seq 1 $(NODE_COUNT)); do echo "start-node-$$i"; done) ## Create and start all node VMs by utilizing the `node-X` target (automatically done by `up` target).

start-node-%: ## Start node VM, where `%` is the number of the node.
	NODE=$* vagrant up

stop: $(shell for i in $(shell seq 1 $(NODE_COUNT)); do echo "stop-node-$$i"; done) ## Stop/Halt all nodes VMs.

stop-node-%: ## Stop/Halt a node VM, where `%` is the number of the node.
	NODE=$* vagrant halt -f

stop-nodes: $(shell for i in $(shell seq 1 $(NODE_COUNT)); do echo "stop-node-$$i"; done) ## Stop/Halt all node VMs.

ssh-node-%: ## SSH into a node VM, where `%` is the number of the node.
	NODE=$* vagrant ssh

ceph-status: ## Runs `ceph -s` inside the first node to return the Ceph cluster status.
	echo "ceph -s" | make ssh-node-1

clean: $(shell for i in $(shell seq 1 $(NODE_COUNT)); do echo "clean-node-$$i"; done) clean-data ## Destroy node VMs, and delete data.

clean-node-%: ## Remove a node VM, where `%` is the number of the node.
	-NODE=$* vagrant destroy -f node$*

clean-nodes: $(shell for i in $(shell seq 1 $(NODE_COUNT)); do echo "clean-node-$$i"; done) ## Remove all node VMs.

clean-data: ## Remove data (shared folders) and disks of all VMs (nodes).
	rm -rf "$(PWD)/data/*"
	rm -rf "$(PWD)/.vagrant/id_rsa*"
	rm -rf "$(PWD)/.vagrant/*.vdi"

status-node-%: ## Show status of a node VM, where `%` is the number of the node.
	@STATUS_OUT="$$(NODE=$* vagrant status | tail -n+3)"; \
		if (( $$(echo "$$STATUS_OUT" | wc -l) > 5 )); then \
			echo "$$STATUS_OUT" | head -n-5; \
		else \
			echo "$$STATUS_OUT" | head -n-2; \
		fi

status-nodes: $(shell for i in $(shell seq 1 $(NODE_COUNT)); do echo "status-node-$$i"; done) ## Show status of all node VMs.

help: ## Show this help menu.
	@grep -E '^[a-zA-Z_-%]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
.EXPORT_ALL_VARIABLES:
.PHONY: ceph-status clean clean-data clean-nodes help ssh-keygen start-nodes status-nodes status \
	stop-nodes stop preflight up
