#!/bin/bash
#
# init shell for bitcoind 0.10.0, ubuntu 14.04 LTS
#
# @author PanZhibiao<bit.kevin@gmail.com>
# @since 2015-02
# @copyright open-nodes.org
#
#

# init pkgs
apt-get update
apt-get install -y zsh git \
  build-essential autotools-dev libtool autoconf automake libssl-dev pkg-config \
  libdb++-dev libdb-dev libboost-all-dev \
  daemontools sysv-rc-conf ntp nload

# download bitcoind-v0.10.0 source
cd ~/
mkdir -p source
wget --no-check-certificate https://github.com/bitcoin/bitcoin/archive/v0.10.0.tar.gz -O v0.10.0.tar.gz
tar zxf v0.10.0.tar.gz
cd bitcoin-0.10.0

# apply open-nodes patch
wget --no-check-certificate https://raw.githubusercontent.com/open-nodes/InstallStaff/master/scripts/v0.10.0/open-nodes.org_hub-v0.10.0.patch -O open-nodes.org_hub-v0.10.0.patch
patch -p1 < open-nodes.org_hub-v0.10.0.patch

# build bitcoind
./autogen.sh
./configure --without-miniupnpc --disable-wallet
make -j4

# install bitcoind
strip src/bitcoind
cp src/bitcoind /usr/bin/bitcoind-0.10.0
cp src/bitcoin-cli /usr/bin/bitcoind-cli
chmod 755 /usr/bin/bitcoind-0.10.0
cd /usr/bin
ln -s ./bitcoind-0.10.0 bitcoind
cd ~/

#
# bitcoind运行目录，默认： ~/.bitcoin，即 /root/.bitcoin
#
mkdir -p ~/.bitcoin
echo "rpcuser=opennodesorg
rpcpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1`
rpcthreads=32

# datadir需要即安装目录，安装到非默认目录请记得修改
datadir=/root/.bitcoin
txindex=1

## 允许下载块数量限制，2016大约14天，即仅允许下载14天内的块数据
## 根据带宽大小可以适度放大
#limitdownloadblocks=2016

maxconnections=2048
outboundconnections=1024
" > ~/.bitcoin/bitcoin.conf

# 配置supervise模式
mkdir ~/supervise_bitcoind
cd ~/supervise_bitcoind
touch run
chmod +x run

echo '#! /bin/sh
SROOT=$(cd $(dirname "$0"); pwd)
cd $SROOT
 
bitcoind 
' > run

# 开机启动
cp /etc/rc.local /etc/rc.local.backup
sed -i 's/^exit 0$//g' /etc/rc.local
echo '
nohup supervise /root/supervise_bitcoind/ &
' >> /etc/rc.local

# start it
nohup supervise /root/supervise_bitcoind/ &
