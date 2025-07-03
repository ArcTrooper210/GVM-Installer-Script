#!/bin/bash

# ————— Variables ——————————————————————————————————————————————
INSTALLER_VERSION="v1.0.0"
LAST_UPDATED="2025-07-02"
HTTP="https"

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
success ()  { echo -e "\e[92m[ OK ]  $1\e[0m"; }
info ()     { echo -e "\e[94m[INFO]  $1\e[0m"; }
warn ()     { echo -e "\e[33m[WARN]  $1\e[0m"; }
error ()    { echo -e "\e[31m[ERROR] $1\e[0m"; }

successi () { echo -e "\e[92m[>] $1\e[0m"; }
infoi ()    { echo -e "\e[94m[i] $1\e[0m"; }
warni ()    { echo -e "\e[33m[-] $1\e[0m"; }
errori ()   { echo -e "\e[31m[!] $1\e[0m"; }

check_sig () {
    if ! grep -xqF 'Good signature from "Greenbone Community Feed integrity key"' <<< "$SIG_OUTPUT"; then
        success "Good signature."
        sleep 2
    else
        errori "Bad signature."
        exit 1
    fi
}

curl_download () {
	local URL="$1"
	local OUTPUT="$2"
	if curl -fLo "$OUTPUT" "$URL"; then
        successi "Downloaded ${INFO}$URL${CLR} to ${INFO}$OUTPUT${CLR}"
        sleep 2
	else
        error "Failed to download $URL"
		exit 1
    fi
}

show_help () {
	echo
	echo "valid arguments:"
    echo "--help            Show this help page"
	echo "--http            Install GVM with insecure http"
	echo "--start           Start all GVM Services"
	echo "--stop            Stop all GVM Services"
	echo "--status          Prints status of all GVM Services"
	echo "--restart         Restarts all GVM Services"
	echo "--uninstall       Uninstall GVM"
	echo
    exit 0
}

start_services () {
    local SERVICES=("ospd-openvas" "gvmd" "gsad" "openvasd")
    ALL_RUNNING=true
    infoi "Starting all Greenbone processes..."

    sudo systemctl start ospd-openvas gvmd gsad openvasd 2>/dev/null
    sleep 3

    for SERVICE_NAME in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            successi "Service '$SERVICE_NAME' started successfully."
        else
            errori "Service '$SERVICE_NAME' failed to start."
            ALL_RUNNING=false
        fi
    done

    if [ $ALL_RUNNING = true ]; then
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
    local SERVICES=("ospd-openvas" "gvmd" "gsad" "openvasd")
    local ALL_STOPPED=true
    infoi "Stopping all Greenbone processes..."

    sudo systemctl stop ospd-openvas gvmd gsad openvasd 2>/dev/null
    sleep 3

    for SERVICE_NAME in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            errori "Service '$SERVICE_NAME' failed to stop."
            ALL_STOPPED=false
        else
            successi "Service '$SERVICE_NAME' stopped successfully."
        fi
    done

    if [ $ALL_STOPPED = true ]; then
        echo
        success "All Greenbone processes stopped."
        echo
    else
        echo
        error "Failed to stop all processes."
        echo
        exit 1
    fi
}

