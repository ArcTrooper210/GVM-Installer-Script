# GVM Installer Script
Bash installer for [Greenbone Community Edition](https://greenbone.github.io/docs/latest/22.4/source-build/index.html).

## Supported OS
Ubuntu 24.XX LTS

## Features
- HTTPS and HTTP installer options for GSAD (default: https)
- Ability to choose custom GSAD domain name
- Ability to Start/Stop/Restart/Check status of all GVM services
- Built in uninstaller (wip)
- Checks for proper install
- Minimal user interaction, simply run the script enter a few prompts and let it install

## Usage
`sudo bash gvmInstaller.sh --help`
```
--help | -h     Show this help page
--http          Install GVM with http setup
--start         Start all GVM Services
--stop          Stop all GVM Services
--status        Prints status of all GVM Services
--restart       Restarts all GVM Services
--uninstall     Uninstall GVM (WiP)
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
