<#
.SYNOPSIS
  Iki kapi araci: guvenlik duvari ayarini yedekler, N dakika sonra kendiliginden geri yukleyen gizli bir gorev kurar.

.DESCRIPTION
  Amac: uzaktaki bilgisayarda duvar/ag ayari degistirirken baglanti kopsa bile bilgisayar kendini eski haline dondursun.
  Varsayilan DRYRUN: ne yapacagini yazar, hicbir sey degistirmez. Gercek is icin -Uygula.
  -Iptal : bekleyen geri alma gorevini kaldirir (yeni yolu ikinci cihazdan dogruladiktan sonra bunu calistirirsin).
  Yonetici (Administrator) PowerShell gerekir; betik kendini yukseltmez, gerekirse Turkce soyler.
  Dikkat: geri yukleme TUM duvar ayarini yedek aninin haline dondurur (pencere icinde baska duvar degisikligi yaptiysan o da geri gider).

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\geri_al_zamanlayici.ps1                      # yalniz ne yapacagini yazar
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\geri_al_zamanlayici.ps1 -Dakika 10 -Uygula   # yedek alir, 10 dk sonra geri yukleyen gorev kurar (Yonetici PowerShell)
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\geri_al_zamanlayici.ps1 -Iptal               # gorevi kaldirir (kullanici 'kalsin' dedikten sonra)

.NOTES
  Cikis kodlari: 0 tamam, 1 beklenmeyen hata, 2 yonetici degil, 3 zaten bekleyen geri alma var, 4 yedek alinamadi.
  Sonda 6 alanli DURUM satiri basar: | saat | adim | bitti/yarim | kanit | geri alma | siradaki |  (-DurumSatiriYok ile DURUM satiri ve yonlendirme ipuclari kapatilir; baska betik cagirirken kullanilir).
  Yedek ve geri yukleme dosyalari: %ProgramData%\dogrudan-uzak-masaustu (yalniz SYSTEM ve Administrators yazabilir;
  gorev SYSTEM olarak calistigi icin siradan kullanicinin yazabildigi klasor kullanilmaz).
#>
[CmdletBinding()]
param(
    [ValidateRange(2, 120)][int]$Dakika = 10,
    [switch]$Uygula,
    [switch]$DryRun,
    [switch]$Iptal,
    [switch]$DurumSatiriYok,
    [string]$VeriKlasoru = (Join-Path $env:ProgramData 'dogrudan-uzak-masaustu')
)

$ErrorActionPreference = 'Stop'
$GorevAdi = 'DogrudanUzakMasaustu-GeriAl'

# DryRun varsayilan; yalniz -Uygula ve -DryRun YOKSA gercek is yapilir.
$gercek = ($Uygula.IsPresent -and -not $DryRun.IsPresent)
$onEk = if ($gercek -or ($Iptal.IsPresent -and -not $DryRun.IsPresent)) { '' } else { '[DRYRUN] ' }

