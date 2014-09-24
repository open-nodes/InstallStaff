#
# init shell for bitcoind 0.9.2.1, ubuntu 14.04 LTS
#
# @author PanZhibiao<bit.kevin@gmail.com>
# @since 2014-09
# @copyright open-nodes.com
#
#

# init pkgs
apt-get update
apt-get install -y zsh git \
  build-essential autotools-dev libtool autoconf automake libssl-dev pkg-config \
  libdb++-dev libdb-dev libboost-all-dev \
  daemontools sysv-rc-conf ntp nload

# install oh-my-zsh
wget --no-check-certificate http://install.ohmyz.sh -O - | sh
chsh -s /bin/zsh

# download bitcoind-v0.9.2.1 source
cd ~/
mkdir -p source
wget "https://github.com/bitcoin/bitcoin/archive/v0.9.2.1.tar.gz" -O v0.9.2.1.tar.gz
tar zxf v0.9.2.1.tar.gz
cd bitcoin-0.9.2.1

# apply open-nodes patch
wget https://gist.githubusercontent.com/bitkevin/3386d413393445ea9f33/raw/e94cb7e496d9bf5bd25b1f30c9dc213903a4a989/open-nodes.org_hub-v0.9.2.1.patch -O open-nodes.org_hub-v0.9.2.1.patch
patch -p1 < open-nodes.org_hub-v0.9.2.1.patch

# build bitcoind
./autogen.sh
./configure --without-miniupnpc --disable-wallet
make -j4

# install bitcoind
strip src/bitcoind
cp src/bitcoind /usr/bin/bitcoind-0.9.2.1
chmod 755 /usr/bin/bitcoind-0.9.2.1
cd /usr/bin
ln -s ./bitcoind-0.9.2.1 bitcoind
cd ~/

#
# bitcoind运行目录，默认： ~/.bitcoin，即 /root/.bitcoin
#
mkdir -p ~/.bitcoin
echo 'rpcuser=opennodesorg
rpcpassword=qtD4dspeYL7Zr7nkbMBjyrGoLAUrLt
rpcthreads=32

# datadir需要即安装目录，安装到非默认目录请记得修改
datadir=/root/.bitcoin
txindex=true

# 允许下载块数量限制，2016大约14天，即仅允许下载14天内的块数据
# 根据带宽大小可以适度放大
limitdownloadblocks=2016

maxconnections=2048
outboundconnections=1024
' > ~/.bitcoin/bitcoin.conf

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

# 修改内核参数
cp /etc/sysctl.conf /etc/sysctl.conf.backup
echo '
net.ipv4.tcp_max_syn_backlog = 65536
net.core.netdev_max_backlog =  32768
net.core.somaxconn = 32768

net.core.wmem_default = 8388608
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_max_orphans = 3276800

fs.file-max = 2097152
' >> /etc/sysctl.conf
/sbin/sysctl -p

# 修改句柄数限制
cp /etc/security/limits.conf /etc/security/limits.conf.backup
echo '
*         hard    nofile      500000
*         soft    nofile      500000
root      hard    nofile      500000
root      soft    nofile      500000
' >> /etc/security/limits.conf

cp /etc/pam.d/common-session /etc/pam.d/common-session.backup
echo '
session required pam_limits.so
' >> /etc/pam.d/common-session

# 开机启动
cp /etc/rc.local /etc/rc.local.backup
sed -i 's/^exit 0$//g' /etc/rc.local
echo '
ulimit -SHn 500000
nohup supervise /root/supervise_bitcoind/ &
' >> /etc/rc.local

# 开启ntp
sysv-rc-conf ntp on
service ntp reload

# 重启
# reboot
