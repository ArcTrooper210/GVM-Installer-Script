#!/bin/bash

# Variables
INSTALLER_VERSION="0.2.2-beta"
LAST_UPDATED="2025-05-13"
HTTP="http"

SUCC="\e[01;32m"
SUCCH="\e[042m"
ERR="\e[01;31m"
ERRH="\e[41m"
WARN="\e[01;33m"
WARNH="\e[43m"
INFO="\e[01;34m"
INFOH="\e[44m"
CLR="\e[0m"

# Functions
function check_sig () {
    if ! grep -xqF 'Good signature from "Greenbone Community Feed integrity key"' <<< "$output"; then
        echo -e "${SUCC}[>] Good signature${CLR}"
        sleep 2
    else
        echo -e "${ERR}[!] Bad signature${CLR}"
        exit 1
    fi
}

function curl_download () {
	local url="$1"
	local output="$2"
	if curl -f -L -o "$output" "$url"; then
		echo -e "${SUCC}[>] Downloaded${CLR} ${INFO}$url${CLR} to ${INFO}$output${CLR}"
        sleep 2
	else
		echo -e "${ERR}[!] Failed to download $url${CLR}"
		exit 1
    fi
}

function show_help () {
	echo
	echo "valid arguments:"
	echo "--https      Install GSA with https setup"
	echo "--help       Show this help page"
	echo
}

# HTTPS argument checker
if [[ $1 == -* ]]; then
    case "$1" in
    	--https)
            echo -e "${INFO}[>]${CLR} HTTPS Install selected..."
            HTTP="https"
            PORT="443"
			;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo -e "${WARN}[!]${CLR} Invalid argument(s). Use --help to view valid arguments."
            exit 0
            ;;
    esac
    shift
fi


# Start main script
if [[ $UID != 0 ]]; then
	echo -e "${WARN}[!]${CLR} Run script with sudo."
	exit 1
fi

echo "Installer version: $INSTALLER_VERSION"
echo "Last updated $((($(date +%s)-$(date +%s --date $LAST_UPDATED))/(3600*24))) days ago ($LAST_UPDATED)"

while true; do
    read -p "Proceed with script? (y/n)" yn
    case $yn in
        [yY] ) echo "Continuing...";
            break;;
        [nN] ) echo "Exiting...";
            exit;;
        * ) echo "Invalid response";;
    esac
done


# Create user and group
echo -e "${INFO}[>] Creating user and group...${CLR}"
sudo useradd -r -M -U -G sudo -s /usr/sbin/nologin gvm
sudo usermod -aG gvm $USER


# Setting Environment Variables and PATH
echo -e "${INFO}[>] Setting Environment Variables and Path...${CLR}"
export INSTALL_PREFIX=/usr/local
export PATH=$PATH:$INSTALL_PREFIX/sbin


# Setting a Source, Build and Install Directory
echo -e "${INFO}[>] Setting Source, Build, and Install Directories...${CLR}"
export SOURCE_DIR=$HOME/source
mkdir -p $SOURCE_DIR
export BUILD_DIR=$HOME/build
mkdir -p $BUILD_DIR
export INSTALL_DIR=$HOME/install
mkdir -p $INSTALL_DIR


# Install dependencies
echo -e "${INFO}[>] Updating packages...${CLR}"
apt update && apt upgrade -y
echo -e "${INFO}[>] Installing Dependencies...${CLR}"
NEEDRESTART_MODE=a sudo apt install --no-install-recommends -y build-essential curl cmake pkg-config python3 python3-pip gnupg libcjson-dev libcurl4-gnutls-dev libgcrypt-dev libglib2.0-dev libgnutls28-dev libgpgme-dev libhiredis-dev libnet1-dev libpaho-mqtt-dev libpcap-dev libssh-dev libxml2-dev uuid-dev libldap2-dev libradcli-dev libbsd-dev libical-dev libpq-dev postgresql-server-dev-all rsync xsltproc dpkg fakeroot gnutls-bin gpgsm nsis openssh-client python3-lxml rpm smbclient snmp socat sshpass texlive-fonts-recommended texlive-latex-extra wget xmlstarlet zip libbrotli-dev libmicrohttpd-dev gcc-mingw-w64 libpopt-dev libunistring-dev heimdal-multidev perl-base bison libgcrypt20-dev libksba-dev nmap libjson-glib-dev krb5-multidev libsnmp-dev python3-setuptools python3-packaging python3-wrapt python3-cffi python3-psutil python3-defusedxml python3-paramiko python3-redis python3-gnupg python3-paho-mqtt libssl-dev python3-venv cargo postgresql python3-impacket
sudo apt install -y rustup