restart_services () {
    local SERVICES=("ospd-openvas" "gvmd" "gsad" "openvasd")
    local ALL_RUNNING=true
    infoi "Starting all Greenbone processes..."

    systemctl restart ospd-openvas gvmd gsad openvasd 2>/dev/null
    sleep 3

    for SERVICE_NAME in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            successi "Service '$SERVICE_NAME' restarted successfully."
        else
            errori "Service '$SERVICE_NAME' failed to restart."
            ALL_RUNNING=false
        fi
    done

    if [ "$ALL_RUNNING" = true ]; then
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
    infoi "Checking status of Greenbone processes..."

    local SERVICE_NAME="ospd-openvas"
    local STATUS_OUTPUT=$(systemctl status "$SERVICE_NAME")

    if [[ "$STATUS_OUTPUT" =~ "Active: active (running)" ]]; then
        successi "Service '$SERVICE_NAME' is running."
    elif [[ "$STATUS_OUTPUT" =~ "Active: inactive" ]]; then
        errori "Service '$SERVICE_NAME' is not running."
    else
        warni "Service '$SERVICE_NAME' is in an unknown state: $STATUS_OUTPUT"
    fi

    local SERVICE_NAME="gvmd"
    local STATUS_OUTPUT=$(systemctl status "$SERVICE_NAME")

    if [[ "$STATUS_OUTPUT" =~ "Active: active (running)" ]]; then
        successi "Service '$SERVICE_NAME' is running."
    elif [[ "$STATUS_OUTPUT" =~ "Active: inactive" ]]; then
        errori "Service '$SERVICE_NAME' is not running."
    else
        warni "Service '$SERVICE_NAME' is in an unknown state: $STATUS_OUTPUT"
    fi

    local SERVICE_NAME="gsad"
    local STATUS_OUTPUT=$(systemctl status "$SERVICE_NAME")

    if [[ "$STATUS_OUTPUT" =~ "Active: active (running)" ]]; then
        successi "Service '$SERVICE_NAME' is running."
    elif [[ "$STATUS_OUTPUT" =~ "Active: inactive" ]]; then
        errori "Service '$SERVICE_NAME' is not running."
    else
        warni "Service '$SERVICE_NAME' is in an unknown state: $STATUS_OUTPUT"
    fi

    local SERVICE_NAME="openvasd"
    local STATUS_OUTPUT=$(systemctl status "$SERVICE_NAME")

    if [[ "$STATUS_OUTPUT" =~ "Active: active (running)" ]]; then
        successi "Service '$SERVICE_NAME' is running."
    elif [[ "$STATUS_OUTPUT" =~ "Active: inactive" ]]; then
        errori "Service '$SERVICE_NAME' is not running."
    else
        warni "Service '$SERVICE_NAME' is in an unknown state: $STATUS_OUTPUT"
    fi
}

admin_setup () {
    local CONFIRMU=0
    local CONFIRMP=0
    while [ $CONFIRMU -lt 1 ]; do
        read -p "Set username for admin user: " ADUSER
        if [ -z "$ADUSER" ]; then
            warni "Username cannot be empty!"
            CONFIRMU=0
        else
            successi "Admin username set to: $ADUSER"
            CONFIRMU=1
        fi
    done

    while [ $CONFIRMP -lt 1 ]; do
        read -sp "Set password for admin user: " ADPW
        if [ -z "$ADPW" ]; then
            echo
            warni "Password cannot be empty!"
            CONFIRMP=0
        else
            echo
            read -sp "Confirm password for admin user: " ADPW2
            if [ -z "$ADPW2" ]; then
                echo
                warni "Password cannot be empty!"
                CONFIRMP=0
            else
                if [ "$ADPW" == "$ADPW2" ]; then
                    echo
                    successi "Admin password successfully set."
                    CONFIRMP=1
                else
                    echo
                    warni "Passwords do not match"
                    CONFIRMP=0
                fi
            fi
        fi
    done
}

