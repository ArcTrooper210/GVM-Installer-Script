#!/bin/bash

# ————— Variables ——————————————————————————————————————————————
INSTALLER_VERSION="v2.0.0"
LAST_UPDATED="2025-09-19"
HTTP="https"
LOG=gvmInstaller.log
CHECK_LOG=gvmChecksSetup.log
FIX_LOG=gvmFixesNeeded.log
UNINSTALL_LOG=gvmUninstall.log
SKIP_DEPENDENCIES=false

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
# GVM_LIBS_VERSION=22.27.0
# GVMD_VERSION=26.2.1
# PG_GVM_VERSION=22.6.11
# GSA_VERSION=25.3.1
# GSAD_VERSION=24.5.4
# OPENVAS_SMB_VERSION=22.5.10
# OPENVAS_SCANNER_VERSION=23.23.1
# OSPD_OPENVAS_VERSION=22.9.0
# OPENVAS_DAEMON=23.23.1

# ————— Functions ——————————————————————————————————————————————
success ()  { echo -e "\e[92m[ OK ]  $1\e[0m"; }
successc () { echo -e "    \e[92m[ OK ]  $1\e[0m"; }
info ()     { echo -e "\e[94m[INFO]  $1\e[0m"; }
infoc ()    { echo -e "    \e[94m[INFO]  $1\e[0m"; }
warn ()     { echo -e "\e[33m[WARN]  $1\e[0m"; }
error ()    { echo -e "\e[31m[ERROR] $1\e[0m"; }
errorc ()   { echo -e "    \e[31m[ERROR] $1\e[0m"; }

successi ()     { echo -e "\e[92m[>] $1\e[0m"; }
successic ()    { echo -e "    \e[92m[>] $1\e[0m"; }
infoi ()        { echo -e "\e[94m[i] $1\e[0m"; }
infoic ()       { echo -e "    \e[94m[i] $1\e[0m"; }
warni ()        { echo -e "\e[33m[-] $1\e[0m"; }
errori ()       { echo -e "\e[31m[!] $1\e[0m"; }
erroric ()      { echo -e "    \e[31m[!] $1\e[0m"; }

# ————— Flag functions —————————————————————————————————————————
show_help () {
	echo
	echo "valid arguments:"
    echo "--help|-h             Shows this help page"
	echo "--start               Starts all GVM Services"
	echo "--stop                Stops all GVM Services"
	echo "--restart             Restarts all GVM Services"
	echo "--status              Prints status of all GVM Services"
	echo "--no-dependencies     Runs script without installing dependencies"
    echo "--check-setup         Checks for proper GVM installation"
	echo
	echo "These arguments will install specific modules:"
    echo "--install-gvm-libs            Is a dependency of openvas-scanner, gvmd, gsad and pg-gvm"
    echo "--install-gvmd                gvmd is the main service of Greenbone"
    echo "--install-pg-gvm              pg-gvm is a PostgreSQL extension used by gvmd"
    echo "--install-gsa                 gsa is a JavaScript web application"
    echo "--install-gsad                gsad serves static content like images and provides an API for gsa"
    echo "--install-openvas-smb         openvas-smb is a helper module for openvas-scanner"
    echo "--install-openvas-scanner     openvas-scanner is a scan engine that executes Vulnerability Tests (VTs)"
    echo "--install-ospd-openvas        ospd-openvas allows gvmd to remotely control openvas-scanner"
    echo "--install-openvasd            OpenVASD is used for detecting vulnerable products"
    echo "--install-feed-sync           greenbone-feed-sync is a Python script to download feed data from the Greenbone Community Feed"
    echo "--install-gvm-tools           gvm-tools are a collection of tools that help with controlling Greenbone installations"
    echo "--install-redis-server        Redis key/value storage is used by the scanner for handling the VT info and scan results"
    echo "--install-postgresql          PostgreSQL is used as a central storage for user and scan information for gvmd"
    echo "--set-scan-permissions        Gives vulnurability scanner proper sudo permissions"
    echo "--servicefile-ospd-openvas    Creates ospd-openvas service file"
    echo "--servicefile-gvmd            Creates gvmd service file"
    echo "--servicefile-gsad            Creates gsad service file"
    echo "--servicefile-openvasd        Creates openvasd service file"
    echo "--feed-validation             Installs Greenbone GnuPG keychain to validate feed content"
    echo "--create-cronjob              Creates a cronjob to run greenbone-feed-sync every quarter"
    echo "--create-gvm-user             Creates gvm user and group"
    echo "--install-dependencies        Installs Greenbone apt dependencies"
    echo
}

check_existing_log () {
    if [[ -e $LOG && -s $LOG ]]; then
        mv -T $LOG "${LOG%%.*}"-backup."${LOG##*.}"
        true > $LOG
    fi

    if [[ -e $CHECK_LOG && -s $CHECK_LOG ]]; then
        mv -T $CHECK_LOG "${CHECK_LOG%%.*}"-backup."${CHECK_LOG##*.}"
        true > $CHECK_LOG
    fi

    if [[ -e $FIX_LOG && -s $FIX_LOG ]]; then
        mv -T $FIX_LOG "${FIX_LOG%%.*}"-backup."${FIX_LOG##*.}"
        true > $FIX_LOG
    fi
}

start_services () {
    local SERVICES=("ospd-openvas" "gvmd" "gsad" "openvasd")
    ALL_RUNNING=true
    infoi "Starting all Greenbone processes..."

    sudo systemctl start ospd-openvas gvmd gsad openvasd 2>/dev/null
    sleep 3

    for SERVICE_NAME in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            successic "$SERVICE_NAME started successfully."
        else
            erroric "$SERVICE_NAME failed to start."
            ALL_RUNNING=false
        fi
    done

    if [ $ALL_RUNNING = true ]; then
        echo
        success "All Greenbone processes successfully started"
        echo
    else
        echo
        error "Not all processes started"
        echo
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
            erroric "$SERVICE_NAME failed to stop."
            ALL_STOPPED=false
        else
            successic "$SERVICE_NAME stopped successfully."
        fi
    done

    if [ $ALL_STOPPED = true ]; then
        return 0
    else
        return 1
    fi
}

restart_services () {
    local SERVICES=("ospd-openvas" "gvmd" "gsad" "openvasd")
    local ALL_RUNNING=true
    infoi "Restarting all Greenbone processes..."

    systemctl restart ospd-openvas gvmd gsad openvasd 2>/dev/null
    sleep 3

    for SERVICE_NAME in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            successic "$SERVICE_NAME restarted successfully."
        else
            erroric "$SERVICE_NAME failed to restart."
            ALL_RUNNING=false
        fi
    done

    if [ "$ALL_RUNNING" = true ]; then
        return 0
    else
        return 1
    fi
}

services_status () {
    infoi "Checking status of Greenbone processes..."

    local SERVICE_NAME="ospd-openvas"
    local STATUS_OUTPUT=$(systemctl status "$SERVICE_NAME")

    if [[ "$STATUS_OUTPUT" =~ "Active: active (running)" ]]; then
        successi "$SERVICE_NAME is running."
    elif [[ "$STATUS_OUTPUT" =~ "Active: inactive" ]]; then
        errori "$SERVICE_NAME is not running."
    else
        warni "$SERVICE_NAME is in an unknown state: $STATUS_OUTPUT"
    fi

    local SERVICE_NAME="gvmd"
    local STATUS_OUTPUT=$(systemctl status "$SERVICE_NAME")

    if [[ "$STATUS_OUTPUT" =~ "Active: active (running)" ]]; then
        successi "$SERVICE_NAME is running."
    elif [[ "$STATUS_OUTPUT" =~ "Active: inactive" ]]; then
        errori "$SERVICE_NAME is not running."
    else
        warni "$SERVICE_NAME is in an unknown state: $STATUS_OUTPUT"
    fi

    local SERVICE_NAME="gsad"
    local STATUS_OUTPUT=$(systemctl status "$SERVICE_NAME")

    if [[ "$STATUS_OUTPUT" =~ "Active: active (running)" ]]; then
        successi "$SERVICE_NAME is running."
    elif [[ "$STATUS_OUTPUT" =~ "Active: inactive" ]]; then
        errori "$SERVICE_NAME is not running."
    else
        warni "$SERVICE_NAME is in an unknown state: $STATUS_OUTPUT"
    fi

    local SERVICE_NAME="openvasd"
    local STATUS_OUTPUT=$(systemctl status "$SERVICE_NAME")

    if [[ "$STATUS_OUTPUT" =~ "Active: active (running)" ]]; then
        successi "$SERVICE_NAME is running."
    elif [[ "$STATUS_OUTPUT" =~ "Active: inactive" ]]; then
        errori "$SERVICE_NAME is not running."
    else
        warni "$SERVICE_NAME is in an unknown state: $STATUS_OUTPUT"
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
    local UNINSTALL_SUCCESS=true

# &>>UNINSTALL_LOG
    # Start uninstall process
    # Make sure to check if files exist in a location before uninstalling
    # Error handling



    # if [ $UNINSTALL_SUCCESS = "true" ]; then
    #     return 0
    # else
    #     return 1
    # fi
}

