<#
.SYNOPSIS
    Devuelve el número de fallos de replicación de AD que ve este Domain Controller.

.DESCRIPTION
    Pensado para usarse como UserParameter del agente de Zabbix. Imprime SOLO un número:
        0   -> sin fallos de replicación
        N>0 -> N socios con fallos de replicación
        -1  -> el script no pudo consultar (módulo ausente, permisos, error de AD)

    Debe ejecutarse en un Domain Controller, con el módulo ActiveDirectory (RSAT) disponible.
    El agente corre como SYSTEM; en un DC, SYSTEM consulta AD con la cuenta del equipo.

.NOTES
    Copiar a: C:\Program Files\Zabbix Agent 2\scripts\Get-ADReplFailures.ps1
    Probar manualmente:
        powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent 2\scripts\Get-ADReplFailures.ps1"
#>
$ErrorActionPreference = 'Stop'
try {
    Import-Module ActiveDirectory
    $fallos = @(Get-ADReplicationFailure -Target $env:COMPUTERNAME -Scope Server)
    Write-Output $fallos.Count
}
catch {
    Write-Output -1
}
