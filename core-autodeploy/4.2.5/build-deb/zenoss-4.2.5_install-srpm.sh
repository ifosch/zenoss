#!/bin/bash
##########################################
# Version: 01a
#  Status: Functional
#   Notes: Testing out 4.2.5
#  Zenoss: Core 4.2.5 (v2070) + ZenPacks
#      OS: Ubuntu 12.04 64-Bit
##########################################

# Beginning Script Message
echo && echo "Welcome to the Zenoss 4.2.5 SRPM to DEB script for Ubuntu!"
echo "Blog Post: http://hydruid-blog.com/?p=343" && echo 
echo "Notes: All feedback and suggestions are appreciated." && echo && sleep 5

# Installer variables
## Home path for the zenoss user
zenosshome="/home/zenoss"
## Download Directory
downdir="/tmp"

# Update Ubuntu
apt-get update && apt-get dist-upgrade -y && apt-get autoremove -y

# Setup zenoss user and build environment
useradd -m -U -s /bin/bash zenoss
chmod 777 $zenosshome/.bashrc
echo 'export ZENHOME=/usr/local/zenoss' >> $zenosshome/.bashrc
echo 'export PYTHONPATH=/usr/local/zenoss/lib/python' >> $zenosshome/.bashrc
echo 'export PATH=/usr/local/zenoss/bin:$PATH' >> $zenosshome/.bashrc
echo 'export INSTANCE_HOME=$ZENHOME' >> $zenosshome/.bashrc
echo 'export PATH=/opt/zenup/bin:$PATH' >> $zenosshome/.bashrc
chmod 644 $zenosshome/.bashrc
mkdir $zenosshome/zenoss425-srpm_install
wget --no-check-certificate -N https://raw.github.com/hydruid/zenoss/master/core-autodeploy/4.2.5/misc/variables.sh -P $zenosshome/zenoss425-srpm_install/
. $zenosshome/zenoss425-srpm_install/variables.sh
mkdir $ZENHOME && chown -cR zenoss:zenoss $ZENHOME

# OS compatibility tests
detect-os && detect-arch && detect-user
if grep -Fxq "Ubuntu 12.04.4 LTS" /etc/issue.net
        then    echo "...Correct OS detected."
else    echo "...Incorrect OS detected, this build script requires Ubuntu 12.04 LTS" && exit 0
fi

# Install Package Dependencies
## Java PPA
apt-get install python-software-properties -y && sleep 1
echo | add-apt-repository ppa:webupd8team/java && sleep 1 && apt-get update
## Install Packages
apt-get install rrdtool libmysqlclient-dev nagios-plugins erlang subversion autoconf swig unzip zip g++ libssl-dev maven libmaven-compiler-plugin-java build-essential libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev oracle-java7-installer python-twisted python-gnutls python-twisted-web python-samba libsnmp-base snmp-mibs-downloader bc rpm2cpio memcached libncurses5 libncurses5-dev libreadline6-dev libreadline6 librrd-dev python-setuptools python-dev erlang-nox -y
pkg-fix
## MySQL Packages
export DEBIAN_FRONTEND=noninteractive
apt-get install mysql-server mysql-client mysql-common -y
mysql-conn_test
pkg-fix

# Download the Zenoss SRPM 
wget -N http://softlayer-ams.dl.sourceforge.net/project/zenoss/zenoss-rc/builds/4.2.5-2070/zenoss_core-4.2.5-2070.el6.src.rpm -P $zenosshome/zenoss425-srpm_install/
cd $zenosshome/zenoss425-srpm_install/ && rpm2cpio zenoss_core-4.2.5-2070.el6.src.rpm | cpio -i --make-directories
bunzip2 zenoss_core-4.2.5-2070.el6.x86_64.tar.bz2 && tar -xvf zenoss_core-4.2.5-2070.el6.x86_64.tar

# Install the Zenoss SRPM
apt-get install librrd-dev -y
tar zxvf /home/zenoss/zenoss425-srpm_install/zenoss_core-4.2.5/externallibs/rrdtool-1.4.7.tar.gz && cd rrdtool-1.4.7/
./configure --prefix=/usr/local/zenoss
make && make install
cd /home/zenoss/zenoss425-srpm_install/zenoss_core-4.2.5/
wget http://dev.zenoss.org/svn/tags/zenoss-4.2.4/inst/rrdclean.sh
## Rabbit install and config
wget -N http://www.rabbitmq.com/releases/rabbitmq-server/v3.2.1/rabbitmq-server_3.2.1-1_all.deb -P $downdir/
dpkg -i $downdir/rabbitmq-server_3.2.1-1_all.deb
chown -R zenoss:zenoss $ZENHOME
rabbitmqctl add_user zenoss zenoss
rabbitmqctl add_vhost /zenoss
rabbitmqctl set_permissions -p /zenoss zenoss '.*' '.*' '.*'
./configure 2>&1 | tee log-configure.log
make 2>&1 | tee log-make.log
make clean 2>&1 | tee log-make_clean.log
cp $zenosshome/zenoss425-srpm_install/variables.sh $zenosshome/zenoss425-srpm_install/zenoss_core-4.2.5/
cp mkzenossinstance.sh mkzenossinstance.sh.orig
su - root -c "sed -i 's:# configure to generate the uplevel mkzenossinstance.sh script.:# configure to generate the uplevel mkzenossinstance.sh script.\n#\n#Custom Ubuntu Variables\n. variables.sh:g' /home/zenoss/zenoss425-srpm_install/zenoss_core-4.2.5/mkzenossinstance.sh"
./mkzenossinstance.sh 2>&1 | tee log-mkzenossinstance_a.log
./mkzenossinstance.sh 2>&1 | tee log-mkzenossinstance_b.log
chown -R zenoss:zenoss /usr/local/zenoss

# Download and extract the Core ZenPacks
wget -N http://softlayer-ams.dl.sourceforge.net/project/zenoss/zenoss-rc/builds/4.2.5-2070/zenoss_core-4.2.5-2070.el6.x86_64.rpm -P $downdir/
rpm2cpio $downdir/zenoss_core-4.2.5-2070.el6.x86_64.rpm | sudo cpio -ivd ./opt/zenoss/packs/*.* && mv opt/ $downdir/

echo "...Script complete"
exit 0
