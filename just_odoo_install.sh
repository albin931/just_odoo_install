#!/bin/bash
################################################################################
# Script for installing Odoo on Ubuntu 20.04 (could be used for other version too)
# Author: Albin John
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 16.04 server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano just_odoo_install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x just_odoo_install.sh
# Execute the script to install Odoo:
# ./just_odoo_install
################################################################################
OE_USER="odoo14"
# Set the default Odoo port (you still have to use -c $OE_HOME/odoo-server.conf for example to use this.)
OE_PORT="1469"
# Choose the Odoo version which you want to install. For example: 13.0, 12.0, 11.0 or saas-18. When using 'master' the master version will be installed.
# IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 13.0
OE_VERSION="14.0"

CURRENT_USER="$USER"
OE_HOME="/home/$CURRENT_USER/odoo/$OE_USER"
OE_HOME_EXT="/home/$CURRENT_USER/odoo/$OE_USER/${OE_USER}-server"
# The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
# Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
# set the superadmin password
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_USER}-server"

##
###  WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltopdf installed, for a danger note refer to 
## https://github.com/odoo/odoo/wiki/Wkhtmltopdf ):
WKHTMLTOX_X64=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.trusty_amd64.deb
WKHTMLTOX_X32=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.trusty_i386.deb

#--------------------------------------------------
# Update Server
#--------------------------------------------------

echo -e "\n---- Update Server ----"
# universe package is for Ubuntu 18.x
sudo add-apt-repository universe
# libpng12-0 dependency for wkhtmltopdf
sudo add-apt-repository "deb http://mirrors.kernel.org/ubuntu/ xenial main"
sudo apt update
sudo apt upgrade -y

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
sudo apt install postgresql postgresql-server-dev-all -y

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $CURRENT_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
sudo apt install git python3 python3-pip build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng12-0 gdebi -y

sudo apt install python3-lxml
sudo apt install python3-psycopg2
sudo apt install python3-pillow

echo -e "\n---- Installing nodeJS NPM and rtlcss for LTR support ----"
sudo apt install nodejs npm -y
sudo npm install -g rtlcss

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 13 ----"
  #pick up correct one from x64 & x32 versions:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  sudo gdebi --n `basename $_url`
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$(pwd)/$OE_HOME --gecos 'ODOO' --group $CURRENT_USER
# #The user should also be added to the sudo'ers group.
# sudo adduser $CURRENT_USER sudo

sudo chown -R $CURRENT_USER:$CURRENT_USER $OE_HOME

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$OE_USER
sudo chown $CURRENT_USER:$CURRENT_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

echo -e "\n---- Install python packages/requirements ----"
sudo pip3 install -r $OE_HOME_EXT/requirements.txt

echo -e "\n---- Create projects module directory ----"
mkdir $OE_HOME/projects

sudo chown -R $CURRENT_USER:$CURRENT_USER $OE_HOME_EXT

echo -e "* Create server config file"

sudo touch $OE_HOME/${OE_CONFIG}.conf
echo -e "* Creating server config file"
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> $OE_HOME/${OE_CONFIG}.conf"
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> $OE_HOME/${OE_CONFIG}.conf"
sudo su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> $OE_HOME/${OE_CONFIG}.conf"
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> $OE_HOME/${OE_CONFIG}.conf"
sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons\n' >> $OE_HOME/${OE_CONFIG}.conf"
sudo chown $CURRENT_USER:$CURRENT_USER $OE_HOME/${OE_CONFIG}.conf
sudo chmod 640 $OE_HOME/${OE_CONFIG}.conf