# Install the cert (dont use certbot anymore)
if HTTP == "https"; then
    echo
    echo -e "${WARN}[i] https is currently wip, continuing with http installation...${CLR}"
    echo
    sleep 5
fi



echo -e "${INFO}[>] Updating rustup...${CLR}"
rustup default stable

# Importing the Greenbone Signing Key
echo -e "${INFO}[>] Importing GB Signing Key...${CLR}"
curl_download https://www.greenbone.net/GBCommunitySigningKey.asc /tmp/GBCommunitySigningKey.asc
gpg --import /tmp/GBCommunitySigningKey.asc
echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" | gpg --import-ownertrust



# Download gvm-libs
echo -e "${INFO}[>] Downloading gvm-libs sources...${CLR}"
export GVM_LIBS_VERSION=22.21.0

curl_download https://github.com/greenbone/gvm-libs/archive/refs/tags/v$GVM_LIBS_VERSION.tar.gz $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz
curl_download https://github.com/greenbone/gvm-libs/releases/download/v$GVM_LIBS_VERSION/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc

# Assign cmd output to output
output=$(gpg --verify $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz)

# Test if signature is good
check_sig

echo -e "${INFO}[>] Extracting...${CLR}"
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz

echo -e "${INFO}[>] Building gvm-libs...${CLR}"
mkdir -p $BUILD_DIR/gvm-libs
cmake \
  -S $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION \
  -B $BUILD_DIR/gvm-libs \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
  -DCMAKE_BUILD_TYPE=Release \
  -DSYSCONFDIR=/etc \
  -DLOCALSTATEDIR=/var
cmake --build $BUILD_DIR/gvm-libs -j$(nproc)

