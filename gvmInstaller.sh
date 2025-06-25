#!/bin/bash

# ————— Variables ——————————————————————————————————————————————
INSTALLER_VERSION="0.3.1-beta"
LAST_UPDATED="2025-06-23"
HTTP="http"
# Customize url. URL https://your.greenbone.domain:443
export GVM_CERTIFICATE_SAN_DNS="your.greenbone.domain"

SUCC="\e[01;92m"
SUCCH="\e[042m"
INFO="\e[01;94m"
INFOH="\e[44m"
WARN="\e[01;33m"
WARNH="\e[43m"
ERR="\e[01;31m"
ERRH="\e[41m"
CLR="\e[0m"

# ————— Version variables ——————————————————————————————————————
GVM_LIBS_VERSION=22.21.0
GVMD_VERSION=25.2.1
PG_GVM_VERSION=22.6.9
GSA_VERSION=24.3.0
GSAD_VERSION=24.2.4
OPENVAS_SMB_VERSION=22.5.7
OPENVAS_SCANNER_VERSION=23.17.0
OSPD_OPENVAS_VERSION=22.8.2
OPENVAS_DAEMON=23.17.0

# ————— Functions ——————————————————————————————————————————————
success ()  { echo -e "\e[92m[ OK ]  $1${CLR}"; }
info ()     { echo -e "\e[94m[INFO]  $1${CLR}"; }
warn ()     { echo -e "\e[33m[WARN]  $1${CLR}"; }
error ()    { echo -e "\e[31m[ERROR] $1${CLR}"; }

successi () { echo -e "\e[92m[>] $1${CLR}"; }
infoi ()    { echo -e "\e[94m[i] $1${CLR}"; }
warni ()    { echo -e "\e[33m[-] $1${CLR}"; }
errori ()   { echo -e "\e[31m[!] $1${CLR}"; }

check_sig () {
    if ! grep -xqF 'Good signature from "Greenbone Community Feed integrity key"' <<< "$sig_output"; then
        success "Good signature."
        sleep 2
    else
        errori "Bad signature."
        exit 1
    fi
}

curl_download () {
	local url="$1"
	local output="$2"
	if curl -fLo "$output" "$url"; then
        successi "Downloaded ${INFO}$url${CLR} to ${INFO}$output${CLR}"
        sleep 2
	else
        error "Failed to download $url"
		exit 1
    fi
}

show_help () {
	echo
	echo "valid arguments:"
    echo "--help            Show this help page"
	echo "--https           Install GVM with https setup"
	echo "--start           Start all GVM Services"
	echo "--stop            Stop all GVM Services"
	echo "--status          Prints status of all GVM Services"
	echo "--restart         Restarts all GVM Services"
	echo "--uninstall       Uninstall GVM"
	echo
}

start_services () {
    local services=("ospd-openvas" "gvmd" "gsad" "openvasd")
    local all_running=true
    infoi "Starting all Greenbone Processes..."

    for service_name in "${services[@]}"; do
        sudo systemctl start "$service_name" 2>/dev/null
    done
    sleep 3

    for service_name in "${services[@]}"; do
        if systemctl is-active --quiet "$service_name"; then
            successi "Service '$service_name' started successfully."
        else
            errori "Service '$service_name' failed to start."
            all_running=false
        fi
    done

    if [ "$all_running" = true ]; then
        echo
        success "All Greenbone processes successfully started"
        echo
        exit 0
    else
        echo
        error "Not all processes started"
        echo
        exit 1
    fi
}

stop_services () {
    local services=("ospd-openvas" "gvmd" "gsad" "openvasd")
    local all_stopped=true
    infoi "Stopping all Greenbone Processes..."

    for service_name in "${services[@]}"; do
        sudo systemctl stop "$service_name" 2>/dev/null
    done
    sleep 3

    for service_name in "${services[@]}"; do
        if systemctl is-active --quiet "$service_name"; then
            errori "Service '$service_name' failed to stop."
            all_stopped=false
        else
            successi "Service '$service_name' stopped successfully."
        fi
    done

    if [ "$all_stopped" = true ]; then
        echo
        success "All Greenbone processes stopped."
        echo
        exit 0
    else
        echo
        error "Failed to stop all processes or some processes were already stopped."
        echo
        exit 1
    fi
}

