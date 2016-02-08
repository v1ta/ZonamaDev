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
* Github's Git for Windows: https://git-for-windows.github.io/
* VirtualBox for Windows: https://www.virtualbox.org/wiki/Downloads
* Vagrant for Windows: https://www.vagrantup.com/downloads.html
 
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

### Advanced Featues

#### Local config for core and ram

In the ~/ZonamdaDev/fasttrack directory you can create a simple YAML file that sets cores and/or ram:

Example config.yml:
```yaml
cores: 8
ram: 8192
```
The config.yml is ignored in .gitignore so you can "set it and forget it".

