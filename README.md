# GVM Installer Script
Bash installer for [Greenbone Community Edition](https://greenbone.github.io/docs/latest/22.4/source-build/index.html).

## Supported OS
Ubuntu 24.XX LTS

## Features
- HTTPS and HTTP installer options for GSAD (default: https)
- Ability to choose custom GSAD domain name
- Ability to Start/Stop/Restart/Check status of all GVM services
- Minimal user interaction, simply run the script enter a few prompts and let it install
- Checks for proper install

## Usage
`sudo bash gvmInstaller.sh --help`
```
--help|-h             Shows this help page"
--start               Starts all GVM Services"
--stop                Stops all GVM Services"
--restart             Restarts all GVM Services"
--status              Prints status of all GVM Services"
--no-dependencies     Runs script without installing dependencies"
--check-setup         Checks for proper GVM installation"

These arguments will install specific modules:"
--install-gvm-libs            Is a dependency of openvas-scanner, gvmd, gsad and pg-gvm"
--install-gvmd                gvmd is the main service of Greenbone"
--install-pg-gvm              pg-gvm is a PostgreSQL extension used by gvmd"
--install-gsa                 gsa is a JavaScript web application"
--install-gsad                gsad serves static content like images and provides an API for gsa"
--install-openvas-smb         openvas-smb is a helper module for openvas-scanner"
--install-openvas-scanner     openvas-scanner is a scan engine that executes Vulnerability Tests (VTs)"
--install-ospd-openvas        ospd-openvas allows gvmd to remotely control openvas-scanner"
--install-openvasd            OpenVASD is used for detecting vulnerable products"
--install-feed-sync           greenbone-feed-sync is a Python script to download feed data from the Greenbone Community Feed"
--install-gvm-tools           gvm-tools are a collection of tools that help with controlling Greenbone installations"
--install-redis-server        Redis key/value storage is used by the scanner for handling the VT info and scan results"
--install-postgresql          PostgreSQL is used as a central storage for user and scan information for gvmd"
--set-scan-permissions        Gives vulnurability scanner proper sudo permissions"
--servicefile-ospd-openvas    Creates ospd-openvas service file"
--servicefile-gvmd            Creates gvmd service file"
--servicefile-gsad            Creates gsad service file"
--servicefile-openvasd        Creates openvasd service file"
--feed-validation             Installs Greenbone GnuPG keychain to validate feed content"
--create-cronjob              Creates a cronjob to run greenbone-feed-sync every quarter"
--create-gvm-user             Creates gvm user and group"
--install-dependencies        Installs Greenbone apt dependencies"
```

## Troubleshooting
> [!WARNING]
> Sometimes GitHub will convert the script from LF to CRLF, which will break the script. You will need to manually convert back to LF line endings if you get errors similar to this: </br>
> `'\r': command not found` or `syntax error near unexpected token $'{\r'`


## Credits
Greenbone Community Forums</br>
Debian Team </br>
Libellux 

## Disclaimer
This script is provided "as is" without any warranty of any kind, express or implied. Use at your own risk. I do not guarantee that this script will function as intended, nor do I accept any responsibility for any data loss, system damage, or other issues that may arise from its use. It is strongly recommended to review and test the script in a controlled envinroment before running it.
