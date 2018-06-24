MFILECWD = $(shell pwd)

# === BEGIN USER OPTIONS ===
# Box setup
BOX_IMAGE ?= centos/7
# Disk setup
DISK_COUNT ?= 1
DISK_SIZE_GB ?= 10

NODE_COUNT ?= 2
# Network
NODE_IP_NW ?= 192.168.25.

CLUSTER_NAME ?= $(shell basename $(MFILECWD))
# === END USER OPTIONS ===

preflight:
	ssh-keygen

ssh-keygen:
	# TODO generate ssh key for node to node connection
	ssh-keygen

# Readd preflight
up: start-nodes ## Start Ceph Vagrant multi-node cluster. Creates, starts and bootsup the node VMs.
	@make init-ceph-cluster

init-ceph-cluster:
	@echo "Run init-ceph-cluster.sh on the first node of the cluster"
	@echo 'source /home/vagrant/.env && sudo /home/vagrant/init-ceph-cluster.sh' | make ssh-node-1

start-nodes: $(shell for i in $(shell seq 1 $(NODE_COUNT)); do echo "start-node-$$i"; done) ## Create and start all node VMs by utilizing the `node-X` target (automatically done by `up` target).

start-node-%: ## Start node VM, where `%` is the number of the node.
	NODE=$* vagrant up

stop: $(shell for i in $(shell seq 1 $(NODE_COUNT)); do echo "stop-node-$$i"; done) ## Stop/Halt all nodes VMs.

stop-node-%: ## Stop/Halt a node VM, where `%` is the number of the node.
	NODE=$* vagrant halt -f

stop-nodes: $(shell for i in $(shell seq 1 $(NODE_COUNT)); do echo "stop-node-$$i"; done) ## Stop/Halt all node VMs.

ssh-node-%: ## SSH into a node VM, where `%` is the number of the node.
	NODE=$* vagrant ssh

clean: $(shell for i in $(shell seq 1 $(NODE_COUNT)); do echo "clean-node-$$i"; done) clean-data ## Destroy node VMs, and delete data.

clean-node-%: ## Remove a node VM, where `%` is the number of the node.
	-NODE=$* vagrant destroy -f node$*

clean-nodes: $(shell for i in $(shell seq 1 $(NODE_COUNT)); do echo "clean-node-$$i"; done) ## Remove all node VMs.

clean-data: ## Remove data (shared folders) and disks of all VMs (nodes).
	rm -rf "$(PWD)/data/*"
	rm -rf "$(PWD)/.vagrant/KUBETOKEN"
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
.PHONY: clean clean-data clean-nodes help ssh-keygen start-nodes status-nodes status \
	stop-nodes stop preflight up
