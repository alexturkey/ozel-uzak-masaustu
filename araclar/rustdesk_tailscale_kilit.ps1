<#
.SYNOPSIS
  Home dali / umumi Wi-Fi: RustDesk'in dinledigi portlara (TCP 21118, UDP 21119) yalniz Tailscale adreslerinden ve bu bilgisayarin kendisinden (loopback) gelinsin.

.DESCRIPTION
  Tailscale disindan gelen girisi ENGEL kurali keser. Windows Guvenlik Duvari'nda acik engel kurali celisen izin kurallarini gecersiz kilar
  (Microsoft: "Explicit block rules take precedence over any conflicting allow rules."), bu yuzden RustDesk'in kendi (her adrese acik) izin kuralina dokunulmaz.
  Tailscale'den gelen baglanti (kaynak 100.64.0.0/10 ya da fd7a:115c:a1e0::/48) ve loopback engellenmez.
  Bu betik RustDesk'in 9 haneli ID / role yolunu KAPATMAZ (o yol giden baglantidir); orada koruma paroladir.
  Sira: (1) geri_al_zamanlayici.ps1 ile guvenlik agi, (2) iki ENGEL kurali (TCP 21118, UDP 21119), (3) kurallari dogrula.
  Varsayilan DRYRUN: hicbir sey degistirmez. Gercek is icin -Uygula (Yonetici PowerShell).
  -Geri : bu betigin kurallarini siler ve bekleyen geri alma gorevini de kaldirir.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\rustdesk_tailscale_kilit.ps1                      # ne yapacagini yazar
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\rustdesk_tailscale_kilit.ps1 -Dakika 10 -Uygula   # guvenlik agi + engel (Yonetici PowerShell)
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\rustdesk_tailscale_kilit.ps1 -Geri -Uygula        # geri al (Yonetici PowerShell)

.NOTES
  Cikis kodlari: 0 tamam, 1 beklenmeyen hata, 2 yonetici degil, 7 guvenlik agi kurulamadi, 8 -Geri: kural silindi ama bekleyen geri alma gorevi kaldirilamadi.
  Sonda 6 alanli DURUM satiri basar: | saat | adim | bitti/yarim | kanit | geri alma | siradaki |
  Sinanmadi (TEST_PLANI): ayni Wi-Fi'daki ikinci cihazdan 21118'e baglanamamali; iPhone Tailscale yolu calismali; 21119/UDP'nin ne ise yaradigi belgede yok.
#>
[CmdletBinding()]
param(
    [ValidateRange(2, 120)][int]$Dakika = 10,
    [switch]$Uygula,
    [switch]$DryRun,
    [switch]$Geri,
    [string]$GeriAlYolu = ''
)

$ErrorActionPreference = 'Stop'
$gercek = ($Uygula.IsPresent -and -not $DryRun.IsPresent)
$onEk = if ($gercek) { '' } else { '[DRYRUN] ' }
if (-not $GeriAlYolu) { $GeriAlYolu = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'geri_al_zamanlayici.ps1' }
$ad = 'RustDesk yalniz Tailscale (engel)'
# 100.64.0.0/10 ve fd7a:115c:a1e0::/48 disindaki her adres; 127.0.0.0/8 ve ::1 (loopback) disarida birakildi
$v4 = @('0.0.0.0-100.63.255.255', '100.128.0.0-126.255.255.255', '128.0.0.0-255.255.255.255')
$v6 = @('::2-fd7a:115c:a1df:ffff:ffff:ffff:ffff:ffff', 'fd7a:115c:a1e1::-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff')
$kurallar = @(
    @{ Ek = 'TCP 21118'; Protocol = 'TCP'; Port = 21118 },
    @{ Ek = 'UDP 21119'; Protocol = 'UDP'; Port = 21119 }
)