restart_services () {
    local services=("ospd-openvas" "gvmd" "gsad" "openvasd")
    local all_running=true
    infoi "Starting all Greenbone Processes..."

    for service_name in "${services[@]}"; do
        sudo systemctl restart "$service_name" 2>/dev/null
    done
    sleep 5

    for service_name in "${services[@]}"; do
        if systemctl is-active --quiet "$service_name"; then
            successi "Service '$service_name' restarted successfully."
        else
            errori "Service '$service_name' failed to restart."
            all_running=false
        fi
    done

    if [ "$all_running" = true ]; then
        echo
        success "All Greenbone processes successfully restarted"
        echo
        exit 0
    else
        echo
        error "Not all processes restarted"
        echo
        exit 1
    fi
}

services_status () {
    infoi "Checking status of services..."

    local service_name="ospd-openvas"
    local status_output=$(systemctl status "$service_name")

    if [[ "$status_output" =~ "Active: active (running)" ]]; then
        successi "Service '$service_name' is running."
    elif [[ "$status_output" =~ "Active: inactive" ]]; then
        errori "Service '$service_name' is not running."
    else
        warni "Service '$service_name' is in an unknown state: $status_output"
    fi

    local service_name="gvmd"
    local status_output=$(systemctl status "$service_name")

    if [[ "$status_output" =~ "Active: active (running)" ]]; then
        successi "Service '$service_name' is running."
    elif [[ "$status_output" =~ "Active: inactive" ]]; then
        errori "Service '$service_name' is not running."
    else
        warni "Service '$service_name' is in an unknown state: $status_output"
    fi

    local service_name="gsad"
    local status_output=$(systemctl status "$service_name")

    if [[ "$status_output" =~ "Active: active (running)" ]]; then
        successi "Service '$service_name' is running."
    elif [[ "$status_output" =~ "Active: inactive" ]]; then
        errori "Service '$service_name' is not running."
    else
        warni "Service '$service_name' is in an unknown state: $status_output"
    fi

    local service_name="openvasd"
    local status_output=$(systemctl status "$service_name")

    if [[ "$status_output" =~ "Active: active (running)" ]]; then
        successi "Service '$service_name' is running."
    elif [[ "$status_output" =~ "Active: inactive" ]]; then
        errori "Service '$service_name' is not running."
    else
        warni "Service '$service_name' is in an unknown state: $status_output"
    fi
    exit 0
}

uninstall_greenbone () {
    while true; do
        read -p "Proceed with uninstall? (y/n)" yn
        case $yn in
            [yY] ) successi "Continuing with uninstall...";
                break;;
            [nN] ) warni "Cancelling uninstall...";
                exit;;
            * ) errori "Invalid response";;
        esac
    done

    # Start uninstall process
    # Make sure to check if files exist in a location before uninstalling
    # Disable autoboot of services on load with systemctl disable
    # Error handling

    echo "Uninstaller flag wip..."
    exit 0
}


# ————— Command flags checker ——————————————————————————————————
if [[ $1 == -* ]]; then
    case "$1" in
    	--https)
	    infoi "HTTPS Install selected..."
            HTTP="https"
			;;
        --help|-h)
            show_help
            exit 0
            ;;
        --uninstall)
            uninstall_greenbone
            ;;
        --start)
            start_services
            ;;
        --stop)
            stop_services
            ;;
        --restart)
            restart_services
            ;;
        --status)
            services_status
            ;;
        *)
            # echo -e "${WARN}[!]${CLR} Invalid argument(s). Use --help to view valid arguments."
            warni "Invalid argument(s). Use --help to view valid arguments."
            exit 0
            ;;
    esac
    shift
fi


# ————— Check sudo —————————————————————————————————————————————
if [[ $UID -ne 0 ]]; then
    warni "Run script with sudo."
	exit 1
fi

