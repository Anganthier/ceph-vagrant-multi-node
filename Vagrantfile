# Box setup
BOX_IMAGE = ENV['BOX_IMAGE'] || 'centos/7'.freeze

i = ENV['NODE'].to_i || 1
NODE_COUNT = ENV["NODE_COUNT"].to_i || 1

# Disk setup
DISK_COUNT = ENV['DISK_COUNT'].to_i || 1
DISK_SIZE_GB = ENV['DISK_SIZE_GB'].to_i || 10
# Resources
NODE_CPUS = ENV['NODE_CPUS'].to_i || 1
NODE_MEMORY_SIZE_GB = ENV['NODE_MEMORY_SIZE_GB'].to_i || 1
# Network
NODE_IP_NW = ENV['NODE_IP_NW'] || '192.168.25.'.freeze
NODE_IP = NODE_IP_NW + (i + 10).to_s

# Generate new using steps in README
CEPH_RELEASE = ENV['CEPH_RELEASE'] || ''.freeze
CEPH_MON_COUNT = ENV['CEPH_MON_COUNT'] || ''.freeze

$baseInstallScript = <<SCRIPT

set -x

yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

if [ -n "#{CEPH_RELEASE}" ]; then
    CEPH_REPO="rpm-#{CEPH_RELEASE}"
else
    CEPH_REPO="rpm"
fi

cat << EOM > /etc/yum.repos.d/ceph.repo
[ceph-noarch]
name=Ceph noarch packages
baseurl=https://download.ceph.com/$CEPH_REPO/el7/noarch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
EOM
yum update -y
yum install --nogpgcheck -y net-tools screen tree telnet rsync ntp ntpdate

setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=enforcing/g' /etc/selinux/config
swapoff -a
sed -i '/swap/s/^/#/g' /etc/fstab

systemctl stop firewalld && \
    systemctl disable firewalld && \
    systemctl mask firewalld

echo "vagrant ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/vagrant
chmod 0440 /etc/sudoers.d/vagrant
chmod 600 /home/vagrant/.ssh/id_rsa
cat /home/vagrant/.ssh/ceph_authorized_keys >> /home/vagrant/.ssh/authorized_keys

sed -i "/node1/{d;}" /etc/hosts

for i in $(seq 1 #{i}); do
    IP_END_PART=$(( $i + 10 ))
    cat << EOF >> /home/vagrant/.ssh/config
Host node$i
    Hostname #{NODE_IP_NW}$IP_END_PART
    User ceph-deploy
EOF
    echo "#{NODE_IP_NW}$IP_END_PART node$i" | sudo tee --append /etc/hosts
done
chmod 755 /home/vagrant/init-ceph-cluster.sh
# "Copy" all env vars to VMs that are needed later on
cat << EOF > /home/vagrant/.env
export DISK_COUNT=#{DISK_COUNT}
export NODE_COUNT=#{NODE_COUNT}
export CEPH_RELEASE="#{CEPH_RELEASE}"
export NODE=#{i}
export CEPH_MON_COUNT=#{CEPH_MON_COUNT}
EOF
SCRIPT

Vagrant.configure('2') do |config|
    config.vm.box = BOX_IMAGE
    config.vm.box_check_update = true

    config.vm.provider 'virtualbox' do |l|
        l.cpus = NODE_CPUS
        l.memory = NODE_MEMORY_SIZE_GB * 1024
    end

    config.vm.define "node#{i}" do |subconfig|
        subconfig.vm.hostname = "node#{i}"
        subconfig.vm.network :private_network, ip: NODE_IP
        subconfig.vm.provider :virtualbox do |vb|
            # Storage configuration
            if File.exist?(".vagrant/node#{i}-disk-1.vdi")
                vb.customize ['storagectl', :id, '--name', 'SATAController', '--remove']
            end
            vb.customize ['storagectl', :id, '--name', 'SATAController', '--add', 'sata']
            (1..DISK_COUNT.to_i).each do |diskI|
                unless File.exist?(".vagrant/node#{i}-disk-#{diskI}.vdi")
                    vb.customize ['createhd', '--filename', ".vagrant/node#{i}-disk-#{diskI}.vdi", '--variant', 'Standard', '--size', DISK_SIZE_GB * 1024]
                end
                vb.customize ['storageattach', :id, '--storagectl', 'SATAController', '--port', diskI - 1, '--device', 0, '--type', 'hdd', '--medium', ".vagrant/node#{i}-disk-#{diskI}.vdi"]
            end
        end
        subconfig.vm.synced_folder "data/node#{i}/", '/data', type: 'rsync',
                                                              create: true, owner: 'root', group: 'root',
                                                              rsync__args: ["--rsync-path='sudo rsync'", '--archive', '--delete', '-z']
        # Provision
        subconfig.vm.provision :file, source: "data/id_rsa", destination: "/home/vagrant/.ssh/id_rsa"
        subconfig.vm.provision :file, source: "data/id_rsa.pub", destination: "/home/vagrant/.ssh/ceph_authorized_keys"
        subconfig.vm.provision :file, source: "init-ceph-cluster.sh", destination: "/home/vagrant/init-ceph-cluster.sh"
        subconfig.vm.provision :file, source: "reset-ceph-cluster.sh", destination: "/home/vagrant/reset-ceph-cluster.sh"
        subconfig.vm.provision :shell, inline: $baseInstallScript
    end
end