if (-not (Get-Command Test-DgYonetici -ErrorAction SilentlyContinue)) {
    function Test-DgYonetici {
        $kimlik = [Security.Principal.WindowsIdentity]::GetCurrent()
        $rol = New-Object Security.Principal.WindowsPrincipal($kimlik)
        return $rol.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
}
function Yaz([string]$m) { Write-Host ($onEk + $m) }
function Komut([string]$betik, [string]$arg) {
    return ('powershell -NoProfile -ExecutionPolicy Bypass -File araclar\{0}.ps1 {1}' -f $betik, $arg).TrimEnd()
}
function Durum([string]$adim, [string]$durum, [string]$kanit, [string]$geri, [string]$siradaki) {
    $s = '| {0} | {1} | {2} | {3} | {4} | {5} |' -f (Get-Date -Format 'HH:mm'), $adim, $durum, $kanit, $geri, $siradaki
    Write-Host ($s -replace '\|\s*\|', '| - |')
}

if ($gercek -or ($Geri -and -not $DryRun.IsPresent -and $Uygula.IsPresent)) {
    if (-not (Test-DgYonetici)) {
        Write-Host 'HATA: Yonetici olarak calistirilmali. Baslat menusunde PowerShell''e sag tikla, "Yonetici olarak calistir" sec, sonra bu komutu tekrarla.'
        exit 2
    }
}

try {
    if ($Geri) {
        if (-not $gercek) {
            Yaz ("'{0}' kurallari silinecek ve bekleyen geri alma gorevi kaldirilacak." -f $ad)
            $k = Komut 'rustdesk_tailscale_kilit' '-Geri -Uygula'
            Yaz ('Hicbir sey degistirilmedi. Gercek is icin Yonetici PowerShell: ' + $k)
            Durum 'rustdesk_tailscale_kilit -Geri DryRun' 'bitti' 'DryRun: hicbir sey degismedi' 'gerek yok' $k
            exit 0
        }
        Get-NetFirewallRule -DisplayName "$ad*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        $kalan = @(Get-NetFirewallRule -DisplayName "$ad*" -ErrorAction SilentlyContinue)
        if ($kalan.Count -gt 0) {
            Write-Host ("HATA: {0} kural silinemedi." -f $kalan.Count)
            exit 1
        }
        & $GeriAlYolu -Iptal -DurumSatiriYok
        if ($LASTEXITCODE -ne 0) {
            Write-Host ("UYARI: Kurallar silindi ama bekleyen geri alma gorevi kaldirilamadi (kod {0}). Elle: {1}" -f $LASTEXITCODE, (Komut 'geri_al_zamanlayici' '-Iptal'))
            exit 8
        }
        Write-Host 'Tamam: engel kurallari geri alindi.'
        Durum 'rustdesk_tailscale_kilit -Geri' 'bitti' 'engel kurallari silindi, geri alma gorevi kaldirildi' (Komut 'rustdesk_tailscale_kilit' '-Uygula') 'gerek yok'
        exit 0
    }

    # ---------------------------------------------------------------- 1. GUVENLIK AGI
    if ($gercek) {
        & $GeriAlYolu -Dakika $Dakika -Uygula -DurumSatiriYok
        if ($LASTEXITCODE -ne 0) {
            Write-Host ("DUR: Guvenlik agi (geri_al_zamanlayici) kurulamadi (kod {0}); duvara DOKUNULMADI. Ustteki hata metnini oku." -f $LASTEXITCODE)
            exit 7
        }
    } else {
        Yaz 'Once guvenlik agi kurulacak (geri_al_zamanlayici.ps1 -Uygula); asagidaki bolum onun DryRun ozeti:'
        & $GeriAlYolu -Dakika $Dakika -DurumSatiriYok
    }

    # ---------------------------------------------------------------- 2. ENGEL KURALLARI
    foreach ($k in $kurallar) {
        $tam = "$ad $($k.Ek)"
        if (-not $gercek) {
            Yaz ("Kurulacak: {0} | gelen | ENGEL | tum profiller | uzak: Tailscale ve loopback disi her adres" -f $tam)
            continue
        }
        Get-NetFirewallRule -DisplayName $tam -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        New-NetFirewallRule -DisplayName $tam -Direction Inbound -Action Block -Protocol $k.Protocol -LocalPort $k.Port `
            -RemoteAddress ($v4 + $v6) -Profile Any | Out-Null
        if (-not (Get-NetFirewallRule -DisplayName $tam -ErrorAction SilentlyContinue)) {
            throw ("Kural kurulamadi: {0}" -f $tam)
        }
        Yaz ("Kuruldu: {0}" -f $tam)
    }

    if (-not $gercek) {
        $c = Komut 'rustdesk_tailscale_kilit' ('-Dakika {0} -Uygula' -f $Dakika)
        Yaz ('Hicbir sey degistirilmedi. Gercek is icin Yonetici PowerShell ac ve calistir: ' + $c)
        Durum 'rustdesk_tailscale_kilit DryRun' 'bitti' 'DryRun: hicbir sey degismedi' 'gerek yok' $c
        exit 0
    }

    Write-Host ''
    Write-Host 'Tamam: engel kurallari kuruldu. SIMDI KANIT:'
    Write-Host '  1) Telefondan (Tailscale acik) RustDesk ile bu bilgisayarin Tailscale adresine (100.x...) baglan: baglanmali.'
    Write-Host '  2) Ayni Wi-Fi''daki BASKA bir cihazdan bu bilgisayarin yerel IP''sine :21118 ile baglanmayi dene: baglanMAMALI. Boyle bir cihaz yoksa atla ve DURUM''a yaz.'
    Write-Host ("  3) Ikisi de dogruysa ve kullanici 'kalsin' dediyse kalici yap: {0}   (yapmazsan {1} dk sonra her sey eski haline doner)" -f (Komut 'geri_al_zamanlayici' '-Iptal'), $Dakika)
    Write-Host ('  Ters yon: ' + (Komut 'rustdesk_tailscale_kilit' '-Geri -Uygula'))
    $saat = (Get-Date).AddMinutes($Dakika).ToString('HH:mm')
    Durum 'rustdesk_tailscale_kilit -Uygula' 'yarim' ("2 engel kurali kuruldu (TCP 21118, UDP 21119); dogrulama bekliyor") ("otomatik: {0} civarinda duvar yedege doner; hemen: {1}" -f $saat, (Komut 'rustdesk_tailscale_kilit' '-Geri -Uygula')) ('telefondan dogrula, kalsin denince ' + (Komut 'geri_al_zamanlayici' '-Iptal'))
    exit 0
}
catch {
    Write-Host ("HATA: {0}" -f $_.Exception.Message)
    Write-Host 'Duvar ayari yarim kalmis olabilir; geri alma gorevi kurulduysa sure dolunca eski haline doner (geri_al_zamanlayici -Iptal ile iptal ETME).'
    exit 1
}