check_setup () {
    CHECK_PASSED=true
    
    info "Checking for proper GVM install..." | tee -a $CHECK_LOG
    infoi "Checking for GVMD..." | tee -a $CHECK_LOG
    gvmd --version &>>$CHECK_LOG
    if [[ $? -eq 0 ]]; then
        successc "GVMD is installed" | tee -a $CHECK_LOG
    else
        errorc "GVMD not found. Please install GVMD" | tee -a $CHECK_LOG
        CHECK_PASSED=false
    fi


    infoi "Checking for GSAD..." | tee -a $CHECK_LOG
    gsad --version &>>$CHECK_LOG
    if [[ $? -eq 0 ]]; then
        successc "GSAD is installed" | tee -a $CHECK_LOG
    else
        errorc "GSAD not found. Please install GSAD" | tee -a $CHECK_LOG
        CHECK_PASSED=false
    fi


    infoi "Checking for Openvas..." | tee -a $CHECK_LOG
    openvas --version &>>$CHECK_LOG
    if [[ $? -eq 0 ]]; then
        successc "Openvas is installed" | tee -a $CHECK_LOG
    else
        errorc "Openvas not found. Please install Openvas" | tee -a $CHECK_LOG
        CHECK_PASSED=false
    fi


    infoi "Checking for Postgresql" | tee -a $CHECK_LOG
    psql -V &>>$CHECK_LOG
    if [[ $? -eq 0 ]]; then
        successc "Postgresql is installed" | tee -a $CHECK_LOG
        local PSQL=true
    else
        errorc "Postgresql not found. Please install Postgresql" | tee -a $CHECK_LOG
        local PSQL=false
        CHECK_PASSED=false
    fi
    

    infoi "Checking for redis-server..." | tee -a $CHECK_LOG
    redis-server --version &>>$CHECK_LOG
    if [[ $? -eq 0 ]]; then
        successc "Redis-server is installed" | tee -a $CHECK_LOG

        infoi "Checking for proper redis-server config..." | tee -a $CHECK_LOG
        local REDISCONF=$(grep db_address /etc/openvas/openvas.conf | sed -e 's/^db_address = //') &>>$CHECK_LOG
        if [[ -z "$REDISCONF" ]]; then
            errorc "Scanner is not configured to use redis-scanner socket" | tee -a $CHECK_LOG
            infoic "Configure the db_address of openvas to use redis-server socket" | tee -a $CHECK_LOG
            CHECK_PASSED=false
        else
            successc "Redis-server is configured properly" | tee -a $CHECK_LOG
        fi
    else
        errorc "Redis-server not found" | tee -a $CHECK_LOG
        infoic "Install redis-server by running: sudo apt install -y redis-server" | tee -a $CHECK_LOG
        CHECK_PASSED=false
    fi
    

    infoi "Validating GVM certificates..." | tee -a $CHECK_LOG
    gvm-manage-certs -V &>>$CHECK_LOG
    if [[ $? -eq 0 ]]; then
        successc "GVM certificates passed validation" | tee -a $CHECK_LOG
    else
        errorc "GVM certificates did not pass validation" | tee -a $CHECK_LOG
        infoic "Generate new certificates by running: gvm-manage-certs -aqf" | tee -a $CHECK_LOG
        CHECK_PASSED=false
    fi


    infoi "Checking for users..." | tee -a $CHECK_LOG
    local admin=$(/usr/local/sbin/gvmd --get-users) &>>$CHECK_LOG
    if [[ -z "$admin" ]]; then
        errorc "No users found" | tee -a $CHECK_LOG
        infoic "Create a user by running: sudo gvmd --create-user=[name] --password=[password]" | tee -a $CHECK_LOG
        CHECK_PASSED=false
    else
        successc "At least one user exists" | tee -a $CHECK_LOG
    fi


    infoi "Checking feed import owner..." | tee -a $CHECK_LOG
    if [[ $PSQL = true ]]; then
        sudo -u gvm psql -d gvmd -c "SELECT uuid, name, value FROM settings WHERE uuid = '78eceaec-3385-11ea-b237-28d24461215b'" | sed -n '3p' | grep -qF "$FEED_OWNER_UID"
        if [[ $? -eq 0 ]]; then
            successc "Correct feed import owner set" | tee -a $CHECK_LOG
        else
            errorc "Feed import owner not set properly" | tee -a $CHECK_LOG
            infoic "Manually set feed owner by running: sudo /usr/local/sbin/gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value \`sudo /usr/local/sbin/gvmd --get-users --verbose | grep \$ADUSER | awk '{print \$2}'\`" | tee -a $CHECK_LOG | tee -a $FIX_LOG
            CHECK_PASSED=false
        fi
    else
        errorc "Feed import owner not found because Postgresql is not installed" | tee -a $CHECK_LOG | tee -a $FIX_LOG
        CHECK_PASSED=false
    fi


    infoi "Checking system unit files..."
    systemctl is-enabled --quiet ospd-openvas &>>$CHECK_LOG
    local ec=$?
    if [[ $ec -eq 0 ]]; then
        successc "ospd-openvas enabled." | tee -a $CHECK_LOG
    elif [[ $ec -eq 4 ]]; then
        erroric "ospd-openvas unit file doesn't exist!" | tee -a $CHECK_LOG
        infoic "Attempting to fix..." | tee -a $CHECK_LOG
        service_file_ospd_openvas
    else
        erroric "ospd-openvas not enabled." | tee -a $CHECK_LOG
        warni "Run: sudo systemctl enable ospd-openvas" | tee -a $CHECK_LOG
        CHECK_PASSED=false
    fi
    
    local SERVICE="gvmd"
    systemctl is-enabled --quiet $SERVICE &>>$CHECK_LOG
    ec=$?
    if [[ $ec -eq 0 ]]; then
        successc "$SERVICE enabled." | tee -a $CHECK_LOG
    elif [[ $ec -eq 4 ]]; then
        erroric "$SERVICE unit file doesn't exist!" | tee -a $CHECK_LOG
        infoic "Attempting to fix..." | tee -a $CHECK_LOG
        service_file_${SERVICE}
    else
        erroric "$SERVICE not enabled. Do this manually." | tee -a $CHECK_LOG
        warni "Run: sudo systemctl enable $SERVICE" | tee -a $CHECK_LOG
        CHECK_PASSED=false
    fi
    
    local SERVICE="gsad"
    systemctl is-enabled --quiet $SERVICE &>>$CHECK_LOG
    ec=$?
    if [[ $ec -eq 0 ]]; then
        successc "$SERVICE enabled." | tee -a $CHECK_LOG
    elif [[ $ec -eq 4 ]]; then
        erroric "$SERVICE unit file doesn't exist!" | tee -a $CHECK_LOG
        infoic "Attempting to fix..." | tee -a $CHECK_LOG
        service_file_${SERVICE}
    else
        erroric "$SERVICE not enabled. Do this manually." | tee -a $CHECK_LOG
        warni "Run: sudo systemctl enable $SERVICE" | tee -a $CHECK_LOG
        CHECK_PASSED=false
    fi
    
    local SERVICE="openvasd"
    systemctl is-enabled --quiet $SERVICE &>>$CHECK_LOG
    ec=$?
    if [[ $ec -eq 0 ]]; then
        successc "$SERVICE enabled." | tee -a $CHECK_LOG
    elif [[ $ec -eq 4 ]]; then
        erroric "$SERVICE unit file doesn't exist!" | tee -a $CHECK_LOG
        infoic "Attempting to fix..." | tee -a $CHECK_LOG
        service_file_${SERVICE}
    else
        erroric "$SERVICE not enabled. Do this manually." | tee -a $CHECK_LOG
        warni "Run: sudo systemctl enable $SERVICE" | tee -a $CHECK_LOG
        CHECK_PASSED=false
    fi


    info "Checking for running services"
    systemctl is-active ospd-openvas &>>$CHECK_LOG
    if [[ $? -eq 0 ]]; then
        successc "ospd-openvas is running" | tee -a $CHECK_LOG
    else
        errorc "ospd-openvas is not running" | tee -a $CHECK_LOG
        CHECK_PASSED=false
    fi

    systemctl is-active gvmd &>>$CHECK_LOG
    if [[ $? -eq 0 ]]; then
        successc "gvmd is running" | tee -a $CHECK_LOG
    else
        errorc "gvmd is not running" | tee -a $CHECK_LOG
        CHECK_PASSED=false
    fi

    systemctl is-active gsad &>>$CHECK_LOG
    if [[ $? -eq 0 ]]; then
        successc "gsad is running" | tee -a $CHECK_LOG
    else
        errorc "gsad is not running" | tee -a $CHECK_LOG
        CHECK_PASSED=false
    fi

    systemctl is-active openvasd &>>$CHECK_LOG
    if [[ $? -eq 0 ]]; then
        successc "openvasd is running" | tee -a $CHECK_LOG
    else
        errorc "openvasd is not running" | tee -a $CHECK_LOG
        CHECK_PASSED=false
    fi
}