domain_validation () {
    local USERDOMAIN="$1"
    # Checks for alphanum, <63 char length label, and contains >2 labels
    local REGEX='^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}$'

    # Check if domain name is <253 characters long
    if (( ${#USERDOMAIN} > 253 )); then
        return 1
    fi

    # Final check
    if ! [[ $USERDOMAIN =~ $REGEX ]]; then
        return 1
    fi
}

prev_install_check () {
    local PROGRAM=("ospd-openvas" "gvmd" "gsad" "openvasd")
    for PROG_NAME in "${PROGRAM[@]}"; do
        if command -v "$PROG_NAME" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

prepare_update () {
    stop_services
    sleep 3

    local INSTALLED_GVMD_VERSION=$(sudo gvmd --version | head -n1 | awk '{print $4}')
    if dpkg --compare-versions "$INSTALLED_GVMD_VERSION" lt "$GVMD_VERSION"; then
        for PKG in ospd-openvas greenbone-feed-sync gvm-tools; do
            if python3 -m pip show $PKG >/dev/null 2>&1; then
                infoi "Uninstalling '$PKG'..."
                python3 -m pip uninstall --break-system-packages -y $PKG >/dev/null 2>&1
                if [ $? -ne 0 ]; then
                    error "Failed to automatically uninstall old Python GVM modules. Manually uninstall and run script again."
                    error "sudo python3 -m pip uninstall --break-system-packages -y $PKG"
                    exit 1
                fi
            fi
        done
    fi
}

check_setup () {
    CHECK_PASSED=true

    services_status

    infoi "Checking for GVMD..."
    if gvmd --version; then
        success "GVMD"
    else
        error "GVMD not found. Please install GVMD"
        CHECK_PASSED=false

    fi

    infoi "Checking for GSAD..."
    if gsad --version; then
        success "GSAD"
    else
        error "GSAD not found. Please install GSAD"
        CHECK_PASSED=false
    fi

    infoi "Checking for Openvas..."
    if openvas --version; then
        success "Openvas"
    else
        error "Openvas not found. Please install Openvas"
        CHECK_PASSED=false
    fi

    if [ $HTTP = "https" ]; then
        infoi "Validating GVM certificates..."
        if gvm-manage-certs -V; then
            success "GVM certificates passed validation"
        else
            error "GVM certificates did not pass validation"
            infoi "Run: 'gvm-manage-certs -aqf' to generate new certificates"
            CHECK_PASSED=false
        fi
    fi
}

uninstall_greenbone () {
    while true; do
        read -p "Proceed with uninstall? (y/n)" yn
        case $yn in
            [yY] )
                successi "Continuing with uninstall...";
                break;;
            [nN] )
                warni "Cancelling uninstall...";
                exit 0;;
            * ) 
                errori "Invalid response";;
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
    	--http)
            infoi "HTTP Install selected..."
            HTTP="http";;
        --help|-h)
            show_help;;
        --uninstall)
            uninstall_greenbone;;
        --start)
            start_services;;
        --stop)
            stop_services
            exit 0;;
        --restart)
            restart_services;;
        --status)
            services_status
            exit 0;;
        *)
            warni "Invalid argument(s). Use --help to view valid arguments."
            exit 1;;
    esac
    shift
fi


# ————— Check sudo —————————————————————————————————————————————
if [[ $UID -ne 0 ]]; then
    warni "Run script with sudo"
	exit 1
fi

echo "Installer version: $INSTALLER_VERSION"
echo "Last updated $((($(date +%s)-$(date +%s --date $LAST_UPDATED))/(3600*24))) days ago ($LAST_UPDATED)"

LATEST_TAG=$(curl -sSL "https://api.github.com/repos/ArcTrooper210/GVM-Installer-Script/releases/latest" | jq -r .tag_name)
if [ -z "$LATEST_TAG" ]; then
    error "Could not determine latest release (API error or invalid tag)."
    exit 1
else
    VER_LATEST=${LATEST_TAG:1}
    VER_INST=${INSTALLER_VERSION:1}
    if dpkg --compare-versions "$VER_INST" lt "$VER_LATEST"; then
        echo "✨ A new version is available: $LATEST_TAG (you have $INSTALLER_VERSION)."
        echo "🔗 Release notes: https://github.com/ArcTrooper210/GVM-Installer-Script/releases/latest"
    elif dpkg --compare-versions "$VER_INST" gt "$VER_LATEST"; then
        echo -e "\e[2m\e[1m\e[31mHow do you have a version newer than release...\e[0m"
    else
        successi "You have the latest version"
    fi
fi

info "Use with --help|-h for more options."
echo

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


# ————— Ask user to set admin username and password ————————————
infoi "Setup GVM administrator credentials..."
admin_setup


