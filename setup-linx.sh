#!/bin/bash

echo "Commecing stup"



# 1. Install basic programs

sudo apt update
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
sudo apt-get install apt-transport-https
sudo echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
sudo apt update
sudo apt-get install sublime-text -y
sudo apt install zip zsh gnome-tweaks git curl vim -y
ssh-keygen -t rsa -b 4096 -C "$EMAIL"

# 2. Setup Oh my Zsh


# 3. Install NVM


# 4. Install PHP