# ————— Script functions ———————————————————————————————————————
check_sig () {
    gpg --verify $1 $2 &>>$LOG
    if [[ $? -eq 0 ]]; then
        success "Good signature." | tee -a $LOG
        sleep 2
    else
        errori "Bad signature. Integrity of the downloaded source files cannot be verified!" | tee -a $LOG
        exit 1
    fi
}

curl_download () {
	local URL="$1"
	local OUTPUT="$2"
	if curl -fLo "$OUTPUT" "$URL" &>>$LOG; then
        successi "Downloaded ${INFO}$URL${CLR} to ${INFO}$OUTPUT${CLR}" | tee -a $LOG
        sleep 2
	else
        error "Failed to download $URL" | tee -a $LOG
		exit 1
    fi
}

admin_setup () {
    local CONFIRMU=0
    local CONFIRMP=0
    while [ $CONFIRMU -lt 1 ]; do
        read -p "Set username for admin user: " ADUSER
        if [ -z "$ADUSER" ]; then
            warni "Username cannot be empty!" | tee -a $LOG
            CONFIRMU=0
        else
            successi "Admin username set to: $ADUSER" | tee -a $LOG
            export ADUSER | tee -a $LOG
            CONFIRMU=1
        fi
    done

    while (( $CONFIRMP < 1 )); do
        read -sp "Set password for admin user: " ADPW
        if [[ -z "$ADPW" ]]; then
            echo
            warni "Password cannot be empty!"
            continue
        else
            echo
            read -sp "Confirm password for admin user: " ADPW2
            if [[ -z "$ADPW2" ]]; then
                echo
                warni "Password cannot be empty!"
                continue
            else
                if [[ "$ADPW" == "$ADPW2" ]]; then
                    echo
                    successi "Admin password successfully set." | tee -a $LOG
                    CONFIRMP=1
                else
                    echo
                    warni "Passwords do not match"
                    continue
                fi
            fi
        fi
    done
}

set_domain_name () {
    local VALID_DOMAIN=0
    while [ $VALID_DOMAIN -lt 1 ]; do
        read -p "Enter a custom domain name: " USERDOMAIN
        if [ -z "$USERDOMAIN" ]; then
            warn "Domain name cannot be empty!" | tee -a $LOG
            VALID_DOMAIN=0
        else
            if domain_validation "$USERDOMAIN"; then
                successi "Domain name set to: $USERDOMAIN" | tee -a $LOG
                export GVM_CERTIFICATE_SAN_DNS="$USERDOMAIN"
                VALID_DOMAIN=1
            else
                error "Invalid domain name." | tee -a $LOG
                warni "Domain name rules:" | tee -a $LOG
                echo -e "\e[33m   [-] Only alphanum characters (A-Z,a-z,0-9)\e[0m"
                echo -e "\e[33m   [-] No special characters (only periods allowed)\e[0m"
                echo -e "\e[33m   [-] No spaces\e[0m" 
                echo -e "\e[33m   [-] Has at least 2 labels (e.g. 'my.domain' or 'mydomain.com'. Not 'domain' or '.com')\e[0m"
                VALID_DOMAIN=0
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
        if command -v "$PROG_NAME" &>>$LOG; then
            return 0
        fi
    done
    return 1
}

prepare_update () {
    stop_services
    sleep 3
    local INSTALLED_GVMD_VER=$(gvmd --version | head -n1 | awk '{print $4}' | tee -a $LOG)
    if dpkg --compare-versions "$INSTALLED_GVMD_VER" lt "$GVMD_VERSION"; then
        for PKG in ospd-openvas greenbone-feed-sync gvm-tools; do
            if python3 -m pip show $PKG  &>>$LOG; then
                infoi "Uninstalling '$PKG'..." | tee -a $LOG
                python3 -m pip uninstall --break-system-packages -y $PKG &>>$LOG
                if [[ $? -ne 0 ]]; then
                    error "Failed to automatically uninstall old Python GVM modules. Manually uninstall and run script again." | tee -a $LOG | tee -a $FIX_LOG
                    error "Run: sudo python3 -m pip uninstall --break-system-packages -y $PKG" | tee -a $LOG | tee -a $FIX_LOG
                    exit 1
                fi
            fi
        done
    fi
}

install_dependencies () {
    infoi "Updating packages..." | tee -a $LOG
    apt-get update -qy &>>$LOG
    apt-get upgrade -qy &>>$LOG
    infoi "Installing Dependencies..." | tee -a $LOG
    NEEDRESTART_MODE=a apt-get install --no-install-recommends -qy build-essential curl cmake pkg-config python3 python3-pip gnupg libcjson-dev libcurl4-gnutls-dev libgcrypt-dev libglib2.0-dev libgnutls28-dev libgpgme-dev libhiredis-dev libnet1-dev libpaho-mqtt-dev libpcap-dev libssh-dev libxml2-dev uuid-dev libldap2-dev libradcli-dev libbsd-dev libical-dev libpq-dev postgresql-server-dev-all rsync xsltproc dpkg fakeroot gnutls-bin gpgsm nsis openssh-client python3-lxml rpm smbclient snmp socat sshpass texlive-fonts-recommended texlive-latex-extra wget xmlstarlet zip libbrotli-dev libmicrohttpd-dev gcc-mingw-w64 libpopt-dev libunistring-dev heimdal-multidev perl-base bison libgcrypt20-dev libksba-dev nmap libjson-glib-dev krb5-multidev libsnmp-dev python3-setuptools python3-packaging python3-wrapt python3-cffi python3-psutil python3-defusedxml python3-paramiko python3-redis python3-gnupg python3-paho-mqtt libssl-dev python3-venv postgresql python3-impacket rustup &>>$LOG

    infoi "Updating rustup..." | tee -a $LOG
    rustup default stable &>>$LOG
}

# ————— GVM component functions ————————————————————————————————
import_gpg_key () {
    infoi "Importing GB Signing Key..." | tee -a $LOG
    curl_download https://www.greenbone.net/GBCommunitySigningKey.asc /tmp/GBCommunitySigningKey.asc
    gpg --import /tmp/GBCommunitySigningKey.asc | tee -a $LOG
    echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" | gpg --import-ownertrust | tee -a $LOG
}

