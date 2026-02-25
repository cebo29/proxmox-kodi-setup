# Proxmox Helper

Set of scripts to help in deployment of containers into Proxmox.

based on great work of https://github.com/tteck/Proxmox

# Kodi Media Manager LXC

## To create a new Proxmox Kodi Media Manager, run the following in the Proxmox Shell.

```yaml
bash -c "$(wget -qLO - https://raw.githubusercontent.com/kjames2001/proxmoxHelper/dev/ct/kodi-v1.sh)"
```
Kodi should be attached to TTY7 console

If kodi is not installed automatically, run in lxc console:

```yaml
bash -c "$(wget -qLO - https://raw.githubusercontent.com/kjames2001/proxmoxHelper/dev/setup/kodi-install.sh)"
```

## To Update Kodi Media Manager:

Run in the LXC console
```yaml
apt update && apt upgrade -y
```
## Issue with X on Ubuntu 20.04 and Unprivileged

If you really need to use Ubuntu below 22.04 there is an issue with access rights that prevents Xorg from starting on TTY7 on an Unprivileged container. Workaround exists but a change on the host machine is required so please accept the risk beforehand. Or just use a privileged container instead. In the Proxmox Shell:
```yaml
chmod 660 /dev/tty7
```

## XFCE Desktop Environment
If you would like a desktop env, select it when running the script.

You will be prompted to set a password for the user "kodi" and asked if you want to install Steam, Firefox, Brave, Chrome, LibreOffice, VLC, GIMP. If you choose not to install, the script will create desktop launchers for all skipped applications. You will also be prompted to select audio device and test if they work.

First Shutdown maybe slow, but its only a one time thing.

Shutdown of the lxc is available in kodi or through the desktop shortcut, so that you can access proxmox host shell when needed.

## Bluetooth Setup
If you want to add bluetooth device in Proxmox host, run the following script in proxmox shell:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/kjames2001/proxmoxHelper/dev/ct/bluetooth-setup.sh)"
```
