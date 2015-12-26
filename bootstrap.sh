#!/bin/bash

if [ -z "$BASH_VERSION" ]; then
    echo "** MUST RUN FROM bash, please run again from bash! **"
    exit
fi

main() {
    OS='unknown'

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
	eval install_git_$OS()
    fi

    ## Clone Repo
    git clone https://github.com/lordkator/ZonamaDev.git

    ## hand off to next script
    cd ZonamaDev/fasttrack
    exec ./setup.sh < /dev/tty

    echo "** Something went wrong, get help **"
    exit 11
}

install_git_win() {
    echo "Please download and install git-for-windows at: https://git-for-windows.github.io/"
    echo "When that is complete, please use Git Bash shell to run this script again"
    exit 0
}

install_git_osx() {
    echo "Please download XCode for OSX at: https://developer.apple.com/xcode/downloads/"
    open https://developer.apple.com/xcode/downloads/
    echo "When that is complete, please restart this script."
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

main

exit 0
