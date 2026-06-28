# =============================================
# config.example.ps1
#
# INSTRUCCIONES:
# 1. Copia este archivo y llamalo config.ps1
# 2. Rellena cada variable con tus datos reales
# 3. Guarda config.ps1 en la misma carpeta
#    que arrancar_servidor.ps1
#
# IMPORTANTE: config.ps1 no se sube a GitHub
# porque contiene datos personales de tu sistema
# =============================================

# Ruta completa al ejecutable vmrun.exe
# Este archivo viene con VMware Workstation
# Normalmente esta en:
# C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe
$vmrunPath = "[escribe aqui la ruta completa a vmrun.exe]"

# Ruta completa al archivo .vmx de tu maquina virtual
# Lo encuentras en la carpeta donde guardaste la VM
# Ejemplo:
# C:\Users\TuUsuario\Documents\Virtual Machines\MiVM\MiVM.vmx
$vmxPath = "[escribe aqui la ruta completa al archivo .vmx de tu VM]"

# Nombre de usuario con el que te conectas por SSH
# Es el usuario que creaste al instalar el SO en la VM
$sshUser = "[escribe aqui tu usuario SSH]"

# Direccion IP de tu maquina virtual
# Puedes verla ejecutando 'ip addr' dentro de la VM
$sshHost = "[escribe aqui la IP de tu VM, ejemplo: 192.168.x.x]"

# Segundos que espera el script a que arranque
# el sistema operativo de la VM antes de conectarse
# Aumenta este numero si tu VM tarda mas en arrancar
$bootWait = 45