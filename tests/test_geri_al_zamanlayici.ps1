# geri_al_zamanlayici.ps1 testi. Gercek duvar/gorev degisikligi YOK: tum degistiren komutlar sahte fonksiyonla golgelenir.
# Calistir: powershell -NoProfile -ExecutionPolicy Bypass -File tests\test_geri_al_zamanlayici.ps1   (cikis 0 = gecti)
$ErrorActionPreference = 'Stop'
$betik = Join-Path (Split-Path $PSScriptRoot -Parent) 'araclar\geri_al_zamanlayici.ps1'
$gecici = Join-Path ([IO.Path]::GetTempPath()) ('dg_test_geri_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $gecici | Out-Null
$basarisiz = 0; $toplam = 0
function Dogrula([bool]$kosul, [string]$ad) {
    $script:toplam++
    if ($kosul) { Write-Host "  GECTI  $ad" } else { Write-Host "  KALDI  $ad"; $script:basarisiz++ }
}

# ---- sahte komutlar (betigin gordugu ust kapsamda tanimli) ----
function netsh {
    $global:Cagri += ('netsh ' + ($args -join ' '))
    if ($global:NetshHata) { $global:LASTEXITCODE = 1; return }
    Set-Content -LiteralPath $args[-1] -Value 'sahte yedek'
    $global:LASTEXITCODE = 0
}
function Register-ScheduledTask { param($TaskName, $Action, $Trigger, $Principal, $Settings, [switch]$Force)
    $global:Cagri += "Register-ScheduledTask $TaskName"; $global:Kayit = @{ Eylem = $Action; Tetik = $Trigger; Kimlik = $Principal; Ayar = $Settings }; $global:GorevVar = $true }
function Unregister-ScheduledTask { param($TaskName, $Confirm)
    $global:Cagri += "Unregister-ScheduledTask $TaskName"; $global:GorevVar = $false }
function Get-ScheduledTask { param($TaskName, $ErrorAction)
    if ($global:GorevVar) { return [pscustomobject]@{ TaskName = $TaskName } } return $null }
function New-ScheduledTaskAction { param($Execute, $Argument) [pscustomobject]@{ Execute = $Execute; Argument = $Argument } }
function New-ScheduledTaskTrigger { param([switch]$Once, $At) [pscustomobject]@{ Once = $Once.IsPresent; At = $At } }
function New-ScheduledTaskPrincipal { param($UserId, $LogonType, $RunLevel) [pscustomobject]@{ UserId = $UserId; LogonType = $LogonType; RunLevel = $RunLevel } }
function New-ScheduledTaskSettingsSet { param([switch]$Hidden, [switch]$StartWhenAvailable, [switch]$AllowStartIfOnBatteries, [switch]$DontStopIfGoingOnBatteries, $ExecutionTimeLimit)
    [pscustomobject]@{ Hidden = $Hidden.IsPresent; StartWhenAvailable = $StartWhenAvailable.IsPresent } }
function Set-Acl { param($LiteralPath, $AclObject) $global:Cagri += "Set-Acl $LiteralPath" }
function Test-DgYonetici { return $global:Yonetici }

function Calistir([hashtable]$Arglar) {
    $global:Cagri = @(); $global:LASTEXITCODE = $null
    $v = Join-Path $gecici ('veri_' + [guid]::NewGuid().ToString('N').Substring(0, 6))
    $cikti = (& $betik @Arglar -VeriKlasoru $v *>&1 | Out-String -Width 4000)
    return [pscustomobject]@{ Cikti = $cikti; Kod = $global:LASTEXITCODE; Cagri = $global:Cagri; Veri = $v }
}
function DurumSatiri($r) { @($r.Cikti -split "`r?`n" | Where-Object { $_ -match '^\| \d\d:\d\d \|' }) }
function Say($r, [string]$onEk) { @($r.Cagri | Where-Object { $_ -like "$onEk*" }).Count }

try {
    Write-Host 'test_geri_al_zamanlayici'
    $global:Yonetici = $true; $global:GorevVar = $false; $global:NetshHata = $false

    # 1. sozdizimi + BOM
    $hatalar = $null; $null = [System.Management.Automation.Language.Parser]::ParseFile($betik, [ref]$null, [ref]$hatalar)
    Dogrula ($hatalar.Count -eq 0) 'sozdizimi hatasiz'
    $b = [IO.File]::ReadAllBytes($betik)[0..2]
    Dogrula ($b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) 'UTF-8 BOM var'

    # 2. varsayilan DryRun
    $r = Calistir @{}
    Dogrula ($r.Kod -eq 0) 'DryRun cikis 0'
    Dogrula ($r.Cagri.Count -eq 0) 'DryRun hicbir degistiren komut cagirmadi'
    Dogrula ($r.Cikti -match '\[DRYRUN\]') 'DryRun ciktisi [DRYRUN] etiketli'
    Dogrula (-not (Test-Path $r.Veri)) 'DryRun klasor olusturmadi'
    $ds = @(DurumSatiri $r)
    Dogrula ($ds.Count -eq 1 -and (($ds[0] -split ' \| ').Count -eq 6)) 'DryRun sonunda tek, 6 alanli DURUM satiri'
    Dogrula ($r.Cikti -match [regex]::Escape('powershell -NoProfile -ExecutionPolicy Bypass -File araclar\geri_al_zamanlayici.ps1 -Dakika 10 -Uygula')) 'DryRun ipucu tam calistirma bicimiyle'
    Dogrula ($r.Cikti -match 'Yonetici PowerShell') 'DryRun ipucu Yonetici PowerShell diyor'
    Dogrula ($r.Cikti -cnotmatch '[^\x00-\x7F]') 'cikti ASCII'

    # 3. -Uygula -DryRun birlikte: DryRun kazanir
    $r = Calistir @{ Uygula = $true; DryRun = $true }
    Dogrula ($r.Cagri.Count -eq 0 -and $r.Kod -eq 0) '-Uygula -DryRun: DryRun kazandi, degisiklik yok'

    # 4. yonetici degil
    $global:Yonetici = $false
    $r = Calistir @{ Uygula = $true }
    Dogrula ($r.Kod -eq 2) 'yonetici degilse cikis 2'
    Dogrula ($r.Cagri.Count -eq 0) 'yonetici degilse hicbir sey cagrilmadi'
    Dogrula ($r.Cikti -match 'Yonetici') 'yonetici degilse Turkce aciklama'
    $global:Yonetici = $true

    # 5. gercek akis (sahte komutlarla)
    $global:GorevVar = $false
    $r = Calistir @{ Uygula = $true; Dakika = 7 }
    Dogrula ($r.Kod -eq 0) '-Uygula cikis 0'
    Dogrula ((Say $r 'netsh advfirewall export') -eq 1) 'duvar bir kez disa aktarildi'
    Dogrula ((Say $r 'Register-ScheduledTask') -eq 1) 'gorev bir kez kaydedildi'
    $i1 = [array]::IndexOf($r.Cagri, ($r.Cagri | Where-Object { $_ -like 'netsh advfirewall export*' } | Select-Object -First 1))
    $i2 = [array]::IndexOf($r.Cagri, ($r.Cagri | Where-Object { $_ -like 'Register-ScheduledTask*' } | Select-Object -First 1))
    Dogrula ($i1 -ge 0 -and $i1 -lt $i2) 'yedek gorevden ONCE alindi'
    Dogrula ($global:Kayit.Ayar.Hidden) 'gorev gizli (Hidden)'
    Dogrula ($global:Kayit.Kimlik.UserId -eq 'NT AUTHORITY\SYSTEM' -and $global:Kayit.Kimlik.RunLevel -eq 'Highest') 'gorev SYSTEM/Highest'
    Dogrula ($global:Kayit.Eylem.Argument -match '-WindowStyle Hidden') 'eylem gizli pencere bayragi tasiyor'
    $fark = ($global:Kayit.Tetik.At - (Get-Date)).TotalMinutes
    Dogrula ($fark -gt 6 -and $fark -le 7.1) 'tetik ~7 dk sonra'
    Dogrula ((Say $r 'Set-Acl') -eq 1) 'veri klasorune kilitli ACL uygulandi'
    $gy = Join-Path $r.Veri 'geri_yukle.ps1'
    Dogrula (Test-Path $gy) 'geri_yukle.ps1 yazildi'
    $metin = Get-Content $gy -Raw
    Dogrula ($metin -match 'advfirewall import' -and $metin -match 'Unregister-ScheduledTask') 'geri yukleme: import + kendini kaldirma'
    Dogrula ($r.Cikti -match 'Iptal') 'cikti -Iptal yolunu soyluyor'
    Dogrula ($r.Cikti -match [regex]::Escape('-File araclar\geri_al_zamanlayici.ps1 -Iptal')) '-Iptal ipucu tam calistirma bicimiyle'
    $ds = @(DurumSatiri $r)
    Dogrula ($ds.Count -eq 1 -and (($ds[0] -split ' \| ').Count -eq 6) -and $ds[0] -match '\| yarim \|') 'Uygula sonunda tek 6 alanli DURUM satiri (yarim)'
    Dogrula ($r.Cikti -cnotmatch '[^\x00-\x7F]') 'Uygula ciktisi ASCII'
    $r2 = Calistir @{ Uygula = $true; DurumSatiriYok = $true }
    $global:GorevVar = $false
    Dogrula (@(DurumSatiri $r2).Count -eq 0) '-DurumSatiriYok DURUM satirini kapatir'

    # 6. zaten bekleyen gorev: yedegi ezme
    $global:GorevVar = $true
    $r = Calistir @{ Uygula = $true }
    Dogrula ($r.Kod -eq 3) 'bekleyen gorev varsa cikis 3'
    Dogrula ((Say $r 'netsh') -eq 0 -and (Say $r 'Register') -eq 0) 'bekleyen gorev varsa yedek ezilmedi, gorev kurulmadi'

    # 7. yedek alinamadi
    $global:GorevVar = $false; $global:NetshHata = $true
    $r = Calistir @{ Uygula = $true }
    Dogrula ($r.Kod -eq 4) 'yedek basarisizsa cikis 4'
    Dogrula ((Say $r 'Register') -eq 0) 'yedek basarisizsa gorev kurulmadi'
    $global:NetshHata = $false

    # 8. -Iptal
    $global:GorevVar = $true
    $r = Calistir @{ Iptal = $true }
    Dogrula ($r.Kod -eq 0 -and (Say $r 'Unregister-ScheduledTask') -eq 1) '-Iptal gorevi kaldirdi'
    Dogrula ($r.Cikti -match 'Tamam: geri alma gorevi kaldirildi\. Yeni duvar ayari kalici\.') '-Iptal tam cikti satiri'
    $ds = @(DurumSatiri $r)
    Dogrula ($ds.Count -eq 1 -and (($ds[0] -split ' \| ').Count -eq 6) -and $ds[0] -match '\| bitti \|') '-Iptal sonunda 6 alanli DURUM satiri (bitti)'
    Dogrula ((Say $r 'netsh') -eq 0) '-Iptal duvara dokunmadi'
    $global:GorevVar = $false
    $r = Calistir @{ Iptal = $true }
    Dogrula ($r.Kod -eq 0 -and $r.Cagri.Count -eq 0) '-Iptal gorev yoksa zararsiz'
    $global:GorevVar = $true
    $r = Calistir @{ Iptal = $true; DryRun = $true }
    Dogrula ($r.Kod -eq 0 -and $r.Cagri.Count -eq 0) '-Iptal -DryRun degistirmedi'
    $global:GorevVar = $false
}
finally {
    Remove-Item -LiteralPath $gecici -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ("Sonuc: {0} test, {1} basarisiz" -f $toplam, $basarisiz)
if ($basarisiz -gt 0) { exit 1 } else { exit 0 }