# ————— If https, then ask for domain name —————————————————————
infoi "Set custom domain name for HTTPS GSAD."
if [ $HTTP = "https" ]; then
    VALID_DOMAIN=0
    while [ $VALID_DOMAIN -lt 1 ]; do
        read -p "Enter a custom domain name: " USERDOMAIN
        if [ -z "$USERDOMAIN" ]; then
            warn "Domain name cannot be empty!"
            VALID_DOMAIN=0
        else
            if domain_validation "$USERDOMAIN"; then
                successi "Domain name set to: $USERDOMAIN"
                export GVM_CERTIFICATE_SAN_DNS="$USERDOMAIN"
                VALID_DOMAIN=1
            else
                error "Invalid domain name."
                warni "Domain name rules:"
                echo -e "\e[33m   [-] Only alphanum characters (A-Z,a-z,0-9)\e[0m"
                echo -e "\e[33m   [-] No special characters (only periods allowed)\e[0m"
                echo -e "\e[33m   [-] No spaces\e[0m" 
                echo -e "\e[33m   [-] Has at least 2 labels (e.g. 'my.domain' or 'mydomain.com', not just 'domain' or '.com')\e[0m"
                VALID_DOMAIN=0
            fi
        fi
    done
fi


# ————— Checking for previous GVM install ——————————————————————
infoi "Checking for previous GVM install..."
if prev_install_check; then
    warni "Previous install found..."
    infoi "Preparing for update..."
    prepare_update
else
    infoi "No previous install found"
fi


# ————— Check for running GVM processes ————————————————————————
SERVICES=("ospd-openvas" "gvmd" "gsad" "openvasd")
ALL_STOPPED=true
infoi "Checking for running Greenbone Processes..."

for SERVICE_NAME in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME" 2>/dev/null
    else
        continue
    fi
done

sleep 3

for SERVICE_NAME in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        errori "Service '$SERVICE_NAME' failed to stop."
        ALL_STOPPED=false
    else
        continue
    fi
done

if [ "$ALL_STOPPED" != true ]; then
    error "Failed to stop all processes. Manually stop all Greenbone processes before installing."
    exit 1
fi
unset ALL_STOPPED SERVICES


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

SIG_OUTPUT=$(gpg --verify $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz)
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

SIG_OUTPUT=$(gpg --verify $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz.asc $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz)
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

SIG_OUTPUT=$(gpg --verify $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz.asc $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz)
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

SIG_OUTPUT=$(gpg --verify $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz.asc $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz)
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

SIG_OUTPUT=$(gpg --verify $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz.asc $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz)
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

SIG_OUTPUT=$(gpg --verify $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz.asc $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz)
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

SIG_OUTPUT=$(gpg --verify $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz)
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

SIG_OUTPUT=$(gpg --verify $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz.asc $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz)
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

SIG_OUTPUT=$(gpg --verify $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz)
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
echo "db_address = /run/redis-openvas/redis.sock" | sudo tee -a /etc/openvas/openvas.conf

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

infoi "Setting up PostpreSQL..."
su - postgres -c "createuser -DRS gvm"
su - postgres -c "createdb -O gvm gvmd"
su - postgres -c "psql gvmd -q --command='create role dba with superuser noinherit;'"
su - postgres -c "psql gvmd -q --command='grant dba to gvm;'"

infoi "Restarting PostpreSQL..."
systemctl restart postgresql@16-main


# ————— Setting up an Admin User ———————————————————————————————
infoi "Creating admin user..."
/usr/local/sbin/gvmd --create-user="$ADUSER" --password="$ADPW"
if [ $? -eq 0 ]; then
    successi "Successfully created admin user"
else
    error "Failed to create admin user. Check /var/log/gvm/gvmd.log"
    exit 1
fi
unset ADPW


# ————— Setting feed owner —————————————————————————————————————
infoi "Setting feed import owner..."
FEED_OWNER_UID=$(/usr/local/sbin/gvmd --get-users --verbose | grep "$ADUSER" | awk '{print $2}') &&
/usr/local/sbin/gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value $FEED_OWNER_UID
unset FEED_OWNER_UID ADUSER


