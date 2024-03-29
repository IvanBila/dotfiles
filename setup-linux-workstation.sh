#!/bin/bash

echo "Commencing Setup"

sudo apt update -y && sudo apt upgrade -y
sudo apt install xclip git curl tmux apache2 net-tools ubuntu-restricted-extras software-properties-common build-essential openssl apt-transport-https wget vim -y
sudo apt-get install neofetch

# Install Communication and Productivity apps Via Snap
sudo apt install snapd
sudo snap install skype --classic
sudo snap install postman
sudo snap install vlc
sudo snap install lolcat
sudo snap install slack --classic
sudo snap install teams-for-linux
sudo snap install discord --classic
sudo snap install chromium


# Fonts
cd ~/Downloads
git clone https://github.com/ZulwiyozaPutra/SF-Mono-Font.git
cd SF-Mono-Font
mkdir -p ~/.local/share/fonts
mv *.otf ~/.local/share/fonts

fc-cache -f -v


# JAVA
sudo update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/jdk1.8/bin/java" 0
sudo update-alternatives --install "/usr/bin/javac" "javac" "/usr/lib/jvm/jdk1.8/bin/javac" 0
sudo update-alternatives --set java /usr/lib/jvm/jdk1.8/bin/java
sudo update-alternatives --set javac /usr/lib/jvm/jdk1.8/bin/javac


# Android ADB & FastBoot
sudo apt install android-tools-adb android-tools-fastboot


# https://www.vultr.com/docs/how-to-manually-install-java-8-on-ubuntu-16-04
# https://linuxize.com/post/how-to-set-and-list-environment-variables-in-linux/
#https://askubuntu.com/questions/175514/how-to-set-java-home-for-java
# https://linuxize.com/post/how-to-install-apache-maven-on-ubuntu-18-04/
# https://websiteforstudents.com/manually-install-oracle-java-jdk-12-on-ubuntu-18-04-16-04/
# https://stackoverflow.com/questions/12787757/how-to-use-the-command-update-alternatives-config-java
# https://askubuntu.com/questions/492029/update-alternatives-install-says-it-needs-link-name-path-priority
# https://dev.to/thegroo/install-and-manage-multiple-java-versions-on-linux-using-alternatives-5e93


# NVM 
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

nvm install 8
nvm install 10
nvm install 12
nvm install 13
nvm install 14
nvm install 15
nvm use 14


# BROWSERS
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install ./google-chrome-stable_current_amd64.deb 
sudo apt install chromium-browser
sudo apt-get install fonts-powerline
sudo apt install firefox

# RVM
gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
\curl -sSL https://get.rvm.io | bash -s stable --ruby

# Yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update
sudo apt install yarn -y
yarn --version


# Ruby
sudo apt install ruby-full
ruby --version


# PHP
sudo apt install software-properties-common
sudo add-apt-repository ppa:ondrej/php
sudo apt install php7.4 php7.4-common php7.4-opcache php7.4-cli php7.4-gd php7.4-curl php7.4-mysql -y
sudo apt-get install -y php7.4 libapache2-mod-php7.4 php7.4-bcmath php7.4-xmlrpc php7.4-bz2 php7.4-soap php7.4-cli php7.4-common php7.4-mbstring php7.4-gd php7.4-intl php7.4-xml php7.4-mysql php7.4-mcrypt php7.4-zip php7.4-zip openssl php-common php-curl php-json php-mbstring php-mysql php-xml php-zip
sudo apt install openssl php-common php-curl php-json php-mbstring php-mysql php-xml php-zip

# PHP REPL
cd ~ && wget https://psysh.org/psysh && sudo mv psysh /bin/psysh

# Composer Alternative
 composer g require psy/psysh:@stable 

# COMPOSER
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
HASH="$(wget -q -O - https://composer.github.io/installer.sig)"
php -r "if (hash_file('SHA384', 'composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
composer --version

# LARAVEL
composer global require laravel/installer

# Golang
sudo add-apt-repository ppa:longsleep/golang-backports
sudo apt update
sudo apt install golang-go

# Gradle
wget https://services.gradle.org/distributions/gradle-5.0-bin.zip -P /tmp
sudo unzip -d /opt/gradle /tmp/gradle-*.zip
ls /opt/gradle/gradle-5.0
sudo nano /etc/profile.d/gradle.sh
export GRADLE_HOME=/opt/gradle/gradle-5.0
export PATH=${GRADLE_HOME}/bin:${PATH}
sudo chmod +x /etc/profile.d/gradle.sh
source /etc/profile.d/gradle.sh
gradle -v


# Ubuntu version
lsb_release -a
lsb_release -d
cat /etc/issue
cat /etc/os-release
hostnamectl

# PIP3
sudo apt update
sudo apt install software-properties-common
sudo apt install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libsqlite3-dev libreadline-dev libffi-dev wget
sudo apt-get install -y python3-pip

# Text Editors
# ATOM
wget -q https://packagecloud.io/AtomEditor/atom/gpgkey -O- | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main"
sudo apt install atom

# VSCODE
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
sudo apt install code

# SUBLIME
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
sudo apt-get install apt-transport-https
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
sudo apt-get update -y
sudo apt-get install sublime-text

# TELEGRAM
wget https://updates.tdesktop.com/tlinux/tsetup.1.1.23.tar.xz
tar -xf tsetup.1.1.23.tar.xz 
cd Telegram/
sudo mv Telegram /opt/telegram
sudo ln -sf /opt/telegram/Telegram /usr/bin/telegram

# SIGNAL
curl -s https://updates.signal.org/desktop/apt/keys.asc | sudo apt-key add -
echo "deb [arch=amd64] https://updates.signal.org/desktop/apt xenial main" | sudo tee -a /etc/apt/sources.list.d/signal-xenial.list
sudo apt update && sudo apt install signal-desktop

# ZSH
chsh -s $(which zsh)

# Install Myserver
sudo apt install mysql-server -y

# Install MariaDB
sudo apt install mariadb-server

# Mycli MYSQL/MariaDB client
sudo apt-get install mycli

# Uninstall Mysql 
sudo apt-get purge mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*
sudo rm -rf /etc/mysql /var/lib/mysql
sudo apt-get autoremove
sudo apt-get autoclean

# Set PHP version manually

## Apache
sudo a2dismod php5.6
sudo a2enmod php7.3
sudo service apache2 restart

## Command Line
sudo update-alternatives --set php /usr/bin/php7.3
sudo update-alternatives --set phar /usr/bin/phar7.3
sudo update-alternatives --set phar.phar /usr/bin/phar.phar7.3
sudo update-alternatives --set phpize /usr/bin/phpize7.3
sudo update-alternatives --set php-config /usr/bin/php-config7.3
