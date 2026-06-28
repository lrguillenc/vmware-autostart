# =============================================
# arrancar_servidor.ps1
# Script de arranque automatico de VM VMware
# Autor: Luis Rodrigo Guillen Calderon
# GitHub: github.com/lrguillenc
#
# USO:
# 1. Copia config.example.ps1 como config.ps1
# 2. Rellena config.ps1 con tus datos
# 3. Ejecuta este script con doble clic
# =============================================

# --- CARGAR CONFIGURACION ---
# $PSScriptRoot es la carpeta donde está este script
# El punto al inicio significa "ejecutar este archivo
# en el mismo contexto" para que las variables queden
# disponibles en este script
$configPath = "$PSScriptRoot\config.ps1"

# Comprobamos si el archivo config.ps1 existe
# Si no existe mostramos un error y salimos
if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: No se encontro config.ps1"
    Write-Host "Copia config.example.ps1 como config.ps1 y rellena tus datos"
    Read-Host "Pulsa Enter para salir"
    exit 1
}

# Cargamos las variables definidas en config.ps1
. $configPath

# =============================================
# INICIO DEL SCRIPT
# =============================================
Clear-Host
Write-Host "================================================"
Write-Host "   VMware Autostart - Arranque Automatico"
Write-Host "================================================"

# =============================================
# PASO 1 - Verificar que los archivos necesarios
# existen antes de hacer nada
# =============================================
Write-Host ""
Write-Host "[1/5] Verificando archivos necesarios..."

# Test-Path comprueba si un archivo o carpeta existe
# Devuelve True si existe o False si no existe
if (-not (Test-Path $vmrunPath)) {
    Write-Host "     ERROR: vmrun.exe no encontrado en:"
    Write-Host "     $vmrunPath"
    Write-Host "     Verifica que VMware Workstation esta instalado"
    Read-Host "Pulsa Enter para salir"
    exit 1
}
Write-Host "     OK: vmrun.exe encontrado"

if (-not (Test-Path $vmxPath)) {
    Write-Host "     ERROR: Archivo .vmx no encontrado en:"
    Write-Host "     $vmxPath"
    Write-Host "     Verifica la ruta de tu maquina virtual"
    Read-Host "Pulsa Enter para salir"
    exit 1
}
Write-Host "     OK: Archivo .vmx encontrado"

# =============================================
# PASO 2 - Comprobar si la VM ya esta encendida
# para no intentar encenderla dos veces
# =============================================
Write-Host ""
Write-Host "[2/5] Verificando estado de la maquina virtual..."

# vmrun list devuelve una lista de todas las VMs
# que estan encendidas en este momento
# Buscamos si nuestra VM aparece en esa lista
$vmList    = & $vmrunPath -T ws list 2>&1
$vmRunning = $vmList | Where-Object { 
    $_ -match [regex]::Escape($vmxPath) 
}

