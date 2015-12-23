# ZonamaDev

Zonama - The living planet, or in our world an easily deployed development environment for working on the server code of swgemu's Core3 (https://www.swgemu.com/)

## Quickstart

Download and install VirtualBox and Vagrant

## Windows Host

### Downloads
* Github's Git for Windows: https://git-for-windows.github.io/
* VirtualBox for Windows: https://www.vagrantup.com/downloads.html
* Vagrant for Windows: https://www.vagrantup.com/downloads.html
 
Launch Git Bash: Start -> Programs -> Git Bash

# Once you have cloned and have a bash shell:

```
git clone https://github.com/lordkator/ZonamaDev.git
vagrant plugin install vagrant-reload
vagrant plugin install vagrant-vbguest
vagrant plugin install vagrant-triggers
cd ZonamaDev
vagrant up
```

Currently this takes about 10 mins on a fairly fast internet connection and nice sized box.