install_gvm_libs () {
    infoi "Downloading gvm-libs sources..." | tee -a $LOG
    curl_download https://github.com/greenbone/gvm-libs/archive/refs/tags/v$GVM_LIBS_VERSION.tar.gz $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz
    curl_download https://github.com/greenbone/gvm-libs/releases/download/v$GVM_LIBS_VERSION/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc

    check_sig $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz

    infoi "Extracting..." | tee -a $LOG
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz &>>$LOG

    infoi "Building gvm-libs..." | tee -a $LOG
    warni "This may take a while..." | tee -a $LOG
    mkdir -p $BUILD_DIR/gvm-libs &>>$LOG
    cmake \
        -S $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION \
        -B $BUILD_DIR/gvm-libs \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_BUILD_TYPE=Release \
        -DSYSCONFDIR=/etc \
        -DLOCALSTATEDIR=/var &>>$LOG
    cmake --build $BUILD_DIR/gvm-libs -j$(nproc) &>>$LOG

    infoi "Installing gvm-libs..." | tee -a $LOG
    mkdir -p $INSTALL_DIR/gvm-libs &>>$LOG && cd $BUILD_DIR/gvm-libs
    make DESTDIR=$INSTALL_DIR/gvm-libs install &>>$LOG
    cp -rv $INSTALL_DIR/gvm-libs/* / &>>$LOG
}

install_gvmd () {
    infoi "Downloading gvmd sources..." | tee -a $LOG
    curl_download https://github.com/greenbone/gvmd/archive/refs/tags/v$GVMD_VERSION.tar.gz $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz
    curl_download https://github.com/greenbone/gvmd/releases/download/v$GVMD_VERSION/gvmd-$GVMD_VERSION.tar.gz.asc $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz.asc

    check_sig $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz.asc $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz

    infoi "Extracting..." | tee -a $LOG
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz &>>$LOG

    infoi "Building gvmd..." | tee -a $LOG
    warni "This may take a while..." | tee -a $LOG
    mkdir -p $BUILD_DIR/gvmd &>>$LOG
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
        -DLOGROTATE_DIR=/etc/logrotate.d &>>$LOG
    cmake --build $BUILD_DIR/gvmd -j$(nproc) &>>$LOG

    infoi "Installing gvmd..." | tee -a $LOG
    mkdir -p $INSTALL_DIR/gvmd &>>$LOG && cd $BUILD_DIR/gvmd
    make DESTDIR=$INSTALL_DIR/gvmd install &>>$LOG
    cp -rv $INSTALL_DIR/gvmd/* / &>>$LOG

    if command -v gvmd &>>$LOG; then
        successi "gvmd successfully installed!" | tee -a $LOG
    else
        errori "Failed to install gvmd" | tee -a $LOG | tee -a $FIX_LOG
        infoi "View '$LOG' to check for errors, then run the script again with the --install-gvmd flag to install gvmd" | tee -a $LOG | tee -a $FIX_LOG
        exit 1
    fi
}

install_pg_gvm () {
    infoi "Downloading pg-gvm sources..." | tee -a $LOG
    curl_download https://github.com/greenbone/pg-gvm/archive/refs/tags/v$PG_GVM_VERSION.tar.gz $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz
    curl_download https://github.com/greenbone/pg-gvm/releases/download/v$PG_GVM_VERSION/pg-gvm-$PG_GVM_VERSION.tar.gz.asc $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz.asc

    check_sig $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz.asc $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz

    infoi "Extracting..." | tee -a $LOG
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION.tar.gz &>>$LOG

    infoi "Building pg-gvm..." | tee -a $LOG
    warni "This may take a while..." | tee -a $LOG
    mkdir -p $BUILD_DIR/pg-gvm &>>$LOG
    cmake \
        -S $SOURCE_DIR/pg-gvm-$PG_GVM_VERSION \
        -B $BUILD_DIR/pg-gvm \
        -DCMAKE_BUILD_TYPE=Release &>>$LOG
    cmake --build $BUILD_DIR/pg-gvm -j$(nproc) &>>$LOG

    infoi "Installing pg-gvm..." | tee -a $LOG
    mkdir -p $INSTALL_DIR/pg-gvm &>>$LOG && cd $BUILD_DIR/pg-gvm
    make DESTDIR=$INSTALL_DIR/pg-gvm install &>>$LOG
    cp -rv $INSTALL_DIR/pg-gvm/* / &>>$LOG
}

install_gsa () {
    infoi "Downloading GSA sources..." | tee -a $LOG
    curl_download https://github.com/greenbone/gsa/releases/download/v$GSA_VERSION/gsa-dist-$GSA_VERSION.tar.gz $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz
    curl_download https://github.com/greenbone/gsa/releases/download/v$GSA_VERSION/gsa-dist-$GSA_VERSION.tar.gz.asc $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz.asc

    check_sig $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz.asc $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz

    infoi "Extracting..." | tee -a $LOG
    mkdir -p $SOURCE_DIR/gsa-$GSA_VERSION &>>$LOG
    tar -C $SOURCE_DIR/gsa-$GSA_VERSION -xvzf $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz &>>$LOG

    infoi "Installing GSA..." | tee -a $LOG
    mkdir -p $INSTALL_PREFIX/share/gvm/gsad/web/ &>>$LOG
    cp -rv $SOURCE_DIR/gsa-$GSA_VERSION/* $INSTALL_PREFIX/share/gvm/gsad/web/ &>>$LOG
}

install_gsad () {
    infoi "Downloading gsad sources..." | tee -a $LOG
    curl_download https://github.com/greenbone/gsad/archive/refs/tags/v$GSAD_VERSION.tar.gz $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz
    curl_download https://github.com/greenbone/gsad/releases/download/v$GSAD_VERSION/gsad-$GSAD_VERSION.tar.gz.asc $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz.asc

    check_sig $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz.asc $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz

    infoi "Extracting..." | tee -a $LOG
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz &>>$LOG

    infoi "Building gsad..." | tee -a $LOG
    warni "This may take a while..." | tee -a $LOG
    mkdir -p $BUILD_DIR/gsad &>>$LOG
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
        -DLOGROTATE_DIR=/etc/logrotate.d &>>$LOG
    cmake --build $BUILD_DIR/gsad -j$(nproc) &>>$LOG

    infoi "Installing gsad..." | tee -a $LOG
    mkdir -p $INSTALL_DIR/gsad &>>$LOG && cd $BUILD_DIR/gsad
    make DESTDIR=$INSTALL_DIR/gsad install &>>$LOG
    cp -rv $INSTALL_DIR/gsad/* / &>>$LOG

    if command -v gsad; then
        successi "gsad successfully installed!" | tee -a $LOG
    else
        errori "Failed to install gsad " | tee -a $LOG | tee -a $FIX_LOG
        infoi "View '$LOG' to check for errors, then run the script again with the --install-gsad flag to install gsad again" | tee -a $LOG | tee -a $FIX_LOG
        exit 1
    fi
}

install_openvas_smb () {
    infoi "Downloading openvas-smb sources..." | tee -a $LOG
    curl_download https://github.com/greenbone/openvas-smb/archive/refs/tags/v$OPENVAS_SMB_VERSION.tar.gz $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz
    curl_download https://github.com/greenbone/openvas-smb/releases/download/v$OPENVAS_SMB_VERSION/openvas-smb-v$OPENVAS_SMB_VERSION.tar.gz.asc $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz.asc

    check_sig $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz.asc $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz

    infoi "Extracting..." | tee -a $LOG
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz &>>$LOG

    infoi "Building openvas-smb..." | tee -a $LOG
    warni "This may take a while..." | tee -a $LOG
    mkdir -p $BUILD_DIR/openvas-smb &>>$LOG
    cmake \
        -S $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION \
        -B $BUILD_DIR/openvas-smb \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_BUILD_TYPE=Release &>>$LOG
    cmake --build $BUILD_DIR/openvas-smb -j$(nproc) &>>$LOG

    infoi "Installing openvas-smb..." | tee -a $LOG
    mkdir -p $INSTALL_DIR/openvas-smb &>>$LOG && cd $BUILD_DIR/openvas-smb
    make DESTDIR=$INSTALL_DIR/openvas-smb install &>>$LOG
    cp -rv $INSTALL_DIR/openvas-smb/* / &>>$LOG
}

install_openvas_scanner () {
    infoi "Downloading openvas-scanner..." | tee -a $LOG
    curl_download https://github.com/greenbone/openvas-scanner/archive/refs/tags/v$OPENVAS_SCANNER_VERSION.tar.gz $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz
    curl_download https://github.com/greenbone/openvas-scanner/releases/download/v$OPENVAS_SCANNER_VERSION/openvas-scanner-v$OPENVAS_SCANNER_VERSION.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz.asc

    check_sig $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz

    infoi "Extracting..." | tee -a $LOG
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz &>>$LOG

    infoi "Building openvas-scanner..." | tee -a $LOG
    mkdir -p $BUILD_DIR/openvas-scanner &>>$LOG
    cmake \
        -S $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION \
        -B $BUILD_DIR/openvas-scanner \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_BUILD_TYPE=Release \
        -DSYSCONFDIR=/etc \
        -DLOCALSTATEDIR=/var \
        -DOPENVAS_FEED_LOCK_PATH=/var/lib/openvas/feed-update.lock \
        -DOPENVAS_RUN_DIR=/run/ospd &>>$LOG
    cmake --build $BUILD_DIR/openvas-scanner -j$(nproc) &>>$LOG

    infoi "Installing openvas-scanner..." | tee -a $LOG
    mkdir -p $INSTALL_DIR/openvas-scanner &>>$LOG && cd $BUILD_DIR/openvas-scanner
    make DESTDIR=$INSTALL_DIR/openvas-scanner install &>>$LOG
    cp -rv $INSTALL_DIR/openvas-scanner/* / &>>$LOG

    infoi "Setting openvasd_server config..." | tee -a $LOG
    printf "table_driven_lsc = yes\n" | sudo tee /etc/openvas/openvas.conf &>>$LOG
    printf "openvasd_server = http://127.0.0.1:3000\n" | sudo tee -a /etc/openvas/openvas.conf &>>$LOG
}

install_ospd_openvas () {
    infoi "Downloading ospd-openvas..." | tee -a $LOG
    curl_download https://github.com/greenbone/ospd-openvas/archive/refs/tags/v$OSPD_OPENVAS_VERSION.tar.gz $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz
    curl_download https://github.com/greenbone/ospd-openvas/releases/download/v$OSPD_OPENVAS_VERSION/ospd-openvas-v$OSPD_OPENVAS_VERSION.tar.gz.asc $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz.asc

    check_sig $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz.asc $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz

    infoi "Extracting..." | tee -a $LOG
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz &>>$LOG

    infoi "Installing ospd-openvas..." | tee -a $LOG
    cd $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION
    mkdir -p $INSTALL_DIR/ospd-openvas &>>$LOG
    python3 -m pip install --root=$INSTALL_DIR/ospd-openvas --no-warn-script-location . &>>$LOG
    cp -rv $INSTALL_DIR/ospd-openvas/* / &>>$LOG

    if command -v ospd-openvas &>>$LOG; then
        successi "ospd-openvas successfully installed!" | tee -a $LOG
    else
        errori "Failed to install ospd-openvas" | tee -a $LOG | tee -a $FIX_LOG
        infoi "Check '$LOG' for more details" | tee -a $LOG | tee -a $FIX_LOG
        infoi "Then run the script again with the --install-ospd-openvas flag to install ospd-openvas" | tee -a $LOG | tee -a $FIX_LOG
        exit 1
    fi
}

install_openvasd () {
    infoi "Downloading openvasd..." | tee -a $LOG
    curl_download https://github.com/greenbone/openvas-scanner/archive/refs/tags/v$OPENVAS_DAEMON.tar.gz $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz
    curl_download https://github.com/greenbone/openvas-scanner/releases/download/v$OPENVAS_DAEMON/openvas-scanner-v$OPENVAS_DAEMON.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz.asc

    check_sig $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz

    infoi "Extracting..." | tee -a $LOG
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON.tar.gz &>>$LOG

    infoi "Installing openvasd..." | tee -a $LOG
    mkdir -p $INSTALL_DIR/openvasd/usr/local/bin &>>$LOG
    cd $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON/rust/src/openvasd &>>$LOG
    infoi "Building openvasd..." | tee -a $LOG
    warni "This may take a while..." | tee -a $LOG
    cargo build --release &>>$LOG
    cd $SOURCE_DIR/openvas-scanner-$OPENVAS_DAEMON/rust/src/scannerctl &>>$LOG
    infoi "Building scannerctl..." | tee -a $LOG
    warni "This may take a while..." | tee -a $LOG
    cargo build --release &>>$LOG
    cp -v ../../target/release/openvasd $INSTALL_DIR/openvasd/usr/local/bin/ &>>$LOG
    cp -v ../../target/release/scannerctl $INSTALL_DIR/openvasd/usr/local/bin/ &>>$LOG
    cp -rv $INSTALL_DIR/openvasd/* / &>>$LOG

    if command -v openvasd &>>$LOG; then
        successi "openvasd successfully installed!" | tee -a $LOG
    else
        errori "Failed to install openvasd" | tee -a $LOG | tee -a $FIX_LOG
        infoi "Check '$LOG' for more details" | tee -a $LOG | tee -a $FIX_LOG
        infoi "Then run the script again with the --install-openvasd flag to install openvasd" | tee -a $LOG | tee -a $FIX_LOG
        exit 1
    fi
}

install_feed_sync () {
    infoi "Installing greenbone-feed-sync..." | tee -a $LOG
    mkdir -p $INSTALL_DIR/greenbone-feed-sync &>>$LOG
    python3 -m pip install --root=$INSTALL_DIR/greenbone-feed-sync --no-warn-script-location greenbone-feed-sync &>>$LOG
    cp -rv $INSTALL_DIR/greenbone-feed-sync/* / &>>$LOG

    if command -v greenbone-feed-sync &>>$LOG; then
        successi "greenbone-feed-sync successfully installed!" | tee -a $LOG
    else
        errori "Failed to install greenbone-feed-sync" | tee -a $LOG | tee -a $FIX_LOG
        infoi "Check '$LOG' for more details" | tee -a $LOG | tee -a $FIX_LOG
        infoi "Then run the script again with the --install-greenbone-feed-sync flag to install greenbone-feed-sync" | tee -a $LOG | tee -a $FIX_LOG
        exit 1
    fi
}

install_gvm_tools () {
    infoi "Installing gvm-tools..." | tee -a $LOG
    mkdir -p $INSTALL_DIR/gvm-tools &>>$LOG
    python3 -m pip install --root=$INSTALL_DIR/gvm-tools --no-warn-script-location gvm-tools &>>$LOG
    cp -rv $INSTALL_DIR/gvm-tools/* / &>>$LOG

    if command -v gvm-cli && command -v gvm-script && command -v gvm-pyshell; then
        successi "gvm-tools successfully installed!" | tee -a $LOG
    else
        errori "Failed to install gvm-tools!" | tee -a $LOG | tee -a $FIX_LOG
        infoi "Check '$LOG' for more details" | tee -a $LOG | tee -a $FIX_LOG
        infoi "Then run the script again with the --install-greenbone-feed-sync flag to install greenbone-feed-sync" | tee -a $LOG | tee -a $FIX_LOG
        exit 1
    fi
}

setup_redis_server () {
    infoi "Installing Redis Data Store..." | tee -a $LOG
    apt-get install -qy redis-server &>>$LOG

    infoi "Adding openvas-scanner config..." | tee -a $LOG
    cp $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION/config/redis-openvas.conf /etc/redis/ &>>$LOG
    chown redis:redis /etc/redis/redis-openvas.conf &>>$LOG
    echo "db_address = /run/redis-openvas/redis.sock" | tee -a /etc/openvas/openvas.conf &>>$LOG

    infoi "Redis startup with config..." | tee -a $LOG
    systemctl start redis-server@openvas.service &>>$LOG
    systemctl enable redis-server@openvas.service &>>$LOG

    infoi "Add gvm user to redis group..." | tee -a $LOG
    usermod -aG redis gvm &>>$LOG

    if ! getent group redis | grep -qF "gvm"; then
        errori "Failed to add gvm to redis group!" | tee -a $LOG | tee -a $FIX_LOG
        warni "Run: usermod -aG redis gvm" | tee -a $LOG | tee -a $FIX_LOG
        exit 1
    fi
}

feed_validation () {
    if [[ -f /tmp/GBCommunitySigningKey.asc ]]; then
        warni "Signing key file already exists, checking if it's been imported..." | tee -a $LOG
        if gpg --list-keys --keyid-format SHORT | grep -qF "Greenbone Community Feed integrity key"; then
            warni "Feed validation key has already been imported, checking for proper trust level..." | tee -a $LOG
            if gpg --list-keys --with-colons 8AE4BE429B60A59B311C2E739823FAA60ED1E580 | awk -F: '/^pub:/ {print $9}' | grep -qF "u"; then
                warni "Key already has proper trust level..." | tee -a $LOG
            else
                warni "Key has wrong trust level, setting trust level 6..." | tee -a $LOG
                echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" | sudo gpg --import-ownertrust
                if [[ $? -ne 0 ]]; then
                    errori "Failed to set key trust level." | tee -a $LOG | tee -a $FIX_LOG
                    infoi "Run: 'echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" | sudo gpg --import-ownertrust' then run the script again." | tee -a $LOG | tee -a $FIX_LOG
                    exit 1
                fi
            fi
        else
            infoi "Key has not been imported, importing signing key and setting trust level..." | tee -a $LOG
            gpg --import /tmp/GBCommunitySigningKey.asc &>>$LOG
            echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" | sudo gpg --import-ownertrust
            if [[ $? -ne 0 ]]; then
                errori "Failed to set key trust level." | tee -a $LOG | tee -a $FIX_LOG
                infoi "Run: 'echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" | sudo gpg --import-ownertrust' then run the script again." | tee -a $LOG | tee -a $FIX_LOG
                exit 1
            fi

            export GNUPGHOME=/tmp/openvas-gnupg
            mkdir -p $GNUPGHOME &>>$LOG
            export OPENVAS_GNUPG_HOME=/etc/openvas/gnupg
            mkdir -p $OPENVAS_GNUPG_HOME &>>$LOG
            cp -r /tmp/openvas-gnupg/* $OPENVAS_GNUPG_HOME/ &>>$LOG
            chown -R gvm:gvm $OPENVAS_GNUPG_HOME &>>$LOG
        fi
    else
        infoi "Creating gpg Greenbone feed validation keyring..." | tee -a $LOG
        curl_download https://www.greenbone.net/GBCommunitySigningKey.asc /tmp/GBCommunitySigningKey.asc

        gpg --import /tmp/GBCommunitySigningKey.asc &>>$LOG
        echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" | sudo gpg --import-ownertrust
        if [[ $? -ne 0 ]]; then
            errori "Failed to set key trust level." | tee -a $LOG | tee -a $FIX_LOG
            infoi "Run: 'echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" | sudo gpg --import-ownertrust' then run the script again." | tee -a $LOG | tee -a $FIX_LOG
            exit 1
        fi

        export GNUPGHOME=/tmp/openvas-gnupg
        mkdir -p $GNUPGHOME &>>$LOG
        export OPENVAS_GNUPG_HOME=/etc/openvas/gnupg
        mkdir -p $OPENVAS_GNUPG_HOME &>>$LOG
        cp -r /tmp/openvas-gnupg/* $OPENVAS_GNUPG_HOME/ &>>$LOG
        chown -R gvm:gvm $OPENVAS_GNUPG_HOME &>>$LOG
    fi
}

set_sudo_scan () {
    if [[ -f /etc/sudoers.d/gvm ]]; then
        if ! grep -Fxq '%gvm ALL = NOPASSWD: /usr/local/sbin/openvas' /etc/sudoers.d/gvm; then
            echo "%gvm ALL = NOPASSWD: /usr/local/sbin/openvas" >> /etc/sudoers.d/gvm
            visudo -cf /etc/sudoers.d/gvm &>>$LOG
            if [[ $? -eq 0 ]]; then
                chmod 0440 /etc/sudoers.d/gvm &>>$LOG
                success "Permissions successfully granted" | tee -a $LOG
            else
                error "Couldn't create and modify /etc/sudoers.d/gvm file. Do this manually." | tee -a $LOG | tee -a $FIX_LOG
                infoi "Add '%gvm ALL = NOPASSWD: /usr/local/sbin/openvas' to '/etc/sudoers.d/gvm'" | tee -a $LOG | tee -a $FIX_LOG
                sleep 4
            fi
        else
            info "gvm group already exists and has sufficient permissions" | tee -a $LOG
        fi
    else
        infoi "No gvm sudoers file found, creating one..."
        echo "%gvm ALL = NOPASSWD: /usr/local/sbin/openvas" >> /etc/sudoers.d/gvm
        visudo -cf /etc/sudoers.d/gvm &>>$LOG
        if [[ $? -eq 0 ]]; then
            infoi "Granting permissions..." | tee -a $LOG
            chmod 0440 /etc/sudoers.d/gvm &>>$LOG
            success "Permissions successfully granted" | tee -a $LOG
        else
            error "Couldn't create and modify /etc/sudoers.d/gvm file. Do this manually." | tee -a $LOG | tee -a $FIX_LOG
            infoi "Add '%gvm ALL = NOPASSWD: /usr/local/sbin/openvas' to '/etc/sudoers.d/gvm'" | tee -a $LOG | tee -a $FIX_LOG
            sleep 4
        fi
    fi
}

setup_postgresql () {
    infoi "Starting PostpreSQL..." | tee -a $LOG
    systemctl start postgresql@16-main &>>$LOG
    sleep 2

    infoi "Setting up PostpreSQL..." | tee -a $LOG

    if sudo -u postgres psql -c "\du" | grep -qF "gvm"; then
        warni "gvm user already exists..." | tee -a $LOG
    else
        infoi "Creating psql gvm user..." | tee -a $LOG
        sudo -u postgres createuser -DRS gvm &>>$LOG
        if [[ $? -ne 0 ]]; then
            errori "Failed to automatically create user" | tee -a $LOG | tee -a $FIX_LOG
            infoi "Run: sudo -u postgres createuser -DRS gvm" | tee -a $LOG | tee -a $FIX_LOG
            exit 1
        fi
    fi

    if sudo -u postgres psql -c "\l" | grep -qF "gvmd"; then
        warni "gvmd database already exists..." | tee -a $LOG
    else
        infoi "Creating gvmd database..." | tee -a $LOG
        sudo -u postgres createdb -O gvm gvmd &>>$LOG
        if [[ $? -ne 0 ]]; then
            errori "Failed to create database" | tee -a $LOG | tee -a $FIX_LOG
            infoi "Run: sudo -u postgres createdb -O gvm gvmd" | tee -a $LOG | tee -a $FIX_LOG
            exit 1
        fi
    fi

    if sudo -u postgres psql -c "\du" | grep -qF "dba"; then
        warni "dba role already exists..." | tee -a $LOG
    else
        infoi "Creating administrator role..."
        sudo -u postgres psql gvmd -c "create role dba with superuser noinherit;" &>>$LOG
        if [[ $? -ne 0 ]]; then
            errori "Failed to create dba role..." | tee -a $LOG | tee -a $FIX_LOG
            infoi "Run: sudo -u postgres psql gvmd -c "create role dba with superuser noinherit;"" | tee -a $LOG | tee -a $FIX_LOG
            exit 1
        fi
    fi
    
    if sudo -u postgres psql -c "\drg" | grep -qF -e "gvm" -e "dba"; then
        warni "gvm has already been granted dbs permissions..." | tee -a $LOG
    else
        infoi "Granting gvm dba permissions..." | tee -a $LOG
        sudo -u postgres psql gvmd -c "grant dba to gvm;" &>>$LOG
        if [[ $? -ne 0 ]]; then
            errori "Failed to grant permissions..." | tee -a $LOG | tee -a $FIX_LOG
            infoi "Run: sudo -u postgres psql gvmd -c "grant dba to gvm;"" | tee -a $LOG | tee -a $FIX_LOG
            exit 1
        fi
    fi

    infoi "Restarting PostpreSQL..." | tee -a $LOG
    systemctl restart postgresql@16-main &>>$LOG
}

service_file_ospd_openvas () {
    if [[ -f /etc/systemd/system/ospd-openvas.service ]]; then
        warni "ospd-openvas service file already exists, skipping creation..."
    else
        infoi "Creating systemd service file for ospd-openvas..." | tee -a $LOG
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
        infoi "Installing systemd service file for ospd-openvas..." | tee -a $LOG
        cp -v $BUILD_DIR/ospd-openvas.service /etc/systemd/system/ &>>$LOG
    fi
}

service_file_gvmd () {
    if [[ -f /etc/systemd/system/gvmd.service ]]; then
        warni "gvmd service file already exists, skipping creation..."
    else
        infoi "Creating systemd service file for gvmd..." | tee -a $LOG
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
        infoi "Installing systemd service file for gvmd..." | tee -a $LOG
        cp -v $BUILD_DIR/gvmd.service /etc/systemd/system/ &>>$LOG
    fi
}

service_file_gsad_https () {
    if [[ -f /etc/systemd/system/gsad.service ]]; then
        warni "gsad service file already exists, skipping creation..."
    else
        infoi "Creating HTTPS systemd service file for gsad..." | tee -a $LOG
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
        infoi "Installing https systemd service file for gsad..." | tee -a $LOG
        cp -v $BUILD_DIR/gsad.service /etc/systemd/system/ &>>$LOG
    fi
}

service_file_gsad_http () {
    if [[ -f /etc/systemd/system/gsad.service ]]; then
        warni "gsad service file already exists, skipping creation..."
    else
        infoi "Creating HTTPS systemd service file for gsad..." | tee -a $LOG
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
        infoi "Installing https systemd service file for gsad..." | tee -a $LOG
        cp -v $BUILD_DIR/gsad.service /etc/systemd/system/ &>>$LOG
    fi
}

service_file_openvasd () {
    if [[ -f /etc/systemd/system/openvasd.service ]]; then
        warni "openvasd service file already exists, skipping creation..."
    else
        infoi "Creating systemd service file for openvasd..." | tee -a $LOG
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
        infoi "Installing systemd service file for openvasd..." | tee -a $LOG
        cp -v $BUILD_DIR/openvasd.service /etc/systemd/system/ &>>$LOG
    fi
}

feed_sync () {
    infoi "Performing feed sync..." | tee -a $LOG
    warni "This might take a while..." | tee -a $LOG
    /usr/local/bin/greenbone-feed-sync
}

create_feed_sync_cron () {
    if [[ -f /tmp/feed_sync_cron ]]; then
        rm /tmp/feed_sync_cron &>>$LOG
    fi

    infoi "Adding feed-sync cron job..." | tee -a $LOG
    crontab -l >/tmp/feed_sync_cron

    if grep -qF "/usr/local/bin/greenbone-feed-sync --type ALL" /tmp/feed_sync_cron; then
        warni "Feed sync cronjob already present!" | tee -a $LOG
    else
        # Append a "run feed-sync every quarter at 1am" cron job
        echo '0 1 1 3,6,9,12 * /usr/local/bin/greenbone-feed-sync --type ALL >>/var/log/gvm/feed-sync.log 2>&1' >>/tmp/feed_sync_cron
        crontab /tmp/feed_sync_cron &>>$LOG

        if grep -qF "/usr/local/bin/greenbone-feed-sync --type ALL" /tmp/feed_sync_cron; then
            successi "Cronjob successfully added!" | tee -a $LOG
        else
            errori "Feedsync cronjob was not added!" | tee -a $LOG | tee -a $FIX_LOG
            infoi "Append this to the end of your cronjob file: 0 1 1 3,6,9,12 * /usr/local/bin/greenbone-feed-sync --type ALL >>/var/log/gvm/feed-sync.log 2>&1" | tee -a $LOG | tee -a $FIX_LOG
            sleep 3
        fi
    fi
}

create_gvm_user () {
    infoi "Creating user and group..." | tee -a $LOG
    if id -u "gvm" &>>$LOG; then
        warni "gvm user already exists!" | tee -a $LOG
    else
        useradd -rMUG sudo -s /usr/sbin/nologin gvm &>>$LOG
        if [ $? -ne 0 ]; then
            errori "Unable to create gvm user!" | tee -a $LOG | tee -a $FIX_LOG
            infoi "Run: useradd -rMUG sudo -s /usr/sbin/nologin gvm" | tee -a $LOG | tee -a $FIX_LOG
            infoi "then run script again." | tee -a $LOG | tee -a $FIX_LOG
            exit 1
        fi
    fi

    if id -nG "$USER" | grep -qw "gvm"; then
        warni "$USER already belongs to group gvm" | tee -a $LOG
    else
        usermod -aG gvm $USER &>>$LOG
    fi
}

# ————— Command flags checker ——————————————————————————————————
if [[ $1 == -* ]]; then
    case "$1" in
    	--http)
            infoi "HTTP Install selected..."
            HTTP="http"
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        --uninstall)
            warn "Uninstall flag wip..."
            # uninstall_greenbone
            # if [ $? -eq 0 ]; then
            #     echo
            #     success "Greenbone successfully uninstalled."
            #     echo
            #     exit 0
            # else
            #     echo
            #     success "Greenbone was not uninstalled completely. Check '/tmp/gvmUninstall.log' for more information."
            #     echo
            #     exit 1
            # fi
            exit 0
            ;;
        --start)
            start_services
            if [ "$ALL_RUNNING" = true ]; then
                exit 0
            else
                exit 1
            fi
            ;;
        --stop)
            stop_services
            if [[ $? -eq 0 ]]; then
                echo
                success "All Greenbone processes stopped."
                echo
                exit 0
            else
                echo
                error "Failed to stop all processes."
                echo
                exit 1
            fi
            ;;
        --restart)
            restart_services
            if [[ $? -eq 0 ]]; then
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
            ;;
        --status)
            services_status
            exit 0
            ;;
        --check-setup)
            check_setup
            if [[ "$CHECK_PASSED" = true ]]; then
                success "Your GVM install is correct and up to date!"
                echo
                SERVICES=("ospd-openvas" "gvmd" "gsad" "openvasd")
                infoi "Starting Greenbone processes..."
                for SERVICE_NAME in "${SERVICES[@]}"; do
                    if systemctl is-active --quiet "$SERVICE_NAME"; then
                        infoic "$SERVICE_NAME already running."
                    else
                        infoi "$SERVICE_NAME not running, starting $SERVICE_NAME"
                        systemctl start $SERVICE_NAME
                    fi
                done
                unset SERVICES
                exit 0
            else
                echo
                error "GVM is not installed correctly, check console for errors"
                exit 1
            fi
            ;;
        --no-dependencies)
            infoi "Skipping dependencies..."
            SKIP_DEPENDENCIES=true
            ;;
        --install-dependencies)
            install_dependencies
            ;;
        --install-gvm-libs)
            install_gvm_libs
            ;;
        --install-gvmd)
            install_gvmd
            ;;
        --install-pg-gvm)
            install_pg_gvm
            ;;
        --install-gsa)
            install_gsa
            ;;
        --install-gsad)
            install_gsad
            ;;
        --install-openvas-smb)
            install_openvas_smb
            ;;
        --install-openvas-scanner)
            install_openvas_scanner
            ;;
        --install-ospd-openvas)
            install_ospd_openvas
            ;;
        --install-openvasd)
            install_openvasd
            ;;
        --install-feed-sync)
            install_feed_sync
            ;;
        --install-gvm-tools)
            install_gvm_tools
            ;;
        --install-redis-server)
            setup_redis_server
            ;;
        --feed-validation)
            feed_validation
            ;;
        --set-scan-permissions)
            set_sudo_scan
            ;;
        --install-postgresql)
            setup_postgresql
            ;;
        --servicefile-ospd-openvas)
            service_file_ospd_openvas
            ;;
        --servicefile-gvmd)
            service_file_gvmd
            ;;
        --servicefile-gsad)
            service_file_gsad_https
            ;;
        --servicefile-openvasd)
            service_file_openvasd
            ;;
        --create-cronjob)
            create_feed_sync_cron
            ;;
        --create-gvm-user)
            create_gvm_user
            ;;
        *)
            warni "Invalid argument(s). Use --help to view valid arguments."
            exit 1
            ;;
    esac
fi


# ————— Check sudo —————————————————————————————————————————————
if [[ $UID -ne 0 ]]; then
    warni "Run script with sudo" | tee -a $LOG
	exit 1
fi

echo "Installer version: $INSTALLER_VERSION" | tee -a $LOG
echo "Last updated $((($(date +%s)-$(date -d "$LAST_UPDATED" +%s))/(86400))) days ago ($LAST_UPDATED)" | tee -a $LOG

# ————— Check for latest ———————————————————————————————————————
LATEST_TAG=$(curl -sSL "https://api.github.com/repos/ArcTrooper210/GVM-Installer-Script/releases/latest" | jq -r .tag_name)
echo "Latest release version: $LATEST_TAG" >>$LOG
if [ -z "$LATEST_TAG" ]; then
    error "Could not determine latest release (API error or invalid tag)." | tee -a $LOG
else
    VER_LATEST=${LATEST_TAG:1}
    VER_INST=${INSTALLER_VERSION:1}
    if dpkg --compare-versions "$VER_INST" lt "$VER_LATEST"; then
        echo "A new version is available: $LATEST_TAG (you have $INSTALLER_VERSION)." | tee -a $LOG
        echo "Release notes: https://github.com/ArcTrooper210/GVM-Installer-Script/releases/latest" | tee -a $LOG
    elif dpkg --compare-versions "$VER_INST" gt "$VER_LATEST"; then
        echo -e "\e[2m\e[1m\e[31mHow do you have a version newer than release...\e[0m"
    else
        successi "You have the latest version" | tee -a $LOG
    fi
fi
unset LATEST_TAG VER_LATEST VER_INST


info "Use with --help|-h for more options." | tee -a $LOG
echo

while true; do
    read -p "Proceed with script? (y/n)" yn
    case $yn in
        [yY] ) echo "Continuing...";
            break;;
        [nN] ) echo "Exiting...";
            exit 1;;
        * ) warni "Invalid response";;
    esac
done


# ————— Checking for previous GVM install ——————————————————————
infoi "Checking for previous GVM install..." | tee -a $LOG
if prev_install_check; then
    warni "Previous GVM install found..." | tee -a $LOG
    infoi "Preparing for update..." | tee -a $LOG
    prepare_update
else
    infoi "No previous GVM install found..." | tee -a $LOG
fi


# ————— Check for running GVM processes ————————————————————————
SERVICES=("ospd-openvas" "gvmd" "gsad" "openvasd")
ALL_STOPPED=true
infoi "Checking for running Greenbone services..." | tee -a $LOG

for SERVICE_NAME in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$SERVICE_NAME" &>>$LOG; then
        systemctl stop $SERVICE_NAME &>>$LOG
    fi
done

sleep 3

for SERVICE_NAME in "${SERVICES[@]}"; do
    if systemctl is-active --quiet $SERVICE_NAME &>>$LOG; then
        errori "Service '$SERVICE_NAME' failed to stop." | tee -a $LOG
        infoi "Run 'sudo systemctl stop $SERVICE_NAME'" | tee -a $LOG
        ALL_STOPPED=false
    fi
done

if [ "$ALL_STOPPED" != true ]; then
    error "Failed to stop all services. Manually stop above Greenbone services before installing." | tee -a $LOG
    exit 1 &>>$LOG
fi
unset SERVICES ALL_STOPPED


# ————— Ask user to set admin username and password ————————————
infoi "Setting up GVM administrator credentials..." | tee -a $LOG
admin_setup


# ————— If https, then ask for domain name —————————————————————
if [ $HTTP = "https" ]; then
    infoi "Set custom domain name for HTTPS GSAD." | tee -a $LOG
    set_domain_name
else
    info "HTTP install selected, skipping domain name..." | tee -a $LOG
fi


# ————————————————— Start GVM install ——————————————————————————
# ————— Create user and group ——————————————————————————————————
create_gvm_user


# ──── Setting Environment Variables and PATH ——————————————————
infoi "Setting Environment Variables and Path..." | tee -a $LOG
export INSTALL_PREFIX=/usr/local
export PATH=$PATH:$INSTALL_PREFIX/sbin


# ──── Setting Source, Build and Install Directory —————————————
infoi "Setting Source, Build, and Install Directories..." | tee -a $LOG
export SOURCE_DIR=$HOME/source
mkdir -p $SOURCE_DIR &>>$LOG
export BUILD_DIR=$HOME/build
mkdir -p $BUILD_DIR &>>$LOG
export INSTALL_DIR=$HOME/install
mkdir -p $INSTALL_DIR &>>$LOG


# ──── Install dependencies ————————————————————————————————————
if [[ $SKIP_DEPENDENCIES = false ]]; then
    install_dependencies
elif [[ $SKIP_DEPENDENCIES = true ]]; then
    warni "Skipping installation of dependencies..."  | tee -a $LOG
fi


# ————— Importing the Greenbone Signing Key ————————————————————
import_gpg_key


# ————— Download gvm-libs ——————————————————————————————————————
install_gvm_libs


# ————— Download gvmd ——————————————————————————————————————————
install_gvmd


# ————— Download pg-gvm ————————————————————————————————————————
install_pg_gvm


# ————— Download gsa ———————————————————————————————————————————
install_gsa


# ————— Download gsad ——————————————————————————————————————————
install_gsad


# ————— Download openvas-smb ———————————————————————————————————
install_openvas_smb


# ————— Download openvas-scanner ———————————————————————————————
install_openvas_scanner


# ————— Download ospd-openvas ——————————————————————————————————
install_ospd_openvas


# ————— Download openvasd ——————————————————————————————————————
install_openvasd

# ————— Download greenbone-feed-sync ———————————————————————————
install_feed_sync

# ————— Download gvm-tools —————————————————————————————————————
install_gvm_tools


# ————— Setting up Redis Data Store ————————————————————————————
setup_redis_server


# ————— Adjusting perms ————————————————————————————————————————
infoi "Adjusting Permissions..." | tee -a $LOG
mkdir -p /var/lib/notus /run/gvmd &>>$LOG
chown -R gvm:gvm \
    /var/lib/gvm \
    /var/lib/openvas \
    /var/lib/notus \
    /var/log/gvm \
    /run/gvmd &>>$LOG
chmod -R g+srw \
    /var/lib/gvm \
    /var/lib/openvas \
    /var/log/gvm &>>$LOG
chown gvm:gvm /usr/local/sbin/gvmd &>>$LOG
chmod 6750 /usr/local/sbin/gvmd &>>$LOG


# ————— Feed validation ————————————————————————————————————————
feed_validation


# ————— Setting up sudo for scanning ———————————————————————————
set_sudo_scan


# ————— Setting up PostgreSQL ——————————————————————————————————
setup_postgresql


# ————— Setting up an Admin User ———————————————————————————————
infoi "Creating admin user..." | tee -a $LOG
OUT="$(/usr/local/sbin/gvmd --create-user="$ADUSER" --password="$ADPW")"
if [[ "$OUT" = "User created." ]]; then
    successi "Successfully created admin user" | tee -a $LOG
elif [[ "$OUT" = "User exists already." ]]; then
    warni "$ADUSER already exists" | tee -a $LOG
else
    error "Failed to create admin user. Check /var/log/gvm/gvmd.log" | tee -a $FIX_LOG
    warni "Run: sudo /usr/local/sbin/gvmd --create-user="adminUsername" --password="adminPassword"" | tee -a $FIX_LOG
    sleep 4
fi
unset ADPW


# ————— Setting feed owner —————————————————————————————————————
infoi "Setting feed import owner..." | tee -a $LOG
export FEED_OWNER_UID=$(/usr/local/sbin/gvmd --get-users --verbose | grep "$ADUSER" | awk '{print $2}') &>>$LOG
/usr/local/sbin/gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value $FEED_OWNER_UID &>>$LOG


# ————— Setting up service files for systemd ————————————————————————
service_file_ospd_openvas

service_file_gvmd

if [ $HTTP = "https" ]; then
    service_file_gsad_https
else
    service_file_gsad_http
fi

service_file_openvasd

infoi "Activating and starting new service files..." | tee -a $LOG
systemctl daemon-reload &>>$LOG


# ————— Install cert for https ———————————————————————————————
if [ $HTTP = "https" ]; then
    infoi "Installing SSL Certs..." | tee -a $LOG
    runuser -u gvm -- gvm-manage-certs -aqf &>>$LOG

    infoi "Adding domain name to hosts file..." | tee -a $LOG
    if ! cp /etc/hosts /tmp/hosts; then
        errori "Error while copying. File doesn't exist or not enough permissions." | tee -a $LOG
    else
        echo "127.0.0.1 ${GVM_CERTIFICATE_SAN_DNS}" >>/tmp/hosts
        cp /tmp/hosts /etc/hosts &>>$LOG
    fi

    HOST_CHECK=$(tail -n1 /etc/hosts)
    if [[ "$HOST_CHECK" != "127.0.0.1 ${GVM_CERTIFICATE_SAN_DNS}" ]]; then
        error "Failed to add host to hosts file..." | tee -a $LOG | tee -a $FIX_LOG
        infoi "Manually add domain name to /etc/hosts file. '127.0.0.1 ${GVM_CERTIFICATE_SAN_DNS}'" | tee -a $LOG | tee -a $FIX_LOG
    fi
fi
unset HOST_CHECK

# ————— Feed sync ——————————————————————————————————————————————
feed_sync


# ————— Start services —————————————————————————————————————————
infoi "Setting services to run on system startup..." | tee -a $LOG
systemctl enable ospd-openvas gvmd openvasd gsad &>>$LOG


# Starting all services
start_services


# ————— Create feed sync cron job ——————————————————————————————
create_feed_sync_cron


# ————— Remove tmp files ———————————————————————————————————————
infoi "Removing temporary files..." | tee -a $LOG
infoi "If it says folder not found, ignore and continue..." | tee -a $LOG
rm /tmp/GBCommunitySigningKey.asc
# rm -rf /tmp/openvas-gnupg
rm /tmp/hosts &>>$LOG
rm /tmp/feed_sync_cron &>>$LOG
echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:2:" | gpg --import-ownertrust &>>$LOG


# ————— Complete message ———————————————————————————————————————
check_setup

if [ $CHECK_PASSED = true ]; then
    echo
    successi "Greenbone Community Edition install is completed!" | tee -a $LOG
    echo
    infoi "You can change the password with:" | tee -a $LOG
    infoi "sudo gvmd --user='yourCurrentUsername' --new-password='yourNewPassword'" | tee -a $LOG
    echo
    infoi "You can change the username with:" | tee -a $LOG
    infoi "sudo gvmd --create-user='yourNewUsername' --password='yourPassword' --role=Admin" | tee -a $LOG
    infoi "sudo gvmd --delete-user='yourOldUsername' --inheritor='yourNewUsername'" | tee -a $LOG
    echo
    echo
    sleep 5

    # ————— Start gsa interface ————————————————————————————————
    infoi "Starting GSA interface..." | tee -a $LOG
    if [ $HTTP = "https" ]; then
        infoi "If your browser doesn't open. Go to: https://${GVM_CERTIFICATE_SAN_DNS}:9392" | tee -a $LOG
        xdg-open "https://${GVM_CERTIFICATE_SAN_DNS}:9392" &>>$LOG
    else
        infoi "If your browser doesn't open." | echo "Go to: http://127.0.0.1:9392" | tee -a $LOG
        xdg-open "http://127.0.0.1:9392" &>>$LOG
    fi
    exit 0
else
    echo
    errori "Greenbone Community Edition install is incomplete! Check /tmp/gvmInstall.log and /tmp/gvmFixesNeeded.log for errors!" | tee -a $LOG
    echo
    exit 1
fi
