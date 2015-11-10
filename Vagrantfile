# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.
  config.vm.synced_folder ".", "/build/pkgs/"

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "ubuntu/trusty64"
  config.vm.provider "virtualbox" do |v|
    v.name = "pibuilder"
    v.memory = 2048
    v.cpus = 4
  end
  
  config.vm.provision "shell", inline: <<-SHELL
     apt-get update
     apt-get install -y build-essential git  debootstrap  qemu-user-static  kpartx whois dosfstools tmux wget ntp  binfmt-support qemu qemu-user-static lvm2 apt-cacher-ng unzip
  SHELL
end