if (-not (Get-Command Test-DgYonetici -ErrorAction SilentlyContinue)) {
    function Test-DgYonetici {
        $kimlik = [Security.Principal.WindowsIdentity]::GetCurrent()
        $rol = New-Object Security.Principal.WindowsPrincipal($kimlik)
        return $rol.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
}

function Yaz([string]$m) { Write-Host ($onEk + $m) }

function Komut([string]$arg) {
    return ('powershell -NoProfile -ExecutionPolicy Bypass -File araclar\geri_al_zamanlayici.ps1 ' + $arg).TrimEnd()
}

# 6 alanli DURUM tablo satiri (alanlarda '|' olmamali)
function Durum([string]$adim, [string]$durum, [string]$kanit, [string]$geri, [string]$siradaki) {
    if ($DurumSatiriYok.IsPresent) { return }
    $s = '| {0} | {1} | {2} | {3} | {4} | {5} |' -f (Get-Date -Format 'HH:mm'), $adim, $durum, $kanit, $geri, $siradaki
    Write-Host ($s -replace '\|\s*\|', '| - |')
}

function GunlukYaz([string]$m) {
    try {
        if (Test-Path -LiteralPath $VeriKlasoru) {
            $satir = '{0} | {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
            Add-Content -LiteralPath (Join-Path $VeriKlasoru 'geri_al.log') -Value $satir -Encoding UTF8
        }
    } catch { }
}

# ---------------------------------------------------------------- IPTAL
if ($Iptal.IsPresent) {
    if (-not $DryRun.IsPresent -and -not (Test-DgYonetici)) {
        Write-Host 'HATA: Yonetici olarak calistirilmali. Baslat menusunde PowerShell''e sag tikla, "Yonetici olarak calistir" sec, sonra bu komutu tekrarla.'
        exit 2
    }
    $var = Get-ScheduledTask -TaskName $GorevAdi -ErrorAction SilentlyContinue
    if (-not $var) {
        Yaz 'Bekleyen geri alma gorevi yok; iptal edilecek bir sey yok.'
        Durum 'geri_al_zamanlayici -Iptal' 'bitti' 'bekleyen gorev yoktu' 'gerek yok' 'sonraki adima gec'
        exit 0
    }
    Yaz ("Gorev '{0}' kaldirilacak (duvar ayarina dokunulmaz, yeni ayar kalir)." -f $GorevAdi)
    if ($DryRun.IsPresent) {
        Durum 'geri_al_zamanlayici -Iptal DryRun' 'bitti' 'DryRun: hicbir sey degismedi' 'gerek yok' ('kullanici kalsin derse: ' + (Komut '-Iptal'))
        exit 0
    }
    Unregister-ScheduledTask -TaskName $GorevAdi -Confirm:$false
    GunlukYaz 'Iptal: geri alma gorevi kaldirildi (yeni ayar kabul edildi).'
    Write-Host 'Tamam: geri alma gorevi kaldirildi. Yeni duvar ayari kalici.'
    $kalan = Get-ScheduledTask -TaskName $GorevAdi -ErrorAction SilentlyContinue
    $kanit = if ($kalan) { 'UYARI: gorev hala listede' } else { 'gorev kaldirildi (Get-ScheduledTask bulamadi)' }
    Durum 'geri_al_zamanlayici -Iptal' 'bitti' $kanit 'yeni ayari geri almak icin ilgili aracin -Geri -Uygula komutu (Pro: rdp_tailscale_kilit)' 'sonraki adima gec'
    exit 0
}

# ---------------------------------------------------------------- KURULUM
Yaz ("Plan: 1) duvar ayarini yedekle  2) {0} dk sonra yedegi geri yukleyen gizli gorev kur ('{1}')." -f $Dakika, $GorevAdi)
Yaz ("Dosyalar: {0}" -f $VeriKlasoru)

if (-not $gercek) {
    if (-not $DurumSatiriYok.IsPresent) { Yaz ('Hicbir sey degistirilmedi. Gercek is icin Yonetici PowerShell ac ve calistir: ' + (Komut ('-Dakika {0} -Uygula' -f $Dakika))) }
    Durum 'geri_al_zamanlayici DryRun' 'bitti' 'DryRun: hicbir sey degismedi' 'gerek yok' (Komut ('-Dakika {0} -Uygula' -f $Dakika))
    exit 0
}

if (-not (Test-DgYonetici)) {
    Write-Host 'HATA: Yonetici olarak calistirilmali. Baslat menusunde PowerShell''e sag tikla, "Yonetici olarak calistir" sec, sonra bu komutu tekrarla.'
    exit 2
}

try {
    # Zaten bekleyen gorev varsa yedegi ezme: yeni yedek degismis ayari saklar ve iyi yedek kaybolur.
    $eski = Get-ScheduledTask -TaskName $GorevAdi -ErrorAction SilentlyContinue
    if ($eski) {
        Write-Host ("HATA: Zaten bekleyen bir geri alma gorevi var ('{0}'). Yedegi ezmemek icin yenisi kurulmadi. Once: {1}  (ya da sure dolana kadar bekle)." -f $GorevAdi, (Komut '-Iptal'))
        exit 3
    }

    if (-not (Test-Path -LiteralPath $VeriKlasoru)) {
        New-Item -ItemType Directory -Path $VeriKlasoru -Force | Out-Null
    }
    # Klasoru yalniz SYSTEM + Administrators yazabilsin (gorev SYSTEM olarak calisacak).
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($sid in @('S-1-5-18', 'S-1-5-32-544')) {
        $kural = New-Object System.Security.AccessControl.FileSystemAccessRule(
            (New-Object System.Security.Principal.SecurityIdentifier($sid)),
            'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($kural)
    }
    Set-Acl -LiteralPath $VeriKlasoru -AclObject $acl

    $damga = Get-Date -Format 'yyyyMMdd_HHmmss'
    $yedek = Join-Path $VeriKlasoru ("duvar_yedek_{0}.wfw" -f $damga)
    $geriYukle = Join-Path $VeriKlasoru 'geri_yukle.ps1'

    & netsh advfirewall export $yedek | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $yedek)) {
        Write-Host 'HATA: Duvar yedegi alinamadi; gorev kurulmadi, hicbir sey degismedi.'
        exit 4
    }
    Yaz ("Yedek alindi: {0}" -f $yedek)

    $govde = @(
        '$ErrorActionPreference = ''Continue''',
        ('$log = ''{0}''' -f (Join-Path $VeriKlasoru 'geri_al.log')),
        ('& netsh advfirewall import ''{0}''' -f $yedek),
        ('$kod = $LASTEXITCODE'),
        ('Add-Content -LiteralPath $log -Value ((Get-Date -Format ''yyyy-MM-dd HH:mm:ss'') + '' | geri yukleme calisti, netsh cikis kodu '' + $kod) -Encoding UTF8'),
        ('Unregister-ScheduledTask -TaskName ''{0}'' -Confirm:$false' -f $GorevAdi)
    )
    Set-Content -LiteralPath $geriYukle -Value $govde -Encoding UTF8

    $eylem = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $geriYukle)
    $tetik = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes($Dakika))
    $kimlik = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $ayar = New-ScheduledTaskSettingsSet -Hidden -StartWhenAvailable -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
    Register-ScheduledTask -TaskName $GorevAdi -Action $eylem -Trigger $tetik -Principal $kimlik -Settings $ayar | Out-Null

    $kontrol = Get-ScheduledTask -TaskName $GorevAdi -ErrorAction SilentlyContinue
    if (-not $kontrol) {
        Write-Host 'HATA: Gorev kurulamadi (kayit sonrasi bulunamadi). Duvar ayarini DEGISTIRME; hata metnini ajanina goster.'
        exit 1
    }

    $saat = (Get-Date).AddMinutes($Dakika).ToString('HH:mm')
    GunlukYaz ("Kuruldu: {0} dk sonra ({1}) geri yukleme, yedek {2}" -f $Dakika, $saat, $yedek)
    Write-Host ("Tamam: guvenlik agi kuruldu. Hicbir sey yapmazsan saat {0} civarinda duvar ayari yedege doner." -f $saat)
    if (-not $DurumSatiriYok.IsPresent) { Write-Host ('Yeni yolu ikinci cihazdan dogruladiktan ve kullanici "kalsin" dedikten sonra kalici yapmak icin: ' + (Komut '-Iptal')) }
    Durum 'geri_al_zamanlayici -Uygula' 'yarim' ("gorev '{0}' kuruldu, yedek {1}" -f $GorevAdi, $yedek) ("otomatik: {0} civarinda duvar yedege doner" -f $saat) ('ikinci cihazdan dogrula, kalsin denince ' + (Komut '-Iptal'))
    exit 0
}
catch {
    Write-Host ("HATA: {0}" -f $_.Exception.Message)
    exit 1
}
