# GVM Installer Script
Bash installer for [Greenbone Community Edition](https://greenbone.github.io/docs/latest/22.4/source-build/index.html).

## Supported OS
Ubuntu 22.XX LTS

## Features
- HTTP and HTTPS installer for GSAD (default: http)
- Ability to Start/Stop/Restart/Check status of all GVM services
- Built in uninstaller

## Usage
Run with `sudo bash gvmInstaller.sh --validFlag`
```
--help | -h     Show this help page
--https         Install GVM with https setup
--start         Start all GVM Services
--stop          Stop all GVM Services
--status        Prints status of all GVM Services
--restart       Restarts all GVM Services
--uninstall     Uninstall GVM
```

## Credits
Greenbone Community Forums</br>
Debian Team </br>
Libellux 

## Disclaimer
This script is provided "as is" without any warranty of any kind, express or implied. Use at your own risk. I do not guarantee that this script will function as intended, nor do I accept any responsibility for any data loss, system damage, or other issues that may arise from its use. It is strongly recommended to review and test the script in a controlled envinroment before running it.
