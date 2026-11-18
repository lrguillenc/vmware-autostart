# =============================================
# Configuracion de VMware_Autostart
# Copia este archivo como config.ps1 y rellena tus datos:
#   Copy-Item config.example.ps1 config.ps1
# =============================================

$vmrunPath = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
$vmxPath   = "C:\Users\TU_USUARIO\Documents\Virtual Machines\TU_VM\TU_VM.vmx"
$sshUser   = "tu_usuario"
$sshHost   = "10.X.X.X"
$bootWait  = 30   # segundos de espera hasta que arranca el sistema operativo