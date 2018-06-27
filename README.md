# ceph-vagrant-multi-node

## Prerequisites
* `make`
* Vagrant (tested with `2.1.1`)
* Virtualbox
* `rsync`
* `ssh-keygen`

## Hardware Requirements
* Per Node (default 3 are started):
    * CPU: 1 Core
    * Memory: 1GB

## Quickstart
To start with the defaults, 3x nodes, run the following:
```
$ make up -j 3
```
The `-j3` will cause three VMs to be started in parallel to speed up the Ceph cluster creation.

```
$ make ssh-node1
$ ceph -s
TODO
```

## Usage
### Starting the environment
To start up the Vagrant Ceph multi node environment with the default of **three** nodes (not parallel) run:
```
$ make up
```

### Faster (parallel) environment start
To start up 3 VMs in parallel run (`-j` flag does not control how many (worker) VMs are started, the `NODE_COUNT` variable is used for that):
```
$ NODE_COUNT=3 make up -j3
```
The flag `-j CORES/THREADS` allows yout to set how many VMs (Makefile targets) will be run at the same time.
You can also use `-j $(nproc)` to start as many VMs as cores/threads you have in your machine.
So to start up all VMs (three nodes) in parallel, you would add one to the chosen `NODE_COUNT`.

### Show status of VMs
```
$ make status
node1                     not created (virtualbox)
node2                     not created (virtualbox)
node3                     not created (virtualbox)
```

### Shutting down the environment
To destroy the Vagrant environment run:
```
$ make clean
```

### Data inside VM
See the `data/VM_NAME/` directories, where `VM_NAME` is for example `node1`.

### Show `make` targets
```
$ make help
clean-data                     Remove data (shared folders) and disks of all VMs (nodes).
clean-node-%                   Remove a node VM, where `%` is the number of the node.
clean-nodes                    Remove all node VMs.
clean                          Destroy node VMs, and delete data.
help                           Show this help menu.
init-ceph-cluster              Run the init-ceph-cluster.sh script to deploy the Ceph cluster (automatically done by `up` target).
reset-ceph-cluster             Run "Starting Over" commands to "reset" the Ceph cluster.
ssh-keygen                     Generate ssh key for `ceph-deploy` command used for the actual Ceph cluster deployment.
ssh-node-%                     SSH into a node VM, where `%` is the number of the node.
start-nodes                    Create and start all node VMs by utilizing the `node-X` target (automatically done by `up` target).
start-node-%                   Start node VM, where `%` is the number of the node.
status-node-%                  Show status of a node VM, where `%` is the number of the node.
status-nodes                   Show status of all node VMs.
stop-nodes                     Stop/Halt all node VMs.
stop-node-%                    Stop/Halt a node VM, where `%` is the number of the node.
stop                           Stop/Halt all nodes VMs.
up                             Start Ceph Vagrant multi-node cluster. Creates, starts and bootsup the node VMs.
```

## Variables
| Variable Name         | Default Value | Description                                              |
| --------------------- | ------------- | -------------------------------------------------------- |
| `BOX_IMAGE`           | `centos/7`    | Set the VMs box image to use.                            |
| `DISK_COUNT`          | `1`           | Set how many additional disks will be added to the VMs.  |
| `DISK_SIZE_GB`        | `10` GB       | Size of additional disks added to the VMs.               |
| `NODE_MEMORY_SIZE_GB` | `1` GB        | Size of memory (in GB) to be allocated for each node VM. |
| `NODE_COUNT`          | `2`           | How many worker nodes should be spawned.                 |
