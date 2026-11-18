# =============================================
# TintaHub - Script de arranque automatico
# Autor: Luis Rodrigo Guillen Calderon
# =============================================

# --- CONFIGURACION ---
$configPath = Join-Path $PSScriptRoot "config.ps1"
if (-not (Test-Path $configPath)) {
    Write-Host "No se encuentra config.ps1. Copia config.example.ps1 como config.ps1 y rellena tus datos." -ForegroundColor Red
    Read-Host "Pulsa Enter para salir"
    exit 1
}
. $configPath

# --- FUNCIONES ---
function Write-Step { param($step, $msg) Write-Host "`n[$step] $msg" -ForegroundColor Yellow }
function Write-OK   { param($msg) Write-Host "     OK: $msg" -ForegroundColor Green }
function Write-WARN { param($msg) Write-Host "     AVISO: $msg" -ForegroundColor Yellow }
function Write-ERR  { param($msg) Write-Host "     ERROR: $msg" -ForegroundColor Red }

# --- INICIO ---
Clear-Host
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   TintaHub Server - Arranque Automatico        " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# PASO 1 - Verificar archivos necesarios
Write-Step "1/5" "Verificando archivos necesarios..."

if (-not (Test-Path $vmrunPath)) {
    Write-ERR "vmrun.exe no encontrado"
    Read-Host "Pulsa Enter para salir"
    exit 1
}
Write-OK "vmrun.exe encontrado"

if (-not (Test-Path $vmxPath)) {
    Write-ERR "Archivo .vmx no encontrado en: $vmxPath"
    Read-Host "Pulsa Enter para salir"
    exit 1
}
Write-OK "Archivo .vmx encontrado"

# PASO 2 - Verificar si la VM ya esta encendida
Write-Step "2/5" "Verificando estado de TintaHub_Server..."

$vmList    = & $vmrunPath -T ws list 2>&1
$vmRunning = $vmList | Where-Object { $_ -match [regex]::Escape($vmxPath) }

if ($vmRunning) {
    Write-OK "TintaHub_Server ya estaba encendido. Saltando arranque."
    $skipBoot = $true
} else {
    $skipBoot = $false
    Write-WARN "TintaHub_Server esta apagado"

    # PASO 3 - Encender la VM con reintentos
    Write-Step "4/5" "Encendiendo TintaHub_Server..."

    $intentos = 0
    $encendido = $false

    while ($intentos -lt 3 -and -not $encendido) {
        $intentos++
        Write-WARN "Intento $intentos de 3..."

        $result = & $vmrunPath -T ws start $vmxPath nogui 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-OK "Power on exitoso en el intento $intentos"
            $encendido = $true
        } else {
            Write-ERR "Intento $intentos fallido: $result"
            if ($intentos -lt 3) {
                Write-WARN "Esperando 5 segundos antes del siguiente intento..."
                Start-Sleep -Seconds 5
            }
        }
    }

    if (-not $encendido) {
        Write-ERR "No se pudo encender la VM despues de 3 intentos"
        Write-WARN "Abriendo VMware manualmente para que puedas encenderla..."
        Start-Process "C:\Program Files (x86)\VMware\VMware Workstation\vmware.exe" -ArgumentList $vmxPath
        Read-Host "Enciende la VM manualmente y pulsa Enter para continuar"
    }

    # Esperar arranque de Ubuntu
    Write-Host "`n     Esperando arranque de Ubuntu Server ($bootWait segundos)..." -ForegroundColor Yellow

    for ($i = $bootWait; $i -gt 0; $i--) {
        $pct = [math]::Round((($bootWait - $i) / $bootWait) * 100)
        Write-Progress -Activity "Arrancando Ubuntu Server" `
                       -Status "$i segundos restantes..." `
                       -PercentComplete $pct
        Start-Sleep -Seconds 1
    }
    Write-Progress -Activity "Arrancando Ubuntu Server" -Completed
    Write-OK "Ubuntu Server listo"
}

# PASO 4 - Abrir WSL con SSH
Write-Step "5/5" "Abriendo WSL con conexion SSH a $sshHost..."

$wtAvailable = Get-Command "wt.exe" -ErrorAction SilentlyContinue

if ($wtAvailable) {
    Start-Process "wt.exe" -ArgumentList "wsl.exe -e ssh $sshUser@$sshHost"
    Write-OK "Windows Terminal abierto con SSH"
} else {
    Start-Process "powershell.exe" -ArgumentList "-NoExit -Command wsl -e ssh $sshUser@$sshHost"
    Write-OK "PowerShell abierto con SSH"
}

# Cerrar esta ventana de PowerShell
Start-Sleep -Seconds 5 # Puedes cambiar los segundos que prefieras
exit