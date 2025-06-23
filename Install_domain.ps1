# Требует запуска от администратора
#Requires -RunAsAdministrator

<#
.SYNOPSIS
Устанавливает и настраивает Domain Controller на Windows Server 2016
.DESCRIPTION
1. Устанавливает роли AD-Domain-Services и DNS-сервер
2. Продвигает сервер в контроллер домена
3. Создает новый лес домена
4. Настраивает автоматические параметры
.PARAMETER DomainName
Полное доменное имя (например, "contoso.com")
.PARAMETER NetBIOSName
Имя NetBIOS домена (например, "CONTOSO")
.PARAMETER SafeModePassword
Пароль для режима восстановления служб каталогов (DSRM)
.EXAMPLE
.\Install-DomainController.ps1 -DomainName "contoso.com" -NetBIOSName "CONTOSO" -SafeModePassword "P@ssw0rd123"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$DomainName,
    
    [Parameter(Mandatory=$true)]
    [string]$NetBIOSName,
    
    [Parameter(Mandatory=$true)]
    [securestring]$SafeModePassword
)

# Проверка ОС
if ((Get-CimInstance Win32_OperatingSystem).Caption -notmatch "Windows Server 2016") {
    Write-Warning "Этот скрипт предназначен для Windows Server 2016!"
    exit 1
}

# Проверка статического IP
$adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
foreach ($adapter in $adapters) {
    $ipconfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4
    if ($ipconfig.PrefixOrigin -ne "Manual") {
        Write-Warning "Сетевой адаптер $($adapter.Name) не имеет статического IPv4-адреса!"
        exit 1
    }
}

# Установка необходимых компонентов
Write-Host "Установка ролей AD-Domain-Services и DNS..." -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools

# Продвижение сервера в контроллер домена
Write-Host "Настройка контроллера домена..." -ForegroundColor Cyan
try {
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $NetBIOSName `
        -ForestMode "Win2016" `
        -DomainMode "Win2016" `
        -InstallDns:$true `
        -CreateDnsDelegation:$false `
        -DatabasePath "C:\Windows\NTDS" `
        -LogPath "C:\Windows\NTDS" `
        -SysvolPath "C:\Windows\SYSVOL" `
        -SafeModeAdministratorPassword $SafeModePassword `
        -Force:$true `
        -NoRebootOnCompletion:$false `
        -WarningAction SilentlyContinue
    
    Write-Host "Контроллер домена успешно настроен!" -ForegroundColor Green
}
catch {
    Write-Host "Ошибка настройки: $_" -ForegroundColor Red
    exit 1
}

# Дополнительные настройки (выполняются после перезагрузки)
Write-Host "Дополнительные настройки после перезагрузки..." -ForegroundColor Yellow
$rebootScript = @"
# Настройка DNS-сервера
Set-DnsServerForwarder -IPAddress 8.8.8.8, 8.8.4.4 -PassThru

# Настройка времени
w32tm /config /syncfromflags:domhier /update
net stop w32time && net start w32time

# Создание тестового пользователя
New-ADUser -Name "TestUser" -GivenName "Test" -Surname "User" -SamAccountName "testuser" -UserPrincipalName "testuser@$DomainName" -AccountPassword (ConvertTo-SecureString "P@ssw0rd123" -AsPlainText -Force) -Enabled $true

# Экспорт настроек
Get-ADDomain | Export-Clixml C:\DomainConfig.xml
Write-Host "Настройка завершена!" -ForegroundColor Green
"@

$rebootScript | Out-File "C:\PostInstall.ps1" -Encoding UTF8

# Добавление задания в планировщик для выполнения после перезагрузки
$trigger = New-ScheduledTaskTrigger -AtLogOn
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\PostInstall.ps1"
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "PostDCInstall" -User "SYSTEM" -RunLevel Highest