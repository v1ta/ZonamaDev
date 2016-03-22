# ZonamaDev

Zonama - The living planet, or in our world an easily deployed development environment for working on the server code of swgemu's Core3 (https://www.swgemu.com/)

## Windows Host

#### Minimum requirements
- Virtualization enabled cpu (Check your BIOS if virtualbox fails to boot box)
- 64 Bit Host
- 2 Host Cores
- 6 Gigs Host Ram
- Dynamically sized 40G HD (Approx 15G on first boot) (Usually $HOME/ZonamaDev)
- 2.5Gb in your $HOME directory for base box image (On windows this is usually C:\ )
- **Guest must be configured for at least 2Gb Ram, 128Mb Video Memory and 2 Cores**

### Fast Start

#### Downloads
* [Github's Git for Windows](https://git-for-windows.github.io)
* [VirtualBox for Windows](https://www.virtualbox.org/wiki/Downloads)
* [Vagrant for Windows](https://www.vagrantup.com/downloads.html)
 
#### Bootstrap
Launch Git Bash: Start -> Programs -> Git Bash
or
Right click in desired directory -> Git Bash

Type:
````
curl -L http://downloads.lordkator.com/bootstrap.sh | bash
````

Watch for instructions.

#### Hard way

Type:
````
git clone https://github.com/lordkator/ZonamaDev.git
cd ZonamaDev/fasttrack
./setup.sh
````

Watch for instructions.

---

## Linux Host

### Linux mint 17.3 / Ubuntu 14.04
First install git, curl, and zlib1g-dev via
````
sudo apt-get install git curl zlib1g-dev
````
Next install Vagrant and VirtualBox through their websites:
````
[VirtualBox for Linux](https://www.virtualbox.org/wiki/Linux_Downloads)
[Vagrant for Linux](https://www.vagrantup.com/downloads.html)
````
* Virtualbox - Choose linux version (use 14.04 ubuntu as Linux Mint is based on 14.04)
* Vagrant download the debian package for vagrant.  (The versions in the apt-get repos are older, and unsupported for ZonamaDev)

Install downloaded packages:
````
sudo dpkg -i <pathtofile>/<nameoffile>
````
Type:
````
curl -L http://downloads.lordkator.com/bootstrap.sh | bash
````
Watch for error messages, and resolve any unmet dependancy problems.  Each distro of linux has different versions:
For example, on Debian Testing (Stretch) install should be able to do apt-get virtualbox and vagrant.

---

### Updates

The system should update on reboot, please reboot the vm:

* via the applications menu "Loggout -> Restart"
* via host control: vagrant reload
* via terminal: sudo init 6

### Advanced Featues

#### DESTROY AND START FRESH

To uninstall and re-install fresh on the host system type:

````
curl -L http://downloads.lordkator.com/bootstrap.sh | bash -s destroy
````


#### UNINSTALL

To uninstall on the host system type:

````
curl -L http://downloads.lordkator.com/bootstrap.sh | bash -s uninstall
````

#### Local config for core and ram

On the host (usually Windows or OSX) in the ~/ZonamdaDev/fasttrack directory you can create a simple YAML file that sets cores and/or ram:

Example config.yml:
```yaml
cores: 8
ram: 8192
```
The config.yml is ignored in .gitignore so you can "set it and forget it".

You can also setup a "bridged" network interface if you want the server to be directly on your LAN:

````yaml
bridge: "auto"
```

Under windows you can do 'auto' and it usually picks the right interface on OSX you will need to choose the right
interface often "en0":

````yaml
bridge: "en0"
```

The next time you do vagrant reload or vagrant up these settings will take effect.

### For More Information

Please see [The Wiki](https://github.com/lordkator/ZonamaDev/wiki)
