#!/bin/bash

if [ -z "$BASH_VERSION" ]; then
    echo "** MUST RUN FROM bash, please run again from bash! **"
    exit
fi

OS='unknown'

main() {
    case $HOME in
	*' '* )
	    echo
	    echo 'Your $HOME has spaces in it:'
	    echo
	    echo "  HOME=[$HOME]"
	    echo
	    echo 'Vagrant is based on Ruby which has issues with spaces in $HOME'
	    echo
	    echo 'In order to use this system you must have a username without spaces'
	    echo 'or you must manually override HOME to a directory without spaces.'
	    echo
	    echo 'You could try working around this by doing the following:'
	    echo
	    echo '  mkdir /c/swgemudev'
	    echo '  export HOME=/c/swgemudev'
	    echo '  cd $HOME'
	    echo '  curl -L http://downloads.lordkator.com/bootstrap.sh | bash'
	    echo
	    echo 'However, every time you want to work with this system you will need to reset'
	    echo 'your HOME when you open the bash shell window.'
	    echo
	    echo '** Process aborted, Spaces in HOME **'
	    exit 13
	    ;;
    esac

    case $(uname -s) in
	Darwin ) OS='osx' ;;
	*Linux* ) OS='linux' ;;
	*_NT* ) OS='win';;
	* ) echo "Not sure what OS you are on, guessing Windows"; OS='win';;
    esac

    ## Check for git
    if git --version > /dev/null 2>&1; then
	:
    else
	eval install_git_$OS
    fi

    echo "** Checking for VirtualBox **"
    check_virtualbox_$OS

    echo "** Checking for Vagrant **"
    check_vagrant_$OS

    ## Clone Repo
    if git clone https://github.com/lordkator/ZonamaDev.git; then
	:
    else
	case $PWD in
	*ZonamaDev* ) : ;;
	* ) echo "** Something is wrong, did you try and run this in the right directory? **"
	    echo "** We suggest you run it from $HOME **"
	    exit 1
	    ;;
	esac

	if git pull; then
	    :
	else
	    echo "** Failed to clone too, you might need help!"
	    exit 1
	fi
    fi

    ## hand off to next script
    cd ${PWD/ZonamaDev*/}"/ZonamaDev/fasttrack"

    echo "** Running in $PWD **"

    exec ./setup.sh

    echo "** Something went wrong, get help **"

    exit 11
}

install_git_win() {
    echo "** Please download and install git-for-windows at: https://git-for-windows.github.io/"
    echo "** When that is complete, please use Git Bash shell to run this script again"
    exit 0
}

install_git_osx() {
    echo "** Please download XCode for OSX at: https://developer.apple.com/xcode/downloads/"
    open https://developer.apple.com/xcode/downloads/
    echo "** When that is complete, please restart this script."
    exit 0
}

install_git_linux() {
    # Assume deb for now?
    sudo apt-get install git < /dev/tty

    if git --version > /dev/null 2>&1; then
	:
    else
	echo "** Failed to install git, **ABORT**"
	exit 12
    fi
}

check_gitbash_win() {
    echo "TODO check git bash version"
}

check_virtualbox_win() {
    if [ -z "$VBOX_INSTALL_PATH" -a -z "$VBOX_MSI_INSTALL_PATH" ]; then
	echo -e "** You need to install VirtualBox for windows **\n"

	if yorn "Would you like me to take you to: https://www.virtualbox.org/wiki/Downloads?"; then
	    explorer "https://www.virtualbox.org/wiki/Downloads"
	fi

	echo "** Please close this window, install VirtualBox, REBOOT and try again **"
	exit 1
    fi
}

check_vagrant_win() {
    local ver=$(vagrant --version | cut -d' ' -f2 2> /dev/null)

    if [ -z "$ver" ]; then
	echo -e "** You need to install Vagrant **\n"

	if yorn "Would you like me to take you to: https://www.vagrantup.com/downloads.html?"; then
	    explorer "https://www.vagrantup.com/downloads.html"
	fi

	echo "** Please close this window, install Vagrant and try again **"
	exit 1
    fi

    echo "** Vagrant version $ver **"
}

yorn() {
  if tty -s; then
      echo -n -e "$@ Y\b" > /dev/tty
      read yorn < /dev/tty
      case $yorn in
	[Nn]* ) return 1;;
      esac
  fi

  return 0
}

main < /dev/tty

exit 0
