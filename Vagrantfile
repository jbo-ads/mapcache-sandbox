Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp/bionic64"
  config.vm.hostname = "mapcache-sandbox"
  config.vm.synced_folder ".", "/share", type: "virtualbox",
    mount_options: ["dmode=777,fmode=777"]
  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.network "forwarded_port", guest: 9200, host: 9292
  config.vm.provider "virtualbox" do |v|
    v.name = "mapcache-sandbox"
    v.memory = 4096
    v.cpus = 2
  end

  config.vm.provision "shell",                path: "provision/dependencies.sh"

  config.vm.provision "shell", run: "always", path: "provision/openlayers.sh"
  config.vm.provision "shell", run: "always", path: "provision/mapcache.sh"
  config.vm.provision "shell", run: "always", path: "provision/mapcache-test.sh"
  config.vm.provision "shell", run: "always", path: "provision/mapcache-source.sh"

  config.vm.provision "shell", run: "always", path: "provision/apache.sh"

end
