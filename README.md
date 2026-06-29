# VMware Autostart

Script de PowerShell para arrancar automáticamente una máquina 
virtual VMware Workstation y conectarse a ella por SSH mediante WSL.

## Autor

**Luis Rodrigo Guillén Calderón**
GitHub: [@lrguillenc](https://github.com/lrguillenc)

## Características

- Verifica si VMware ya está abierto antes de iniciarlo
- Verifica si la VM ya está encendida antes de hacer power on
- Sistema de reintentos automáticos si el arranque falla
- Cuenta atrás visual mientras arranca el sistema operativo
- Abre WSL automáticamente con la conexión SSH lista
- Configuración separada del código para mayor seguridad

## Requisitos

- Windows 10/11
- VMware Workstation Pro
- WSL (Windows Subsystem for Linux)
- Windows Terminal (recomendado)

## Instalación

### 1 — Clonar el repositorio

```powershell
git clone https://github.com/lrguillenc/vmware-autostart.git
cd vmware-autostart
```

### 2 — Crear tu configuración personal

```powershell
Copy-Item config.example.ps1 config.ps1
```

Abre `config.ps1` y rellena con tus datos:

```powershell
$vmrunPath = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
$vmxPath   = "C:\Users\TU_USUARIO\Documents\Virtual Machines\TU_VM\TU_VM.vmx"
$sshUser   = "tu_usuario"
$sshHost   = "10.X.X.X"
$bootWait  = 45
```

### 3 — Ejecutar el script

```powershell
powershell -ExecutionPolicy Bypass -File arrancar_servidor.ps1
```

### 4 — Crear acceso directo opcional

```powershell
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Documents\Arrancar Servidor.lnk")
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$PWD\arrancar_servidor.ps1`""
$Shortcut.Save()
```

## Licencia

MIT License — libre para usar y modificar