echo "Installer version: $INSTALLER_VERSION"
echo "Last updated $((($(date +%s)-$(date +%s --date $LAST_UPDATED))/(3600*24))) days ago ($LAST_UPDATED)"
# —————————————————————————————————————————————
# ————— CHECK GITHUB FOR LATEST VERSION OF INSTALLER ——————————————————————————————————————————————————————————————————————————————————————————
# —————————————————————————————————————————————

while true; do
    read -p "Proceed with script? (y/n)" yn
    case $yn in
        [yY] ) echo "Continuing...";
            break;;
        [nN] ) echo "Exiting...";
            exit;;
        * ) warni "Invalid response";;
    esac
done


# ————— Check for running GB processes —————————————————————————
services=("ospd-openvas" "gvmd" "gsad" "openvasd")
all_stopped=true
infoi "Checking for running Greenbone Processes..."

for service_name in "${services[@]}"; do
    sudo systemctl stop "$service_name" 2>/dev/null
done
sleep 3

for service_name in "${services[@]}"; do
    if systemctl is-active --quiet "$service_name"; then
        errori "Service '$service_name' failed to stop."
        all_stopped=false
    else
        continue
    fi
done

if [ "$all_stopped" != true ]; then
    error "Failed to stop all processes. Manually stop all Greenbone processes before installing."
    exit 1
fi


# ————————————————— Start GVM install ——————————————————————————

# ————— Create user and group ——————————————————————————————————
infoi "Creating user and group..."
sudo useradd -rMU -G sudo -s /usr/sbin/nologin gvm
sudo usermod -aG gvm $USER

# ──── Setting Environment Variables and PATH ——————————————————
infoi "Setting Environment Variables and Path..."
export INSTALL_PREFIX=/usr/local
export PATH=$PATH:$INSTALL_PREFIX/sbin


# ──── Setting Source, Build and Install Directory —————————————
infoi "Setting Source, Build, and Install Directories..."
export SOURCE_DIR=$HOME/source
mkdir -p $SOURCE_DIR
export BUILD_DIR=$HOME/build
mkdir -p $BUILD_DIR
export INSTALL_DIR=$HOME/install
mkdir -p $INSTALL_DIR



# ──── Install dependencies ————————————————————————————————————
infoi "Updating packages..."
apt-get update && apt-get upgrade -y
infoi "Installing Dependencies..."
NEEDRESTART_MODE=a apt-get install --no-install-recommends -y build-essential curl cmake pkg-config python3 python3-pip gnupg libcjson-dev libcurl4-gnutls-dev libgcrypt-dev libglib2.0-dev libgnutls28-dev libgpgme-dev libhiredis-dev libnet1-dev libpaho-mqtt-dev libpcap-dev libssh-dev libxml2-dev uuid-dev libldap2-dev libradcli-dev libbsd-dev libical-dev libpq-dev postgresql-server-dev-all rsync xsltproc dpkg fakeroot gnutls-bin gpgsm nsis openssh-client python3-lxml rpm smbclient snmp socat sshpass texlive-fonts-recommended texlive-latex-extra wget xmlstarlet zip libbrotli-dev libmicrohttpd-dev gcc-mingw-w64 libpopt-dev libunistring-dev heimdal-multidev perl-base bison libgcrypt20-dev libksba-dev nmap libjson-glib-dev krb5-multidev libsnmp-dev python3-setuptools python3-packaging python3-wrapt python3-cffi python3-psutil python3-defusedxml python3-paramiko python3-redis python3-gnupg python3-paho-mqtt libssl-dev python3-venv cargo postgresql python3-impacket
apt-get install -y rustup

infoi "Updating rustup..."
rustup default stable



# ————— Importing the Greenbone Signing Key ————————————————————
infoi "Importing GB Signing Key..."
curl_download https://www.greenbone.net/GBCommunitySigningKey.asc /tmp/GBCommunitySigningKey.asc
gpg --import /tmp/GBCommunitySigningKey.asc
echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" | gpg --import-ownertrust



# ————— Download gvm-libs ——————————————————————————————————————
infoi "Downloading gvm-libs sources..."
curl_download https://github.com/greenbone/gvm-libs/archive/refs/tags/v$GVM_LIBS_VERSION.tar.gz $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz
curl_download https://github.com/greenbone/gvm-libs/releases/download/v$GVM_LIBS_VERSION/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc

