# Homelabs 4-node Debian cluster (bridged, /22)
# Requires: VirtualBox, Vagrant
# Optional: vagrant-disksize plugin for 32GB disks:
#   vagrant plugin install vagrant-disksize

NETMASK  = "255.255.252.0"  # /22 (192.168.4.0–192.168.7.255)
GATEWAY  = "192.168.4.1"
DNS      = ["8.8.8.8", "8.8.4.4"]

NODES = [
  {name: "master",  ip: "192.168.5.200", cpu: 2, ram: 4096},
  {name: "worker1", ip: "192.168.5.201", cpu: 2, ram: 4096},
  {name: "worker2", ip: "192.168.5.202", cpu: 2, ram: 4096},
  {name: "worker3", ip: "192.168.5.203", cpu: 2, ram: 4096},
]

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Make sure vbguest (if present) doesn't interfere
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
    config.vbguest.no_remote = true
  end

  NODES.each do |node|
    config.vm.define node[:name] do |vm|
      vm.vm.hostname = node[:name]

      # Bridged NIC with static IP on /22
      vm.vm.network :public_network,
        ip: node[:ip],
        netmask: NETMASK,
        bridge: "en2: Wi-Fi (AirPort)"   # using your host NIC on 192.168.4.0/22

      vm.vm.provider :virtualbox do |vb|
        vb.name   = "hlab-#{node[:name]}"
        vb.cpus   = node[:cpu]
        vb.memory = node[:ram]
        vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
      end

      # 32 GB disk via plugin (comment if you don't use the plugin)
      if Vagrant.has_plugin?("vagrant-disksize")
        vm.disksize.size = "32GB"
      end

      vm.vm.provision "shell", privileged: true, inline: <<-SHELL
        set -euo pipefail
        apt-get update -y
        apt-get install -y curl ca-certificates gnupg lsb-release jq net-tools iproute2

        # K8s-friendly sysctls (safe even if you don't install k3s yet)
        swapoff -a || true
        sed -i.bak '/ swap / s/^/#/' /etc/fstab || true
        modprobe br_netfilter || true
        sysctl -w net.ipv4.ip_forward=1
        echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-ipforward.conf
        echo 'net.bridge.bridge-nf-call-iptables=1' > /etc/sysctl.d/99-k8s.conf
        sysctl --system

        # Make bridged NIC the default route (optional but recommended here)
        IFACE=$(ip -o -4 addr show | awk '/192\\.168\\.(4|5|6|7)\\./ {print $2; exit}')
        if [ -n "$IFACE" ]; then
          ip route del default || true
          ip route add default via #{GATEWAY} dev "$IFACE"
        fi

        # DNS via systemd-resolved
        mkdir -p /etc/systemd/resolved.conf.d
        cat >/etc/systemd/resolved.conf.d/99-custom-dns.conf <<EOF
[Resolve]
DNS=#{DNS.join(" ")}
FallbackDNS=
Domains=
MulticastDNS=no
LLMNR=no
DNSSEC=no
EOF
        systemctl restart systemd-resolved || true
      SHELL

      # Copy your SSH public key for direct SSH access
      ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_rsa.pub").first.strip rescue nil
      ssh_pub_key ||= File.readlines("#{Dir.home}/.ssh/id_ed25519.pub").first.strip rescue nil
      
      if ssh_pub_key
        vm.vm.provision "shell", privileged: false, inline: <<-SHELL
          echo "Adding your SSH public key to authorized_keys..."
          mkdir -p ~/.ssh
          chmod 700 ~/.ssh
          echo '#{ssh_pub_key}' >> ~/.ssh/authorized_keys
          chmod 600 ~/.ssh/authorized_keys
        SHELL
        
        vm.vm.provision "shell", privileged: true, inline: <<-SHELL
          echo "Adding your SSH public key to root authorized_keys..."
          mkdir -p /root/.ssh
          chmod 700 /root/.ssh
          echo '#{ssh_pub_key}' >> /root/.ssh/authorized_keys
          chmod 600 /root/.ssh/authorized_keys
        SHELL
      end
    end
  end
end