echo -e "${INFO}[>] Installing gvm-libs...${CLR}"
mkdir -p $INSTALL_DIR/gvm-libs && cd $BUILD_DIR/gvm-libs
make DESTDIR=$INSTALL_DIR/gvm-libs install
sudo cp -rv $INSTALL_DIR/gvm-libs/* /



# Download gvmd
echo -e "${INFO}[>] Downloading gvmd sources...${CLR}"
export GVMD_VERSION=25.2.1
curl_download https://github.com/greenbone/gvmd/archive/refs/tags/v$GVMD_VERSION.tar.gz $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz
curl_download https://github.com/greenbone/gvmd/releases/download/v$GVMD_VERSION/gvmd-$GVMD_VERSION.tar.gz.asc $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz.asc

output=$(gpg --verify $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz.asc $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz)

check_sig

echo -e "${INFO}[>] Extracting...${CLR}"
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz

echo -e "${INFO}[>] Building gvmd...${CLR}"
mkdir -p $BUILD_DIR/gvmd
cmake \
  -S $SOURCE_DIR/gvmd-$GVMD_VERSION \
  -B $BUILD_DIR/gvmd \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
  -DCMAKE_BUILD_TYPE=Release \
  -DLOCALSTATEDIR=/var \
  -DSYSCONFDIR=/etc \
  -DGVM_DATA_DIR=/var \
  -DGVM_LOG_DIR=/var/log/gvm \
  -DGVMD_RUN_DIR=/run/gvmd \
  -DOPENVAS_DEFAULT_SOCKET=/run/ospd/ospd-openvas.sock \
  -DGVM_FEED_LOCK_PATH=/var/lib/gvm/feed-update.lock \
  -DLOGROTATE_DIR=/etc/logrotate.d
cmake --build $BUILD_DIR/gvmd -j$(nproc)

echo -e "${INFO}[>] Installing gvmd...${CLR}"
mkdir -p $INSTALL_DIR/gvmd && cd $BUILD_DIR/gvmd
make DESTDIR=$INSTALL_DIR/gvmd install
sudo cp -rv $INSTALL_DIR/gvmd/* /



# Download pg-gvm
echo -e "${INFO}[>] Downloading pg-gvm sources...${CLR}"
export PG_GVM_VERSION=22.6.9
curl_download https://github.com/greenbone/pg-gvm/archive/refs/tags/v$PG_GVM_VERSION.tar.gz $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz
curl_download https://github.com/greenbone/pg-gvm/releases/download/v$PG_GVM_VERSION/pg-gvm-$PG_GVM_VERSION.tar.gz.asc $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz.asc

output=$(gpg --verify $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz.asc $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz)

check_sig

echo -e "${INFO}[>] Extracting...${CLR}"
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz

echo -e "${INFO}[>] Building pg-gvm...${CLR}"
mkdir -p $BUILD_DIR/pg-gvm
cmake \
  -S $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION \
  -B $BUILD_DIR/pg-gvm \
  -DCMAKE_BUILD_TYPE=Release
cmake --build $BUILD_DIR/pg-gvm -j$(nproc)

echo -e "${INFO}[>] Installing pg-gvm...${CLR}"
mkdir -p $INSTALL_DIR/pg-gvm && cd $BUILD_DIR/pg-gvm
make DESTDIR=$INSTALL_DIR/pg-gvm install
sudo cp -rv $INSTALL_DIR/pg-gvm/* /



# Download gsa
echo -e "${INFO}[>] Downloading GSA sources...${CLR}"
export GSA_VERSION=24.3.0
curl_download https://github.com/greenbone/gsa/releases/download/v$GSA_VERSION/gsa-dist-$GSA_VERSION.tar.gz $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz
curl_download https://github.com/greenbone/gsa/releases/download/v$GSA_VERSION/gsa-dist-$GSA_VERSION.tar.gz.asc $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz.asc

output=$(gpg --verify $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz.asc $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz)

check_sig

echo -e "${INFO}[>] Extracting...${CLR}"
mkdir -p $SOURCE_DIR/gsa-$GSA_VERSION
tar -C $SOURCE_DIR/gsa-$GSA_VERSION -xvzf $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz

echo -e "${INFO}[>] Installing GSA...${CLR}"
sudo mkdir -p $INSTALL_PREFIX/share/gvm/gsad/web/
sudo cp -rv $SOURCE_DIR/gsa-$GSA_VERSION/* $INSTALL_PREFIX/share/gvm/gsad/web/



# Download gsad
echo -e "${INFO}[>] Downloading gsad sources...${CLR}"
export GSAD_VERSION=24.2.4
curl_download https://github.com/greenbone/gsad/archive/refs/tags/v$GSAD_VERSION.tar.gz $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz
curl_download https://github.com/greenbone/gsad/releases/download/v$GSAD_VERSION/gsad-$GSAD_VERSION.tar.gz.asc $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz.asc

output=$(gpg --verify $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz.asc $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz)

check_sig

echo -e "${INFO}[>] Extracting...${CLR}"
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz

echo -e "${INFO}[>] Building gsad...${CLR}"
mkdir -p $BUILD_DIR/gsad
cmake \
  -S $SOURCE_DIR/gsad-$GSAD_VERSION \
  -B $BUILD_DIR/gsad \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
  -DCMAKE_BUILD_TYPE=Release \
  -DSYSCONFDIR=/etc \
  -DLOCALSTATEDIR=/var \
  -DGVMD_RUN_DIR=/run/gvmd \
  -DGSAD_RUN_DIR=/run/gsad \
  -DGVM_LOG_DIR=/var/log/gvm \
  -DLOGROTATE_DIR=/etc/logrotate.d
cmake --build $BUILD_DIR/gsad -j$(nproc)

echo -e "${INFO}[>] Installing gsad...${CLR}"
mkdir -p $INSTALL_DIR/gsad && cd $BUILD_DIR/gsad
make DESTDIR=$INSTALL_DIR/gsad install
sudo cp -rv $INSTALL_DIR/gsad/* /



# Download openvas-smb
echo -e "${INFO}[>] Downloading openvas-smb sources...${CLR}"
export OPENVAS_SMB_VERSION=22.5.7
curl_download https://github.com/greenbone/openvas-smb/archive/refs/tags/v$OPENVAS_SMB_VERSION.tar.gz $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz
curl_download https://github.com/greenbone/openvas-smb/releases/download/v$OPENVAS_SMB_VERSION/openvas-smb-v$OPENVAS_SMB_VERSION.tar.gz.asc $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz.asc

output=$(gpg --verify $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz.asc $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz)

check_sig

echo -e "${INFO}[>] Extracting...${CLR}"
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz

echo -e "${INFO}[>] Building openvas-smb...${CLR}"
mkdir -p $BUILD_DIR/openvas-smb
cmake \
  -S $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION \
  -B $BUILD_DIR/openvas-smb \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
  -DCMAKE_BUILD_TYPE=Release
cmake --build $BUILD_DIR/openvas-smb -j$(nproc)

echo -e "${INFO}[>] Installing openvas-smb...${CLR}"
mkdir -p $INSTALL_DIR/openvas-smb && cd $BUILD_DIR/openvas-smb
make DESTDIR=$INSTALL_DIR/openvas-smb install
sudo cp -rv $INSTALL_DIR/openvas-smb/* /



# Download openvas-scanner
echo -e "${INFO}[>] Downloading openvas-scanner...${CLR}"
export OPENVAS_SCANNER_VERSION=23.17.0
curl_download https://github.com/greenbone/openvas-scanner/archive/refs/tags/v$OPENVAS_SCANNER_VERSION.tar.gz $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz
curl_download https://github.com/greenbone/openvas-scanner/releases/download/v$OPENVAS_SCANNER_VERSION/openvas-scanner-v$OPENVAS_SCANNER_VERSION.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz.asc

output=$(gpg --verify $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz)

check_sig

echo -e "${INFO}[>] Extracting...${CLR}"
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz

echo -e "${INFO}[>] Building openvas-scanner...${CLR}"
mkdir -p $BUILD_DIR/openvas-scanner
cmake \
  -S $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION \
  -B $BUILD_DIR/openvas-scanner \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
  -DCMAKE_BUILD_TYPE=Release \
  -DSYSCONFDIR=/etc \
  -DLOCALSTATEDIR=/var \
  -DOPENVAS_FEED_LOCK_PATH=/var/lib/openvas/feed-update.lock \
  -DOPENVAS_RUN_DIR=/run/ospd
cmake --build $BUILD_DIR/openvas-scanner -j$(nproc)

echo -e "${INFO}[>] Installing openvas-scanner...${CLR}"
mkdir -p $INSTALL_DIR/openvas-scanner && cd $BUILD_DIR/openvas-scanner
make DESTDIR=$INSTALL_DIR/openvas-scanner install
sudo cp -rv $INSTALL_DIR/openvas-scanner/* /

echo -e "${INFO}[>] Setting openvasd_server config...${CLR}"
printf "table_driven_lsc = yes\n" | sudo tee /etc/openvas/openvas.conf
printf "openvasd_server = http://127.0.0.1:3000\n" | sudo tee -a /etc/openvas/openvas.conf



# Download ospd-openvas
echo -e "${INFO}[>] Downloading ospd-openvas...${CLR}"
export OSPD_OPENVAS_VERSION=22.8.2
curl_download https://github.com/greenbone/ospd-openvas/archive/refs/tags/v$OSPD_OPENVAS_VERSION.tar.gz $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz
curl_download https://github.com/greenbone/ospd-openvas/releases/download/v$OSPD_OPENVAS_VERSION/ospd-openvas-v$OSPD_OPENVAS_VERSION.tar.gz.asc $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz.asc

output=$(gpg --verify $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz.asc $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz)

check_sig

echo -e "${INFO}[>] Extracting...${CLR}"
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz

echo -e "${INFO}[>] Installing ospd-openvas...${CLR}"
cd $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION
mkdir -p $INSTALL_DIR/ospd-openvas
sudo python3 -m pip install --root=$INSTALL_DIR/ospd-openvas --no-warn-script-location .
sudo cp -rv $INSTALL_DIR/ospd-openvas/* /



# Download openvasd
echo -e "${INFO}[>] Downloading openvasd...${CLR}"
export OPENVAS_DAEMON=23.17.0
curl_download https://github.com/greenbone/openvas-scanner/archive/refs/tags/v$OPENVAS_DAEMON.tar.gz $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz
curl_download https://github.com/greenbone/openvas-scanner/releases/download/v$OPENVAS_DAEMON/openvas-scanner-v$OPENVAS_DAEMON.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz.asc

output=$(gpg --verify $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz)

check_sig

echo -e "${INFO}[>] Extracting...${CLR}"
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz

echo -e "${INFO}[>] Installing openvasd...${CLR}"
mkdir -p $INSTALL_DIR/openvasd/usr/local/bin
cd $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON/rust/src/openvasd
cargo build --release
cd $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON/rust/src/scannerctl
cargo build --release
sudo cp -v ../../target/release/openvasd $INSTALL_DIR/openvasd/usr/local/bin/
sudo cp -v ../../target/release/scannerctl $INSTALL_DIR/openvasd/usr/local/bin/
sudo cp -rv $INSTALL_DIR/openvasd/* /



# Download greenbone-feed-sync
echo -e "${INFO}[>] Installing greenbone-feed-sync...${CLR}"
sudo mkdir -p $INSTALL_DIR/greenbone-feed-sync
sudo python3 -m pip install --root=$INSTALL_DIR/greenbone-feed-sync --no-warn-script-location greenbone-feed-sync
sudo cp -rv $INSTALL_DIR/greenbone-feed-sync/* /



# Download gvm-tools
echo -e "${INFO}[>] Installing gvm-tools...${CLR}"
sudo mkdir -p $INSTALL_DIR/gvm-tools
sudo python3 -m pip install --root=$INSTALL_DIR/gvm-tools --no-warn-script-location gvm-tools
sudo cp -rv $INSTALL_DIR/gvm-tools/* /




# Setting up Redis Data Store
echo -e "${INFO}[>] Installing Redis Data Store...${CLR}"
sudo apt install -y redis-server

echo -e "${INFO}[>] Adding openvas-scanner config...${CLR}"
sudo cp $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION/config/redis-openvas.conf /etc/redis/
sudo chown redis:redis /etc/redis/redis-openvas.conf
echo -e "db_address = /run/redis-openvas/redis.sock" | sudo tee -a /etc/openvas/openvas.conf

echo -e "${INFO}[>] Redis startup with config...${CLR}"
sudo systemctl start redis-server@openvas.service
sudo systemctl enable redis-server@openvas.service

echo -e "${INFO}[>] Add gvm user to redis group...${CLR}"
sudo usermod -aG redis gvm



# Adjusting perms
echo -e "${INFO}[>] Adjusting Permissions...${CLR}"
sudo mkdir -p /var/lib/notus
sudo mkdir -p /run/gvmd
sudo chown -R gvm:gvm /var/lib/gvm
sudo chown -R gvm:gvm /var/lib/openvas
sudo chown -R gvm:gvm /var/lib/notus
sudo chown -R gvm:gvm /var/log/gvm
sudo chown -R gvm:gvm /run/gvmd
sudo chmod -R g+srw /var/lib/gvm
sudo chmod -R g+srw /var/lib/openvas
sudo chmod -R g+srw /var/log/gvm
sudo chown gvm:gvm /usr/local/sbin/gvmd
sudo chmod 6750 /usr/local/sbin/gvmd



# Feed validation
echo -e "${INFO}[>] Feed Validation...${CLR}"
curl_download https://www.greenbone.net/GBCommunitySigningKey.asc /tmp/GBCommunitySigningKey.asc

export GNUPGHOME=/tmp/openvas-gnupg
mkdir -p $GNUPGHOME

gpg --import /tmp/GBCommunitySigningKey.asc
echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" | gpg --import-ownertrust

export OPENVAS_GNUPG_HOME=/etc/openvas/gnupg
sudo mkdir -p $OPENVAS_GNUPG_HOME
sudo cp -r /tmp/openvas-gnupg/* $OPENVAS_GNUPG_HOME/
sudo chown -R gvm:gvm $OPENVAS_GNUPG_HOME



# Setting up sudo for scanning
echo -e "${INFO}[>] Setting sudo for scanning...${CLR}"

if ! cat /etc/sudoers.d/gvm | grep -xqFe "%gvm ALL = NOPASSWD: /usr/local/sbin/openvas"; then
	echo "%gvm ALL = NOPASSWD: /usr/local/sbin/openvas" >> /etc/sudoers.d/gvm
	visudo -cf /etc/sudoers.d/gvm
		if [ $? -eq 0 ]; then
			chmod 0440 /etc/sudoers.d/gvm
			echo -e "${SUCC}[>] Permissions successfully granted${CLR}"
		else
			echo -e "${ERR}[!] Couldn't create and modify /etc/sudoers.d/gvm file. Do this manually.${CLR}"
			exit 1
	fi
else
	echo -e "${INFO}[i] gvm group already has sufficient permissions${CLR}"
fi



# Setting up PostgreSQL
echo -e "${INFO}[>] Starting PostpreSQL...${CLR}"
systemctl start postgresql@16-main

echo -e "${INFO}[>] Setting up PostpreSQL...${CLR}"
su - postgres -c "createuser -DRS gvm"
su - postgres -c "createdb -O gvm gvmd"
su - postgres -c "psql gvmd -q --command='create role dba with superuser noinherit;'"
su - postgres -c "psql gvmd -q --command='grant dba to gvm;'"

echo -e "${INFO}[>] Restarting PostpreSQL...${CLR}"
systemctl restart postgresql@16-main



# Setting up an Admin User
echo -e "${INFO}[>] Creating admin user...${CLR}"
/usr/local/sbin/gvmd --create-user=secops --password='admin'

# output=$(/usr/local/sbin/gvmd --create-user=secops --password='admin')

# # Test for success user creation
# if ! grep -qF 'User created' <<< "$output"; then
#     echo -e "${SUCC}Successfully created user.${CLR}"
# else
#     echo -e "${ERR}Failed to create user. Check /var/log/gvm/gvmd.log${CLR}"
#     exit 1
# fi



# Setting feed owner
echo -e "${INFO}[>] Setting feed import owner...${CLR}"
/usr/local/sbin/gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value /usr/local/sbin/gvmd --get-users --verbose | grep admin | awk '{print $2}'



# Setting up Services for Systemd
# ospd-openvas
echo -e "${INFO}[>] Creating systemd service file for ospd-openvas...${CLR}"
cat << EOF > $BUILD_DIR/ospd-openvas.service
[Unit]
Description=OSPD Wrapper for the OpenVAS Scanner (ospd-openvas)
Documentation=man:ospd-openvas(8) man:openvas(8)
After=network.target networking.service redis-server@openvas.service openvasd.service
Wants=redis-server@openvas.service openvasd.service
ConditionKernelCommandLine=!recovery

[Service]
Type=exec
User=gvm
Group=gvm
RuntimeDirectory=ospd
RuntimeDirectoryMode=2775
PIDFile=/run/ospd/ospd-openvas.pid
ExecStart=/usr/local/bin/ospd-openvas --foreground --unix-socket /run/ospd/ospd-openvas.sock --pid-file /run/ospd/ospd-openvas.pid --log-file /var/log/gvm/ospd-openvas.log --lock-file-dir /var/lib/openvas --socket-mode 0o770 --notus-feed-dir /var/lib/notus/advisories
SuccessExitStatus=SIGKILL
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

echo -e "${INFO}[>] Installing systemd service file for ospd-openvas...${CLR}"
sudo cp -v $BUILD_DIR/ospd-openvas.service /etc/systemd/system/



# gvmd
echo -e "${INFO}[>] Creating systemd service file for gvmd...${CLR}"
cat << EOF > $BUILD_DIR/gvmd.service
[Unit]
Description=Greenbone Vulnerability Manager daemon (gvmd)
After=network.target networking.service postgresql.service ospd-openvas.service
Wants=postgresql.service ospd-openvas.service
Documentation=man:gvmd(8)
ConditionKernelCommandLine=!recovery

[Service]
Type=exec
User=gvm
Group=gvm
PIDFile=/run/gvmd/gvmd.pid
RuntimeDirectory=gvmd
RuntimeDirectoryMode=2775
ExecStart=/usr/local/sbin/gvmd --foreground --osp-vt-update=/run/ospd/ospd-openvas.sock --listen-group=gvm
Restart=always
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF

echo -e "${INFO}[>] Installing systemd service file for gvmd...${CLR}"
sudo cp -v $BUILD_DIR/gvmd.service /etc/systemd/system/



# gsad http
echo -e "${INFO}[>] Creating systemd service file for gsad...${CLR}"
cat << EOF > $BUILD_DIR/gsad.service
[Unit]
Description=Greenbone Security Assistant daemon (gsad)
Documentation=man:gsad(8) https://www.greenbone.net
After=network.target gvmd.service
Wants=gvmd.service

[Service]
Type=exec
User=gvm
Group=gvm
RuntimeDirectory=gsad
RuntimeDirectoryMode=2775
PIDFile=/run/gsad/gsad.pid
ExecStart=/usr/local/sbin/gsad --foreground --listen=127.0.0.1 --port=9392 --http-only
Restart=always
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
Alias=greenbone-security-assistant.service
EOF

echo -e "${INFO}[>] Installing systemd service file for gsad...${CLR}"
sudo cp -v $BUILD_DIR/gsad.service /etc/systemd/system/

# # gsad https
# cat << EOF > $BUILD_DIR/gsad.service
# [Unit]
# Description=Greenbone Security Assistant daemon (gsad)
# Documentation=man:gsad(8) https://www.greenbone.net
# After=network.target gvmd.service
# Wants=gvmd.service

# [Service]
# Type=exec
# #User=gvm
# #Group=gvm
# RuntimeDirectory=gsad
# RuntimeDirectoryMode=2775
# PIDFile=/run/gsad/gsad.pid
# ExecStart=/usr/local/sbin/gsad --foreground --listen=127.0.0.1 --port=443 --rport=80 --ssl-private-key=/var/lib/gvm/private/CA/clientkey.pem --ssl-certificate=/var/lib/gvm/CA/clientcert.pem
# Restart=always
# TimeoutStopSec=10

# [Install]
# WantedBy=multi-user.target
# Alias=greenbone-security-assistant.service
# EOF


# openvasd
echo -e "${INFO}[>] Creating systemd service file for openvasd...${CLR}"
cat << EOF > $BUILD_DIR/openvasd.service
[Unit]
Description=OpenVASD
Documentation=https://github.com/greenbone/openvas-scanner/tree/main/rust/openvasd
ConditionKernelCommandLine=!recovery
[Service]
Type=exec
User=gvm
RuntimeDirectory=openvasd
RuntimeDirectoryMode=2775
ExecStart=/usr/local/bin/openvasd --mode service_notus --products /var/lib/notus/products --advisories /var/lib/notus/advisories --listening 127.0.0.1:3000
SuccessExitStatus=SIGKILL
Restart=always
RestartSec=60
[Install]
WantedBy=multi-user.target
EOF

echo -e "${INFO}[>] Installing systemd service file for openvasd...${CLR}"
sudo cp -v $BUILD_DIR/openvasd.service /etc/systemd/system/

echo -e "${INFO}[>] Activating and starting new service files...${CLR}"
sudo systemctl daemon-reload



# Feed sync
echo -e "${INFO}[>] Performing feed sync...${CLR}"
echo -e "${WARN}[i] This might take a while...${CLR}"
sudo /usr/local/bin/greenbone-feed-sync



# Start services
echo -e "${INFO}[>] Starting all services...${CLR}"
sudo systemctl start ospd-openvas
sudo systemctl start gvmd
sudo systemctl start gsad
sudo systemctl start openvasd

echo -e "${INFO}[>] Setting services to run on system startup...${CLR}"
sudo systemctl enable ospd-openvas
sudo systemctl enable gvmd
sudo systemctl enable gsad
sudo systemctl enable openvasd

echo -e "${INFO}[>] Checking status of services...${CLR}"
# sudo systemctl status ospd-openvas
# sudo systemctl status gvmd
# sudo systemctl status gsad
# sudo systemctl status openvasd

SERVICE_NAME="ospd-openvas"
STATUS_OUTPUT=$(systemctl status "$SERVICE_NAME")

if [[ "$STATUS_OUTPUT" =~ "Active: active (running)" ]]; then
    OSPD_OPENVAS="1"
    echo -e "${SUCC}[>] Service '$SERVICE_NAME' is running.${CLR}"
elif [[ "$STATUS_OUTPUT" =~ "Active: inactive" ]]; then
    OSPD_OPENVAS="0"
    echo -e "${ERR}[!] Service '$SERVICE_NAME' is not running.${CLR}"
else
    OSPD_OPENVAS="0"
    echo -e "${WARN}[i] Service '$SERVICE_NAME' is in an unknown state: $STATUS_OUTPUT${CLR}"
fi

SERVICE_NAME="gvmd"
STATUS_OUTPUT=$(systemctl status "$SERVICE_NAME")

if [[ "$STATUS_OUTPUT" =~ "Active: active (running)" ]]; then
    GVMD="1"
    echo -e "${SUCC}[>] Service '$SERVICE_NAME' is running.${CLR}"
elif [[ "$STATUS_OUTPUT" =~ "Active: inactive" ]]; then
    GVMD="0"
    echo -e "${ERR}[!] Service '$SERVICE_NAME' is not running.${CLR}"
else
    GVMD="0"
    echo -e "${WARN}[i] Service '$SERVICE_NAME' is in an unknown state: $STATUS_OUTPUT${CLR}"
fi

SERVICE_NAME="gsad"
STATUS_OUTPUT=$(systemctl status "$SERVICE_NAME")

if [[ "$STATUS_OUTPUT" =~ "Active: active (running)" ]]; then
    GSAD="1"
    echo -e "${SUCC}[>] Service '$SERVICE_NAME' is running.${CLR}"
elif [[ "$STATUS_OUTPUT" =~ "Active: inactive" ]]; then
    GSAD="0"
    echo -e "${ERR}[!] Service '$SERVICE_NAME' is not running.${CLR}"
else
    GSAD="0"
    echo -e "${WARN}[i] Service '$SERVICE_NAME' is in an unknown state: $STATUS_OUTPUT${CLR}"
fi

SERVICE_NAME="openvasd"
STATUS_OUTPUT=$(systemctl status "$SERVICE_NAME")

if [[ "$STATUS_OUTPUT" =~ "Active: active (running)" ]]; then
    OPENVASD="1"
    echo -e "${SUCC}[>] Service '$SERVICE_NAME' is running.${CLR}"
elif [[ "$STATUS_OUTPUT" =~ "Active: inactive" ]]; then
    OPENVASD="0"
    echo -e "${ERR}[!] Service '$SERVICE_NAME' is not running.${CLR}"
else
    OPENVASD="0"
    echo -e "${WARN}[i] Service '$SERVICE_NAME' is in an unknown state: $STATUS_OUTPUT${CLR}"
fi


# Remove tmp files
echo -e "${INFO}[>] Removing temp files...${CLR}"
sudo rm -rf /tmp/GBCommunitySigningKey.asc
sudo rm -rf /tmp/openvas-gnupg


# Complete message
if [ $OSPD_OPENVAS = "1" ] && [ $GVMD = "1" ] && [ $GSAD = "1" ] && [ $OPENVASD = "1" ]; then
    echo
    echo -e "${SUCC}[>] Greenbone Community Edition install is completed!${CLR}"
    echo
else
    echo
    echo -e "${ERR}[!] Greenbone Community Edition install is incomplete!${CLR}"
    echo
fi

# Start http web interface
echo -e "${INFO}[>] Starting GSA interface...${CLR}"
xdg-open "http://127.0.0.1:9392" 2>/dev/null >/dev/null &

# # Start https web interface
# echo -e "${INFO}Starting GSA interfacing...${CLR}"
# xdg-open "https://127.0.0.1:443" 2>/dev/null >/dev/null &