sig_output=$(gpg --verify $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz)
check_sig

infoi "Extracting..."
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz

infoi "Building gvm-libs..."
mkdir -p $BUILD_DIR/gvm-libs
cmake \
    -S $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION \
    -B $BUILD_DIR/gvm-libs \
    -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
    -DCMAKE_BUILD_TYPE=Release \
    -DSYSCONFDIR=/etc \
    -DLOCALSTATEDIR=/var
cmake --build $BUILD_DIR/gvm-libs -j$(nproc)

infoi "Installing gvm-libs..."
mkdir -p $INSTALL_DIR/gvm-libs && cd $BUILD_DIR/gvm-libs
make DESTDIR=$INSTALL_DIR/gvm-libs install
sudo cp -rv $INSTALL_DIR/gvm-libs/* /



# ————— Download gvmd ——————————————————————————————————————————
infoi "Downloading gvmd sources..."
curl_download https://github.com/greenbone/gvmd/archive/refs/tags/v$GVMD_VERSION.tar.gz $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz
curl_download https://github.com/greenbone/gvmd/releases/download/v$GVMD_VERSION/gvmd-$GVMD_VERSION.tar.gz.asc $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz.asc

sig_output=$(gpg --verify $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz.asc $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz)
check_sig

infoi "Extracting..."
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz

infoi "Buildings gvmd..."
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

infoi "Installing gvmd..."
mkdir -p $INSTALL_DIR/gvmd && cd $BUILD_DIR/gvmd
make DESTDIR=$INSTALL_DIR/gvmd install
sudo cp -rv $INSTALL_DIR/gvmd/* /



# ————— Download pg-gvm ————————————————————————————————————————
infoi "Downloading pg-gvm sources..."
curl_download https://github.com/greenbone/pg-gvm/archive/refs/tags/v$PG_GVM_VERSION.tar.gz $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz
curl_download https://github.com/greenbone/pg-gvm/releases/download/v$PG_GVM_VERSION/pg-gvm-$PG_GVM_VERSION.tar.gz.asc $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz.asc

sig_output=$(gpg --verify $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz.asc $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz)
check_sig

infoi "Extracting..."
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz

infoi "Building pg-gvm..."
mkdir -p $BUILD_DIR/pg-gvm
cmake \
    -S $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION \
    -B $BUILD_DIR/pg-gvm \
    -DCMAKE_BUILD_TYPE=Release
cmake --build $BUILD_DIR/pg-gvm -j$(nproc)

infoi "Installing pg-gvm..."
mkdir -p $INSTALL_DIR/pg-gvm && cd $BUILD_DIR/pg-gvm
make DESTDIR=$INSTALL_DIR/pg-gvm install
sudo cp -rv $INSTALL_DIR/pg-gvm/* /



# ————— Download gsa ———————————————————————————————————————————
infoi "Downloading GSA sources..."
curl_download https://github.com/greenbone/gsa/releases/download/v$GSA_VERSION/gsa-dist-$GSA_VERSION.tar.gz $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz
curl_download https://github.com/greenbone/gsa/releases/download/v$GSA_VERSION/gsa-dist-$GSA_VERSION.tar.gz.asc $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz.asc

sig_output=$(gpg --verify $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz.asc $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz)
check_sig

infoi "Extracting..."
mkdir -p $SOURCE_DIR/gsa-$GSA_VERSION
tar -C $SOURCE_DIR/gsa-$GSA_VERSION -xvzf $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz

infoi "Installing GSA..."
sudo mkdir -p $INSTALL_PREFIX/share/gvm/gsad/web/
sudo cp -rv $SOURCE_DIR/gsa-$GSA_VERSION/* $INSTALL_PREFIX/share/gvm/gsad/web/



# ————— Download gsad ——————————————————————————————————————————
infoi "Downloading gsad sources..."
curl_download https://github.com/greenbone/gsad/archive/refs/tags/v$GSAD_VERSION.tar.gz $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz
curl_download https://github.com/greenbone/gsad/releases/download/v$GSAD_VERSION/gsad-$GSAD_VERSION.tar.gz.asc $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz.asc

sig_output=$(gpg --verify $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz.asc $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz)
check_sig

infoi "Extracting..."
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz

infoi "Building gsad..."
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

infoi "Installing gsad..."
mkdir -p $INSTALL_DIR/gsad && cd $BUILD_DIR/gsad
make DESTDIR=$INSTALL_DIR/gsad install
sudo cp -rv $INSTALL_DIR/gsad/* /



# ————— Download openvas-smb ———————————————————————————————————
infoi "Downloading openvas-smb sources..."
curl_download https://github.com/greenbone/openvas-smb/archive/refs/tags/v$OPENVAS_SMB_VERSION.tar.gz $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz
curl_download https://github.com/greenbone/openvas-smb/releases/download/v$OPENVAS_SMB_VERSION/openvas-smb-v$OPENVAS_SMB_VERSION.tar.gz.asc $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz.asc

sig_output=$(gpg --verify $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz.asc $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz)
check_sig

infoi "Extracting..."
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz

infoi "Building openvas-smb..."
mkdir -p $BUILD_DIR/openvas-smb
cmake \
    -S $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION \
    -B $BUILD_DIR/openvas-smb \
    -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
    -DCMAKE_BUILD_TYPE=Release
cmake --build $BUILD_DIR/openvas-smb -j$(nproc)

infoi "Installing openvas-smb..."
mkdir -p $INSTALL_DIR/openvas-smb && cd $BUILD_DIR/openvas-smb
make DESTDIR=$INSTALL_DIR/openvas-smb install
sudo cp -rv $INSTALL_DIR/openvas-smb/* /



# ————— Download openvas-scanner ———————————————————————————————
infoi "Downloading openvas-scanner..."
curl_download https://github.com/greenbone/openvas-scanner/archive/refs/tags/v$OPENVAS_SCANNER_VERSION.tar.gz $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz
curl_download https://github.com/greenbone/openvas-scanner/releases/download/v$OPENVAS_SCANNER_VERSION/openvas-scanner-v$OPENVAS_SCANNER_VERSION.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz.asc

sig_output=$(gpg --verify $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz)
check_sig

infoi "Extracting..."
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz

infoi "Building openvas-scanner..."
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

infoi "Installing openvas-scanner..."
mkdir -p $INSTALL_DIR/openvas-scanner && cd $BUILD_DIR/openvas-scanner
make DESTDIR=$INSTALL_DIR/openvas-scanner install
sudo cp -rv $INSTALL_DIR/openvas-scanner/* /

infoi "Setting openvasd_server config..."
printf "table_driven_lsc = yes\n" | sudo tee /etc/openvas/openvas.conf
printf "openvasd_server = http://127.0.0.1:3000\n" | sudo tee -a /etc/openvas/openvas.conf



# ————— Download ospd-openvas ——————————————————————————————————
infoi "Downloading ospd-openvas..."
curl_download https://github.com/greenbone/ospd-openvas/archive/refs/tags/v$OSPD_OPENVAS_VERSION.tar.gz $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz
curl_download https://github.com/greenbone/ospd-openvas/releases/download/v$OSPD_OPENVAS_VERSION/ospd-openvas-v$OSPD_OPENVAS_VERSION.tar.gz.asc $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz.asc

sig_output=$(gpg --verify $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz.asc $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz)
check_sig

infoi "Extracting..."
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz

infoi "Installing ospd-openvas..."
cd $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION
mkdir -p $INSTALL_DIR/ospd-openvas
sudo python3 -m pip install --root=$INSTALL_DIR/ospd-openvas --no-warn-script-location .
sudo cp -rv $INSTALL_DIR/ospd-openvas/* /



# ————— Download openvasd ——————————————————————————————————————
infoi "Downloading openvasd..."
curl_download https://github.com/greenbone/openvas-scanner/archive/refs/tags/v$OPENVAS_DAEMON.tar.gz $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz
curl_download https://github.com/greenbone/openvas-scanner/releases/download/v$OPENVAS_DAEMON/openvas-scanner-v$OPENVAS_DAEMON.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz.asc

sig_output=$(gpg --verify $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz)
check_sig

infoi "Extracting..."
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz

infoi "Installing openvasd..."
mkdir -p $INSTALL_DIR/openvasd/usr/local/bin
cd $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON/rust/src/openvasd
cargo build --release
cd $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON/rust/src/scannerctl
cargo build --release
sudo cp -v ../../target/release/openvasd $INSTALL_DIR/openvasd/usr/local/bin/
sudo cp -v ../../target/release/scannerctl $INSTALL_DIR/openvasd/usr/local/bin/
sudo cp -rv $INSTALL_DIR/openvasd/* /



# ————— Download greenbone-feed-sync ———————————————————————————
infoi "Installing greenbone-feed-sync..."
sudo mkdir -p $INSTALL_DIR/greenbone-feed-sync
sudo python3 -m pip install --root=$INSTALL_DIR/greenbone-feed-sync --no-warn-script-location greenbone-feed-sync
sudo cp -rv $INSTALL_DIR/greenbone-feed-sync/* /



# ————— Download gvm-tools —————————————————————————————————————
infoi "Installing gvm-tools..."
sudo mkdir -p $INSTALL_DIR/gvm-tools
sudo python3 -m pip install --root=$INSTALL_DIR/gvm-tools --no-warn-script-location gvm-tools
sudo cp -rv $INSTALL_DIR/gvm-tools/* /



# ————— Setting up Redis Data Store ————————————————————————————
infoi "Installing Redis Data Store..."
sudo apt install -y redis-server

infoi "Adding openvas-scanner config..."
sudo cp $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION/config/redis-openvas.conf /etc/redis/
sudo chown redis:redis /etc/redis/redis-openvas.conf
echo -e "db_address = /run/redis-openvas/redis.sock" | sudo tee -a /etc/openvas/openvas.conf

infoi "Redis startup with config..."
sudo systemctl start redis-server@openvas.service
sudo systemctl enable redis-server@openvas.service

infoi "Add gvm user to redis group..."
sudo usermod -aG redis gvm



# ————— Adjusting perms ————————————————————————————————————————
infoi "Adjusting Permissions..."
mkdir -p /var/lib/notus /run/gvmd
chown -R gvm:gvm \
    /var/lib/gvm \
    /var/lib/openvas \
    /var/lib/notus \
    /var/log/gvm \
    /run/gvmd
chmod -R g+srw \
    /var/lib/gvm \
    /var/lib/openvas \
    /var/log/gvm
chown gvm:gvm /usr/local/sbin/gvmd
chmod 6750 /usr/local/sbin/gvmd



# ————— Feed validation ————————————————————————————————————————
infoi "Feed Validation..."
curl_download https://www.greenbone.net/GBCommunitySigningKey.asc /tmp/GBCommunitySigningKey.asc

export GNUPGHOME=/tmp/openvas-gnupg
mkdir -p $GNUPGHOME

gpg --import /tmp/GBCommunitySigningKey.asc
echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" | gpg --import-ownertrust

export OPENVAS_GNUPG_HOME=/etc/openvas/gnupg
sudo mkdir -p $OPENVAS_GNUPG_HOME
sudo cp -r /tmp/openvas-gnupg/* $OPENVAS_GNUPG_HOME/
sudo chown -R gvm:gvm $OPENVAS_GNUPG_HOME



# ————— Setting up sudo for scanning ———————————————————————————
infoi "Setting sudo for scanning..."

if ! cat /etc/sudoers.d/gvm | grep -xqFe "%gvm ALL = NOPASSWD: /usr/local/sbin/openvas"; then
	echo "%gvm ALL = NOPASSWD: /usr/local/sbin/openvas" >> /etc/sudoers.d/gvm
	visudo -cf /etc/sudoers.d/gvm
		if [ $? -eq 0 ]; then
			chmod 0440 /etc/sudoers.d/gvm
            success "Permissions successfully granted"
		else
            error "Couldn't create and modify /etc/sudoers.d/gvm file. Do this manually."
			exit 1
	fi
else
    info "gvm group already has sufficient permissions"
fi



# ————— Setting up PostgreSQL ——————————————————————————————————
infoi "Starting PostpreSQL..."
systemctl start postgresql@16-main
sleep 3

info "Setting up PostpreSQL..."
su - postgres -c "createuser -DRS gvm"
su - postgres -c "createdb -O gvm gvmd"
su - postgres -c "psql gvmd -q --command='create role dba with superuser noinherit;'"
su - postgres -c "psql gvmd -q --command='grant dba to gvm;'"

infoi "Restarting PostpreSQL..."
systemctl restart postgresql@16-main



# ————— Setting up an Admin User ———————————————————————————————
infoi "Creating admin user..."
/usr/local/sbin/gvmd --create-user=admin --password='admin'

# userCreateOutput=$(/usr/local/sbin/gvmd --create-user=admin --password='admin')
# # Test for success user creation
# if ! grep -qF 'User created' <<< "$userCreateOutput"; then
#     echo -e "${SUCC}[>] Successfully created user.${CLR}"
# else
#     echo -e "${ERR}[!] Failed to create user. Check /var/log/gvm/gvmd.log${CLR}"
#     exit 1
# fi



# ————— Setting feed owner —————————————————————————————————————
infoi "Setting feed import owner..."
sudo /usr/local/sbin/gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value `sudo /usr/local/sbin/gvmd --get-users --verbose | grep admin | awk '{print $2}'`


# ————— Setting up Services for Systemd ————————————————————————
# ─────  ospd-openvas ——————————————————————————————————————————
infoi "Creating systemd service file for ospd-openvas..."
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

infoi "Installing systemd service file for ospd-openvas..."
sudo cp -v $BUILD_DIR/ospd-openvas.service /etc/systemd/system/



# ————— gvmd ———————————————————————————————————————————————————
infoi "Creating systemd service file for gvmd..."
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

infoi "Installing systemd service file for gvmd..."
sudo cp -v $BUILD_DIR/gvmd.service /etc/systemd/system/


# ————— gsad ———————————————————————————————————————————————————
if [ HTTP = "HTTPS" ]; then
# https
infoi "Creating HTTPS systemd service file for gsad..."
cat << EOF > $BUILD_DIR/gsad.service
[Unit]
Description=Greenbone Security Assistant daemon (gsad)
Documentation=man:gsad(8) https://www.greenbone.net
After=network.target gvmd.service
Wants=gvmd.service

[Service]
Type=exec
#User=gvm
#Group=gvm
RuntimeDirectory=gsad
RuntimeDirectoryMode=2775
PIDFile=/run/gsad/gsad.pid
ExecStart=/usr/local/sbin/gsad --foreground --listen=${GVM_CERTIFICATE_SAN_DNS} --port=443 --rport=80 --ssl-private-key=/var/lib/gvm/private/CA/clientkey.pem --ssl-certificate=/var/lib/gvm/CA/clientcert.pem
Restart=always
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
Alias=greenbone-security-assistant.service
EOF

else

# http
infoi "Creating HTTP systemd service file for gsad..."
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
fi

infoi "Installing systemd service file for gsad..."
sudo cp -v $BUILD_DIR/gsad.service /etc/systemd/system/



# ————— openvasd ———————————————————————————————————————————————
infoi "Creating systemd service file for openvasd..."
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

infoi "Installing systemd service file for openvasd..."
sudo cp -v $BUILD_DIR/openvasd.service /etc/systemd/system/

infoi "Activating and starting new service files..."
sudo systemctl daemon-reload



# ————— Install cert for https ———————————————————————————————
# Read this for documentation
# https://github.com/greenbone/gvmd/blob/main/tools/gvm-manage-certs.in

if [ HTTP == "https" ]; then
    infoi "Installing SSL Certs..."
    runuser -u gvm -- gvm-manage-certs -aqf
fi



# ————— Feed sync ——————————————————————————————————————————————
infoi "Performing feed sync..."
warni "This might take a while..."
sudo /usr/local/bin/greenbone-feed-sync


# ————— Start services —————————————————————————————————————————
infoi "Setting services to run on system startup..."
sudo systemctl enable ospd-openvas
sudo systemctl enable gvmd
sudo systemctl enable gsad
sudo systemctl enable openvasd

# systemctl is-enabled ospd-openvas gvmd gsad openvasd
# if [ $? -eq 0 ]; then
#     successi "All service files enabled."
# else
#     error "Couldn't enable system files. Do this manually."


infoi "Starting all services..."
sudo systemctl start ospd-openvas
sudo systemctl start gvmd
sudo systemctl start gsad
sudo systemctl start openvasd
sleep 3

# Stop services
# sudo systemctl stop ospd-openvas
# sudo systemctl stop gvmd
# sudo systemctl stop gsad
# sudo systemctl stop openvasd
# sudo systemctl stop ospd-openvas && sudo systemctl stop gvmd && sudo systemctl stop gsad && sudo systemctl stop openvasd

# Restart services
# sudo systemctl restart ospd-openvas
# sudo systemctl restart gvmd
# sudo systemctl restart gsad
# sudo systemctl restart openvasd
# sudo systemctl restart ospd-openvas && sudo systemctl restart gvmd && sudo systemctl restart gsad && sudo systemctl restart openvasd


infoi "Checking status of services..."
all_running=true
# sudo systemctl status ospd-openvas
# sudo systemctl status gvmd
# sudo systemctl status gsad
# sudo systemctl status openvasd


service_name="ospd-openvas"
status_output=$(systemctl status "$service_name")

if [[ "$status_output" =~ "Active: active (running)" ]]; then
    successi "Service '$service_name' is running."
elif [[ "$status_output" =~ "Active: inactive" ]]; then
    all_running=false
    errori "Service '$service_name' is not running."
else
    all_running=false
    warn "Service '$service_name' is in an unknown state: $status_output"
fi

service_name="gvmd"
status_output=$(systemctl status "$service_name")

if [[ "$status_output" =~ "Active: active (running)" ]]; then
    successi "Service '$service_name' is running."
elif [[ "$status_output" =~ "Active: inactive" ]]; then
    all_running=false
    error "Service '$service_name' is not running."
else
    all_running=false
    warn "Service '$service_name' is in an unknown state: $status_output"
fi

service_name="gsad"
status_output=$(systemctl status "$service_name")

if [[ "$status_output" =~ "Active: active (running)" ]]; then
    successi "Service '$service_name' is running."
elif [[ "$status_output" =~ "Active: inactive" ]]; then
    all_running=false
    error "Service '$service_name' is not running."
else
    all_running=false
    warn "Service '$service_name' is in an unknown state: $status_output"
fi

service_name="openvasd"
status_output=$(systemctl status "$service_name")

if [[ "$status_output" =~ "Active: active (running)" ]]; then
    successi "Service '$service_name' is running."
elif [[ "$status_output" =~ "Active: inactive" ]]; then
    all_running=false
    error "Service '$service_name' is not running."
else
    all_running=false
    warn "Service '$service_name' is in an unknown state: $status_output"
fi



# ————— Remove tmp files ———————————————————————————————————————
infoi "Removing temp files..."
rm /tmp/GBCommunitySigningKey.asc
rm -rf /tmp/openvas-gnupg
echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:2:" | gpg --import-ownertrust



# ————— Complete message ———————————————————————————————————————
if [ all_running = true ]; then
    echo
    successi "Greenbone Community Edition install is completed!"
    echo
else
    echo
    errori "Greenbone Community Edition install is incomplete! Check console for errors!"
    echo
fi


# ————— Start gsa interface ————————————————————————————————————
infoi "Starting GSA interface..."
infoi "If your browser doesn't open. Go to:"
infoi "HTTP: http://127.0.0.1:9392"
infoi "HTTPS: https://${GVM_CERTIFICATE_SAN_DNS}"

if [ HTTP = "HTTPS" ]; then
    xdg-open "https://${GVM_CERTIFICATE_SAN_DNS}" 2>/dev/null >/dev/null &
else
    xdg-open "http://127.0.0.1:9392" 2>/dev/null >/dev/null &
fi

# if [ HTTP = "HTTPS" ]; then
#     xdg-open "https://127.0.0.1:443" 2>/dev/null >/dev/null &
# else
#     xdg-open "http://127.0.0.1:9392" 2>/dev/null >/dev/null &
# fi