if ($vmRunning) {
    # La VM ya estaba encendida, no hay que hacer nada
    Write-Host "     OK: La maquina virtual está encendida"
    $skipBoot = $true
} else {
    # La VM esta apagada, hay que encenderla
    $skipBoot = $false
    Write-Host "     AVISO: La maquina virtual está apagada"

    # =============================================
    # PASO 3 - Abrir VMware si no esta abierto
    # =============================================
    Write-Host ""
    Write-Host "[3/5] Iniciando VMware Workstation..."

    # Get-Process busca si hay un proceso llamado vmware
    # corriendo en este momento
    # ErrorAction SilentlyContinue evita mostrar error
    # si el proceso no existe
    $vmwareProc = Get-Process -Name "vmware" -ErrorAction SilentlyContinue

    if (-not $vmwareProc) {
        # VMware no estaba abierto, lo abrimos
        # Split-Path obtiene la carpeta que contiene vmrun.exe
        # para buscar vmware.exe en la misma carpeta
        $vmwareDir = Split-Path $vmrunPath
        Start-Process "$vmwareDir\vmware.exe"

        # Esperamos 15 segundos para que VMware cargue
        # completamente antes de intentar encender la VM
        # Si no esperamos vmrun falla porque VMware
        # no ha terminado de inicializarse
        Write-Host "     Esperando que VMware cargue (15 segundos)..."
        Start-Sleep -Seconds 15
        Write-Host "     OK: VMware listo"
    } else {
        Write-Host "     OK: VMware estaba abierto"
    }

    # =============================================
    # PASO 4 - Encender la maquina virtual
    # con sistema de reintentos por si falla
    # =============================================
    Write-Host ""
    Write-Host "[4/5] Encendiendo la maquina virtual..."

    $intentos  = 0
    $encendido = $false

    # Intentamos encender la VM hasta 3 veces
    # por si el primer intento falla
    while ($intentos -lt 3 -and -not $encendido) {
        $intentos++
        Write-Host "     Intento $intentos de 3..."

        # vmrun start enciende la VM
        # -T ws indica que es VMware Workstation
        # nogui la enciende en segundo plano sin ventana
        $result = & $vmrunPath -T ws start $vmxPath nogui 2>&1

        # $LASTEXITCODE es 0 si el comando tuvo exito
        # y distinto de 0 si hubo algun error
        if ($LASTEXITCODE -eq 0) {
            Write-Host "     OK: Maquina virtual encendida en el intento $intentos"
            $encendido = $true
        } else {
            Write-Host "     ERROR en intento $intentos : $result"
            if ($intentos -lt 3) {
                Write-Host "     Esperando 5 segundos antes del siguiente intento..."
                Start-Sleep -Seconds 5
            }
        }
    }

    # Si los 3 intentos fallaron abrimos VMware
    # con el archivo vmx para que el usuario
    # pueda encenderla manualmente
    if (-not $encendido) {
        Write-Host "     ERROR: No se pudo encender la VM despues de 3 intentos"
        Write-Host "     Abriendo VMware para encenderla manualmente..."
        $vmwareDir = Split-Path $vmrunPath
        Start-Process "$vmwareDir\vmware.exe" -ArgumentList $vmxPath
        Read-Host "     Enciende la VM manualmente y pulsa Enter para continuar"
    }

    # =============================================
    # Esperar a que arranque el sistema operativo
    # de la maquina virtual antes de intentar
    # conectarnos por SSH
    # =============================================
    Write-Host ""
    Write-Host "     Esperando arranque del servidor ($bootWait segundos)..."

    # Mostramos una barra de progreso visual
    # para saber cuanto tiempo queda
    for ($i = $bootWait; $i -gt 0; $i--) {
        $pct = [math]::Round((($bootWait - $i) / $bootWait) * 100)
        Write-Progress `
            -Activity "Arrancando servidor" `
            -Status "$i segundos restantes..." `
            -PercentComplete $pct
        Start-Sleep -Seconds 1
    }

    # Cerramos la barra de progreso
    Write-Progress -Activity "Arrancando servidor" -Completed
    Write-Host "     OK: Servidor listo"
}

# =============================================
# PASO 5 - Abrir WSL con la conexion SSH
# lista automaticamente
# =============================================
Write-Host ""
Write-Host "[5/5] Abriendo WSL con conexion SSH a $sshHost..."

# Comprobamos si Windows Terminal esta instalado
# Es la aplicacion moderna de terminal de Windows
$wtAvailable = Get-Command "wt.exe" -ErrorAction SilentlyContinue

if ($wtAvailable) {
    # Abrimos Windows Terminal con WSL y ejecutamos
    # el comando SSH directamente al arrancar
    Start-Process "wt.exe" -ArgumentList "wsl.exe -e ssh $sshUser@$sshHost"
    Write-Host "     OK: Windows Terminal abierto con SSH"
} else {
    # Si no hay Windows Terminal usamos PowerShell
    # como alternativa
    Start-Process "powershell.exe" -ArgumentList "-NoExit -Command wsl -e ssh $sshUser@$sshHost"
    Write-Host "     OK: PowerShell abierto con SSH"
}

Write-Host ""
Write-Host "================================================"
Write-Host "   Servidor listo para administrar"
Write-Host "================================================"