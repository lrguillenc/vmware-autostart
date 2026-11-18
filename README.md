# VMware Autostart

Script de PowerShell para arrancar automáticamente una máquina
virtual VMware Workstation y conectarse a ella por SSH mediante WSL.

## Autor

**Luis Rodrigo Guillén Calderón**
GitHub: [@lrguillenc](https://github.com/lrguillenc)

## Características

- Verifica que existen `vmrun.exe` y el archivo `.vmx` antes de empezar
- Verifica si la VM ya está encendida antes de hacer power on
- Enciende la VM en segundo plano (`nogui`), sin abrir la aplicación de VMware
- Sistema de reintentos automáticos si el arranque falla (plan B: abre VMware para encenderla a mano)
- Cuenta atrás visual mientras arranca el sistema operativo
- Abre Windows Terminal (o PowerShell si no está disponible) con la conexión SSH lista y cierra su propia ventana
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

Abre `config.ps1` y rellena con tus datos. Este archivo está en `.gitignore`,
así que no se sube al repositorio.

```powershell
$vmrunPath = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
$vmxPath   = "C:\Users\TU_USUARIO\Documents\Virtual Machines\TU_VM\TU_VM.vmx"
$sshUser   = "tu_usuario"
$sshHost   = "10.X.X.X"
$bootWait  = 30
```

| Variable | Qué es |
|---|---|
| `$vmrunPath` | Ruta de `vmrun.exe` |
| `$vmxPath` | Ruta del archivo `.vmx` de la VM |
| `$sshUser` | Usuario SSH de la VM |
| `$sshHost` | IP de la VM |
| `$bootWait` | Segundos de espera tras encender la VM |

### 3 — Ejecutar el script

```powershell
powershell -ExecutionPolicy RemoteSigned -File .\arrancar_servidor.ps1
```

### 4 — Crear acceso directo opcional

```powershell
$ws  = New-Object -ComObject WScript.Shell
$acc = $ws.CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\Arrancar Servidor.lnk")
$acc.TargetPath       = "powershell.exe"
$acc.Arguments        = "-ExecutionPolicy RemoteSigned -File `"$PWD\arrancar_servidor.ps1`""
$acc.WorkingDirectory = "$PWD"
$acc.Save()
```

Si necesitas ver los mensajes de error, añade `-NoExit` al principio de los
argumentos: así la ventana no se cierra al terminar.

## Cómo funciona

1. Verifica que `vmrun.exe` y el `.vmx` existen.
2. Comprueba si la VM ya está encendida; si lo está, salta al último paso.
3. Enciende la VM con `vmrun start ... nogui` (hasta 3 intentos).
4. Espera `$bootWait` segundos a que arranque el sistema operativo.
5. Abre una terminal con `ssh usuario@IP` y cierra la ventana de PowerShell.

## Historia: del problema a la versión actual

Este repositorio nace de un problema real. Se documenta el proceso porque
el diagnóstico fue más instructivo que el script.

### Versión inicial

La configuración estaba dentro del script. Abría la aplicación de VMware y
esperaba 15 segundos, encendía la VM con `vmrun`, esperaba 45 segundos más
y abría SSH.

### Problema 1: el script "no hacía nada"

Al lanzarlo con clic derecho, la ventana de PowerShell se abría y se cerraba
al instante. `Get-ExecutionPolicy -List` mostraba todos los ámbitos como
`Undefined`, es decir, la política por defecto de Windows (`Restricted`), que
bloquea los archivos `.ps1`.

Solución: lanzarlo con `-ExecutionPolicy RemoteSigned` desde un acceso
directo, o fijar esa política solo para el usuario con
`Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`.

### Problema 2: SSH falla con "No route to host"

Con el script ya funcionando, la VM arrancaba pero SSH no conectaba.

| Prueba | Resultado | Conclusión |
|---|---|---|
| `Test-NetConnection IP -Port 22` desde Windows | Falla | No es un problema de WSL |
| `vmrun list` | La VM figura encendida | La VM arranca |
| Arrancar con `gui` en vez de `nogui` | Falla igual | El modo de arranque no es la causa |
| Esperar más tiempo | Falla igual | No es un problema de tiempo |
| Fijar `VMnet0` al adaptador físico en lugar de *Automatic* | Falla igual | No lo resolvió por sí solo (se dejó fijado) |
| En la VM: `ping` a la puerta de enlace | Falla | La VM no llega a su router |
| En la VM: `ip neigh` | `10.X.1.1 INCOMPLETE` | Busca un router en otra subred |

El dato decisivo fue el último: la red real era `10.X.0.X`, pero la VM
preguntaba por `10.X.1.1`, el router del proveedor anterior.

### Causa

Tras cambiar de proveedor de internet, el archivo de netplan de la VM
(`/etc/netplan/50-cloud-init.yaml`) conservaba la IP estática y la puerta de
enlace de la red antigua. Además, el archivo volvía a los datos viejos por sí
solo: `cloud-init` lo regeneraba.

### Solución

1. Corregir la IP y la puerta de enlace en netplan.
2. Aplicar el cambio con prueba (`sudo netplan try`).
3. Desactivar la gestión de red de `cloud-init`, para que no vuelva a
   regenerar el archivo con la configuración antigua.

Los comandos están en la sección siguiente. Tras hacerlo, la configuración se
mantiene después de reiniciar y de apagar la VM.

### Mejoras al script

| Aspecto | Versión inicial | Versión actual |
|---|---|---|
| Configuración | Dentro del script | En `config.ps1` (plantilla: `config.example.ps1`) |
| Aplicación de VMware | La abría y esperaba 15 s | No se abre: `vmrun` no la necesita. Solo como plan B si falla el encendido |
| Espera tras encender | 45 s | 30 s (Ubuntu tardaba unos 20 s en llegar al login) |
| Ventana de PowerShell | Quedaba abierta | Se cierra tras abrir SSH |
| Archivo de configuración ausente | Fallo poco claro | Mensaje explícito |
| Política de ejecución en los ejemplos | `Bypass` | `RemoteSigned`, que es más prudente |

### Lecciones

- Cuando algo falla "sin motivo", comprobar capa por capa: primero si el
  destino responde desde fuera, luego qué ve la máquina desde dentro.
- Descartar hipótesis con una prueba concreta cada una evita cambiar varias
  cosas a la vez y no saber cuál arregló el problema.
- Una IP estática es una configuración que caduca si cambia la red.

## Solución de problemas

### Al ejecutarlo "no pasa nada"

Con la política de ejecución por defecto de Windows (`Restricted`), los
archivos `.ps1` no se ejecutan. Para ver el error, lánzalo desde una consola
ya abierta y comprueba la política:

```powershell
Get-ExecutionPolicy -List
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

La segunda línea solo afecta a tu usuario. Si descargaste el repositorio como
ZIP, Windows puede marcar los archivos como bloqueados:
`Unblock-File .\arrancar_servidor.ps1`.

### SSH falla con "No route to host"

Significa que tu PC no llega a la IP de la VM. Diagnóstico, por orden:

1. Desde Windows: `Test-NetConnection IP_DE_LA_VM -Port 22`. Si falla, el
   problema no es de WSL.
2. En la consola de la VM: `ip a` (¿tiene la IP esperada?) e `ip neigh`. Una
   entrada `INCOMPLETE` o `FAILED` para la puerta de enlace indica que nadie
   responde en esa dirección.
3. En VMware, con la VM en modo Bridged, comprueba en
   *Edit > Virtual Network Editor* que `VMnet0` está enlazado a tu tarjeta de
   red física y no en *Automatic*: con varios adaptadores virtuales puede
   elegir uno equivocado.

### Corregir la configuración de red de la VM (netplan)

Si la VM conserva la subred o la puerta de enlace de una red anterior, edita
el archivo de netplan (el nombre del archivo y de la interfaz pueden variar):

```bash
sudo nano /etc/netplan/50-cloud-init.yaml
```

Cambia solo las líneas `addresses` y `via`; deja el resto como está:

```yaml
network:
  version: 2
  ethernets:
    ens33:
      addresses:
        - "10.X.X.X/24"
      routes:
        - to: "default"
          via: "10.X.X.1"
```

Aplica con prueba (revierte solo a los 120 segundos si pierdes la conexión;
pulsa Enter para confirmar):

```bash
sudo netplan try
```

### Evitar que cloud-init regenere la configuración antigua

`cloud-init` escribe `/etc/netplan/50-cloud-init.yaml` en cada arranque a
partir de sus propios datos, por lo que puede deshacer tus cambios y devolver
la configuración vieja. Para impedirlo se crea un archivo de configuración que
le dice que no gestione la red:

```bash
echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
```

A partir de ese momento, netplan es la única fuente de la configuración de
red. Para comprobar que se mantiene, reinicia con `sudo reboot` y revisa de
nuevo el archivo con `sudo cat /etc/netplan/50-cloud-init.yaml`.

### No veo la ventana de la VM

Es lo esperado: se arranca con `nogui`, es decir, en segundo plano. Para verla,
abre VMware y usa *File > Open* con el `.vmx`. Para apagarla sin ventana:

```powershell
& "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe" -T ws stop "RUTA\TU_VM.vmx" soft
```

`soft` pide un apagado ordenado al sistema (requiere VMware Tools); `hard`
equivale a cortar la corriente.

### SSH falla nada más abrirse

Si el error aparece justo al abrir la terminal, es posible que Ubuntu aún no
haya terminado de arrancar. Sube `$bootWait` en `config.ps1` (por ejemplo, a 40).

## Licencia

MIT License — libre para usar y modificar