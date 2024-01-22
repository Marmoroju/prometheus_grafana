Vagrant.configure("2") do |config|
    config.vm.define "prometheus" do |prometheus|
        prometheus.vm.box = "centos/7"
        prometheus.vm.network "private_network", ip: "192.168.56.8"
        prometheus.vm.provision "shell", path: "provision.sh"
        prometheus.vm.provider "virtualbox" do |v|
            v.memory = 1024
            v.cpus = 2
        end
    end    
end    