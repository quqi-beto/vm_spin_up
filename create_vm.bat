
@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem === Locate VBoxManage ===
set "VBOXMANAGE=C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
if not exist "%VBOXMANAGE%" (
  rem Fallback: try PATH
  for %%I in (VBoxManage.exe) do set "VBOXMANAGE=%%~f$PATH:I"
)
if not exist "%VBOXMANAGE%" (
  echo [ERROR] VBoxManage not found. Please install VirtualBox or add it to PATH.
  exit /b 1
)

rem === Read config ===
if not exist "vm.conf" (
  echo [ERROR] vm.conf not found next to this script.
  exit /b 1
)

for /F "usebackq tokens=1,* delims==" %%A in ("vm.conf") do (
  set "K=%%~A"
  set "V=%%~B"
  if defined K if not "!K:~0,1!"=="#" (
    if defined V set "!K!=!V!"
  )
)

rem === Normalize & defaults ===

if not defined GRAPHICS_CONTROLLER set "GRAPHICS_CONTROLLER=VMSVGA"
if not defined EFI set "EFI=off"
if not defined CPUS set "CPUS=2"
if not defined MEM_MB set "MEM_MB=2048"
if not defined VRAM_MB set "VRAM_MB=16"
if not defined DISK_MB set "DISK_MB=20480"
if not defined NIC1 set "NIC1=nat"
if not defined START_HEADLESS set "START_HEADLESS=true"
if not defined INSTALL_ADDITIONS set "INSTALL_ADDITIONS=false"


  echo %DOWNLOAD_ISO%

if /I "%DOWNLOAD_ISO%"=="true" (
  if not defined ISO_URL (
    echo [ERROR] DOWNLOAD_ISO=true but ISO_URL not set.
    exit /b 1
  )
  if not defined ISO_PATH set "ISO_PATH=.\isos\%VM_NAME%.iso"

  if not exist ".\isos" mkdir ".\isos"
  echo [INFO] Downloading ISO to "%ISO_PATH%"
  powershell -NoProfile -ExecutionPolicy Bypass ^
    -Command "Invoke-WebRequest -Uri '%ISO_URL%' -OutFile '%ISO_PATH%' -UseBasicParsing"
  if errorlevel 1 (
    echo [ERROR] ISO download failed.
    exit /b 1
  )
) else (
    echo [ERROR] DOWNLOAD_ISO is not set.
  if not defined ISO_PATH (
    echo [ERROR] ISO_PATH is not set and DOWNLOAD_ISO=false.
    exit /b 1
  )
)

if not exist "%ISO_PATH%" (
  echo [ERROR] ISO file not found: "%ISO_PATH%"
  exit /b 1
)

rem === Create VM ===
echo [INFO] Creating VM "%VM_NAME%" (type=%OS_TYPE%) in "%VM_BASEFOLDER%"
"%VBOXMANAGE%" createvm --name "%VM_NAME%" --ostype "%OS_TYPE%" --basefolder "%VM_BASEFOLDER%" --register

rem === Modify VM basics ===
echo [INFO] Configuring CPU/RAM/Graphics/Firmware/Paravirt
"%VBOXMANAGE%" modifyvm "%VM_NAME%" ^
  --cpus %CPUS% ^
  --memory %MEM_MB% ^
  --vram %VRAM_MB% ^
  --graphicscontroller %GRAPHICS_CONTROLLER% ^
  --firmware %EFI% ^
  --paravirtprovider kvm

rem === Networking ===
if /I "%NIC1%"=="bridged" (
  if not defined BRIDGE_ADAPTER (
    echo [ERROR] NIC1=bridged but BRIDGE_ADAPTER not set.
    exit /b 1
  )
  "%VBOXMANAGE%" modifyvm "%VM_NAME%" --nic1 bridged --bridgeadapter1 "%BRIDGE_ADAPTER%"
) else (
  "%VBOXMANAGE%" modifyvm "%VM_NAME%" --nic1 nat
  rem Optional NAT port forwards
  if defined NAT_SSH_PORT "%VBOXMANAGE%" modifyvm "%VM_NAME%" --natpf1 "ssh,tcp,127.0.0.1,%NAT_SSH_PORT%,,22"
  if defined NAT_HTTP_PORT "%VBOXMANAGE%" modifyvm "%VM_NAME%" --natpf1 "http,tcp,127.0.0.1,%NAT_HTTP_PORT%,,80"
)

rem === Disk & controllers ===
set "VDI=%VM_BASEFOLDER%\%VM_NAME%\%VM_NAME%.vdi"
echo [INFO] Creating disk "%VDI%" (%DISK_MB% MB)
"%VBOXMANAGE%" createmedium disk --filename "%VDI%" --size %DISK_MB% --format VDI --variant Standard

echo [INFO] Adding SATA controller and attaching disk
"%VBOXMANAGE%" storagectl "%VM_NAME%" --name "SATA" --add sata --controller IntelAhci
"%VBOXMANAGE%" storageattach "%VM_NAME%" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "%VDI%"

echo [INFO] Attaching ISO as optical drive
"%VBOXMANAGE%" storageattach "%VM_NAME%" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "%ISO_PATH%"

rem === Unattended install ===
set "ADD_FLAG="
if /I "%INSTALL_ADDITIONS%"=="true" set "ADD_FLAG=--install-additions"

set "START_FLAG="
if /I "%START_HEADLESS%"=="true" (set "START_FLAG=--start-vm=headless") else (set "START_FLAG=--start-vm=gui")

set "POST_FLAG="
if defined LINUX_POST_INSTALL set "POST_FLAG=--post-install-command=""%LINUX_POST_INSTALL%"""

echo [INFO] Starting unattended install...
"%VBOXMANAGE%" unattended install "%VM_NAME%" --iso="%ISO_PATH%" ^
  --user="%USERNAME%" ^
  --password="%PASSWORD%" ^
  --full-user-name="%FULL_NAME%" ^
  --hostname="%HOSTNAME%" ^
  --time-zone="%TIMEZONE%" ^
  --locale="%LOCALE%" ^
  --package-selection-adjustment=minimal ^
  %ADD_FLAG% ^
  %POST_FLAG% ^
  %START_FLAG%

echo [INFO] VM "%VM_NAME%" is installing unattended. This may take several minutes.
echo [INFO] When the VM completes installation and reboots, you can SSH to localhost:%NAT_SSH_PORT% (if NAT + ssh PF was enabled).
endlocal
