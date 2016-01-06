# ZonamaDev

Zonama - The living planet, or in our world an easily deployed development environment for working on the server code of swgemu's Core3 (https://www.swgemu.com/)

## ALPHA SIGNUP

Please make an account at: https://atlas.hashicorp.com/account/new

Post an issue with your username to https://github.com/lordkator/ZonamaDev/issues and Kator will get you access.

We expect to open the boxes up this weekend if you want to wait for that.

## Windows Host

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
