# VM SpinUp
Fully automate VM creation and OS installation (unattended), with all specs read from a simple key=value config file via command line.

## High-level

1. **Use `VBoxManage`** (VirtualBox CLI) to create and configure the VM, disk, controllers, and networking.
2. **Kick off an unattended Linux install** from an ISO, passing username, password, locale, timezone, hostname, and whether to install Guest Additions—all non-interactively.
3. **Make everything configurable** via a simple `key=value` config file that the batch script reads (`FOR /F` parsing).
4. **Optionally download the ISO** automatically using PowerShell (or point to an existing local path).
> VirtualBox’s “unattended install” is designed specifically for this scenario and supports options like --user, --password, --hostname, --locale, --time-zone, --install-additions, --post-install-command, and more.
---

## Prerequisites

- **VirtualBox installed on Windows 11** (includes `VBoxManage.exe`). Verify with:
  ```cmd
  "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" -v
  ```
- **An ISO path or URL** to your chosen Linux distribution.
- **Enough host resources** (RAM/CPU/disk) for the guest.

---

## Step-by-step setup

### 1) Configure the config file (`vm.conf`)

Example:
```properties
VM_NAME=ubuntu-server-lab
OS_TYPE=Ubuntu_64
VM_BASEFOLDER=%USERPROFILE%\VirtualBox VMs
CPUS=2
MEM_MB=4096
VRAM_MB=16
DISK_MB=20480
EFI=on
GRAPHICS_CONTROLLER=VMSVGA
NIC1=nat
BRIDGE_ADAPTER=
NAT_SSH_PORT=2222
NAT_HTTP_PORT=8080
DOWNLOAD_ISO=true
ISO_URL=https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso
ISO_PATH=.\isos\ubuntu-24.04-live-server-amd64.iso
USERNAME=oliver
PASSWORD=changeme!
FULL_NAME=Oliver Roque
HOSTNAME=ubuntu-lab
TIMEZONE=Asia/Manila
LOCALE=en_US
INSTALL_ADDITIONS=true
START_HEADLESS=true
LINUX_POST_INSTALL=usermod -aG sudo oliver
```

> Run `VBoxManage list ostypes` to see valid OS types.
> Then copy the identifier (e.g., Ubuntu_64, Debian_64, Fedora_64).
> The unattended install GUI caveat (VirtualBox 7) is that some Linux installs may not add the created user to sudo by default; the --post-install-command in the script handles that.

---

### 2) See the batch script (`create_vm.bat`)

Key actions:
- Locate `VBoxManage`
- Parse `vm.conf`
- Create VM and configure resources
- Attach storage and ISO
- Run `VBoxManage unattended install` with user, password, locale, timezone, hostname, and optional Guest Additions

---

## Running it

1. Save `vm.conf` and `create_vm.bat` in the same folder.
2. Open **Command Prompt** (Run as Administrator recommended).
3. Execute:
   ```cmd
   create_vm.bat
   ```
4. VM will be created and OS installed unattended. Monitor progress in VirtualBox Manager or via:
   ```cmd
   VBoxManage showvminfo "VM_NAME" --details
   ```