# ————— Setting up service files for systemd ————————————————————————
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
if [ $HTTP = "https" ]; then
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
ExecStart=/usr/local/sbin/gsad --foreground --listen=127.0.0.1 --port=9392 --rport=80 --ssl-private-key=/var/lib/gvm/private/CA/clientkey.pem --ssl-certificate=/var/lib/gvm/CA/clientcert.pem
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
if [ $HTTP = "https" ]; then
    infoi "Installing SSL Certs..."
    runuser -u gvm -- gvm-manage-certs -aqf

    infoi "Adding domain name to hosts file..."
    if ! cp /etc/hosts /tmp/hosts; then
        errori "Error while copying. File doesn't exist or not enough permissions."
    else
        echo "127.0.0.1 ${GVM_CERTIFICATE_SAN_DNS}" >>/tmp/hosts
        cp /tmp/hosts /etc/hosts
    fi

    host_check=$(tail -n1 /etc/hosts)
    if [[ "$host_check" != "127.0.0.1 ${GVM_CERTIFICATE_SAN_DNS}" ]]; then
        error "Failed to add host to hosts file..."
        warni "Manually add domain name to /etc/hosts file. '127.0.0.1 ${GVM_CERTIFICATE_SAN_DNS}'"
    fi
fi
unset host_check

# ————— Feed sync ——————————————————————————————————————————————
infoi "Performing feed sync..."
warni "This might take a while..."
sudo /usr/local/bin/greenbone-feed-sync


# ————— Start services —————————————————————————————————————————
infoi "Setting services to run on system startup..."
systemctl enable ospd-openvas
systemctl enable gvmd
systemctl enable openvasd
systemctl enable gsad

if systemctl is-enabled ospd-openvas gvmd gsad openvasd &>/dev/null; then
    successi "All service files enabled."
else
    error "Couldn't enable system files. Do this manually."
    sleep 5
fi


infoi "Starting all services..."
sudo systemctl start ospd-openvas gvmd openvasd gsad


# ————— Create feed sync cron job ——————————————————————————————
# Write current user's cron jobs to file
sudo crontab -l > /tmp/feed_sync_cron 2>/dev/null
# Append a run feed-sync every 3 months cron job
echo "0 1 1 3,6,9,12 * /usr/local/bin/greenbone-feed-sync --type ALL >> /var/log/gvm/feed-sync.log 2>&1" >> /tmp/feed_sync_cron
# Install new cron file
crontab /tmp/feed_sync_cron


# ————— Remove tmp files ———————————————————————————————————————
infoi "Removing temporary files..."
# warni "If it says folder not found, ignore and continue..."
# rm /tmp/GBCommunitySigningKey.asc
# rm -rf /tmp/openvas-gnupg
# rm /tmp/hosts
rm /tmp/feed_sync_cron
echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:2:" | gpg --import-ownertrust


# ————— Complete message ———————————————————————————————————————

if [[ $ALL_RUNNING = true && $CHECK_PASSED = true ]]; then
    echo
    successi "Greenbone Community Edition install is completed!"
    echo
    infoi "You can change the password with:"
    infoi "sudo gvmd --user='yourCurrentUsername' --new-password='yourNewPassword'"
    echo
    infoi "You can change the username with:"
    infoi "sudo gvmd --create-user='yourNewUsername' --password='yourPassword' --role=Admin"
    infoi "sudo gvmd --delete-user='yourOldUsername' --inheritor='yourNewUsername'"
    echo
else
    echo
    errori "Greenbone Community Edition install is incomplete! Check console for errors!"
    echo
fi


# ————— Start gsa interface ————————————————————————————————————
if [ $ALL_RUNNING = true ]; then
    infoi "Starting GSA interface..."
    if [ $HTTP = "https" ]; then
        infoi "If your browser doesn't open. Go to: https://${GVM_CERTIFICATE_SAN_DNS}:9392"
        xdg-open "https://${GVM_CERTIFICATE_SAN_DNS}:9392" 2>/dev/null >/dev/null &
    else
        infoi "If your browser doesn't open. Go to: http://127.0.0.1:9392"
        xdg-open "http://127.0.0.1:9392" 2>/dev/null >/dev/null &
    fi
fi
