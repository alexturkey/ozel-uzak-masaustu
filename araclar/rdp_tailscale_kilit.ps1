<#
.SYNOPSIS
  Pro dali: Uzak Masaustu (RDP, 3389) kapisini yalniz Tailscale arayuzune ve 100.64.0.0/10 adreslerine acar.

.DESCRIPTION
  Sira: (1) once geri_al_zamanlayici.ps1 ile guvenlik agi kurulur (N dk sonra duvar kendini eski haline dondurur);
        (2) "RDP yalniz Tailscale" kurali EKLENIR; (3) 3389 icin acik olan oteki giris izin kurallari kapatilir.
  Varsayilan DRYRUN: ne yapacagini yazar, hicbir sey degistirmez. Gercek is icin -Uygula (Yonetici PowerShell).
  -Geri : bu betigin eklediklerini geri alir (kendi kuralini siler, kapattigi kurallari yeniden acar, bekleyen geri alma gorevini de kaldirir).
  Windows Home bu betige uygun DEGIL (Home, Uzak Masaustu sunucusu olamaz); betik Home'u taniyip durur.
  Betik Uzak Masaustu ayarini acmaz/kapatmaz: Ayarlar > Sistem > Uzak Masaustu'nden acik olmali.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\rdp_tailscale_kilit.ps1                      # ne yapacagini yazar
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\rdp_tailscale_kilit.ps1 -Dakika 10 -Uygula   # guvenlik agi + kilit (Yonetici PowerShell)
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\rdp_tailscale_kilit.ps1 -Geri -Uygula        # kilidi geri al (Yonetici PowerShell)

.NOTES
  Cikis kodlari: 0 tamam, 1 beklenmeyen hata, 2 yonetici degil, 5 Windows Home, 6 Tailscale arayuzu yok,
  7 guvenlik agi (geri_al_zamanlayici) kurulamadi, 8 -Geri: kural geri alindi ama bekleyen geri alma gorevi kaldirilamadi.
  Sonda 6 alanli DURUM satiri basar: | saat | adim | bitti/yarim | kanit | geri alma | siradaki |
  Duvar kurallari toplanir (bir izin kurali yeter): yerlesik 3389 izinleri kapatilmazsa dar kural bir sey kisitlamaz.
  Ayrica: parametresiz Disable-NetFirewallRule TUM kurallari kapatir; bu betik yalnizca -Name ile adlandirilmis kurallari kapatir.
#>
[CmdletBinding()]
param(
    [ValidateRange(2, 120)][int]$Dakika = 10,
    [switch]$Uygula,
    [switch]$DryRun,
    [switch]$Geri,
    [string]$ArayuzAdi = 'Tailscale',
    [string]$KuralAdi = 'RDP yalniz Tailscale',
    [string]$TailscaleAraligi = '100.64.0.0/10',
    [string]$GeriAlYolu = '',
    [string]$VeriKlasoru = (Join-Path $env:ProgramData 'dogrudan-uzak-masaustu')
)

$ErrorActionPreference = 'Stop'
$gercek = ($Uygula.IsPresent -and -not $DryRun.IsPresent)
$onEk = if ($gercek) { '' } else { '[DRYRUN] ' }
$listeDosyasi = Join-Path $VeriKlasoru 'kapatilan_kurallar.txt'
if (-not $GeriAlYolu) { $GeriAlYolu = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'geri_al_zamanlayici.ps1' }

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

# 6 alanli DURUM tablo satiri (alanlarda '|' olmamali)
function Durum([string]$adim, [string]$durum, [string]$kanit, [string]$geri, [string]$siradaki) {
    $s = '| {0} | {1} | {2} | {3} | {4} | {5} |' -f (Get-Date -Format 'HH:mm'), $adim, $durum, $kanit, $geri, $siradaki
    Write-Host ($s -replace '\|\s*\|', '| - |')
}

if ($gercek -and -not (Test-DgYonetici)) {
    Write-Host 'HATA: Yonetici olarak calistirilmali. Baslat menusunde PowerShell''e sag tikla, "Yonetici olarak calistir" sec, sonra bu komutu tekrarla.'
    exit 2
}

try {
    # ------------------------------------------------------------ GERI AL
    if ($Geri.IsPresent) {
        Yaz ("Geri alinacak: '{0}' kurali silinecek; onceden kapatilan kurallar (varsa) yeniden acilacak." -f $KuralAdi)
        $adlar = @()
        if (Test-Path -LiteralPath $listeDosyasi) {
            $adlar = @(Get-Content -LiteralPath $listeDosyasi | Where-Object { $_ -and $_.Trim() })
        }
        if ($adlar.Count -gt 0) { Yaz ("Yeniden acilacak kurallar: {0}" -f ($adlar -join ', ')) } else { Yaz 'Yeniden acilacak kural kaydi yok.' }
        if (-not $gercek) {
            Yaz 'Bekleyen geri alma gorevi de kaldirilacak; onun DryRun ozeti:'
            & $GeriAlYolu -Iptal -DryRun -DurumSatiriYok
            Yaz ('Hicbir sey degistirilmedi. Gercek is icin Yonetici PowerShell ac ve calistir: ' + (Komut 'rdp_tailscale_kilit' '-Geri -Uygula'))
            Durum 'rdp_tailscale_kilit -Geri DryRun' 'bitti' 'DryRun: hicbir sey degismedi' 'gerek yok' (Komut 'rdp_tailscale_kilit' '-Geri -Uygula')
            exit 0
        }
        if ($adlar.Count -gt 0) { Enable-NetFirewallRule -Name $adlar }
        if (Get-NetFirewallRule -DisplayName $KuralAdi -ErrorAction SilentlyContinue) { Remove-NetFirewallRule -DisplayName $KuralAdi }
        & $GeriAlYolu -Iptal -DurumSatiriYok
        if ($LASTEXITCODE -ne 0) {
            Write-Host ("UYARI: Kilit geri alindi ama bekleyen geri alma gorevi kaldirilamadi (kod {0}). Elle: {1}" -f $LASTEXITCODE, (Komut 'geri_al_zamanlayici' '-Iptal'))
            exit 8
        }
        Write-Host 'Tamam: kilit geri alindi.'
        Durum 'rdp_tailscale_kilit -Geri' 'bitti' ("kural '{0}' silindi, {1} kural yeniden acildi, geri alma gorevi kaldirildi" -f $KuralAdi, $adlar.Count) 'gerek yok' 'sonraki adima gec ya da kilidi yeniden uygula'
        exit 0
    }

    # ------------------------------------------------------------ ON KONTROL
    $sku = [int](Get-CimInstance -ClassName Win32_OperatingSystem).OperatingSystemSKU
    # Home surumleri: PRODUCT_CORE_N 98, COUNTRYSPECIFIC 99, SINGLELANGUAGE 100, CORE 101 (Microsoft GetProductInfo belgesi)
    if ($sku -ge 98 -and $sku -le 101) {
        Write-Host 'DUR: Bu bilgisayar Windows Home. Home surumu Uzak Masaustu sunucusu olamaz (Microsoft belgesi). Bu betik Pro icindir; REHBER''deki Home (RustDesk) dalina gec.'
        exit 5
    }

    $arayuz = Get-NetAdapter -Name $ArayuzAdi -ErrorAction SilentlyContinue
    if (-not $arayuz) {
        Write-Host ("DUR: '{0}' adli ag arayuzu yok. Once Tailscale'i kur ve giris yap (REHBER adim 1); arayuz adi farkliysa -ArayuzAdi ile ver (Get-NetAdapter listeler)." -f $ArayuzAdi)
        exit 6
    }
    if ("$($arayuz.Status)" -ne 'Up') {
        Yaz ("UYARI: '{0}' arayuzunun durumu 'Up' degil ({1}). Tailscale baglanmadan kilit ise yaramaz." -f $ArayuzAdi, $arayuz.Status)
    }

    # 3389 icin su an ACIK giris izin kurallari (kendi kuralimiz haric)
    $bulunan = @(Get-NetFirewallPortFilter | Where-Object { @($_.LocalPort) -contains '3389' } | Get-NetFirewallRule |
        Where-Object { "$($_.Enabled)" -eq 'True' -and "$($_.Direction)" -eq 'Inbound' -and "$($_.Action)" -eq 'Allow' -and $_.DisplayName -ne $KuralAdi })
    $kapatilacak = @($bulunan | ForEach-Object { $_.Name } | Where-Object { $_ })

    Yaz ("Windows: Pro/uygun surum (SKU {0}). Arayuz '{1}' bulundu." -f $sku, $ArayuzAdi)
    Yaz ("Eklenecek kural: '{0}'  TCP 3389 giris, arayuz '{1}', yalniz {2}, profil Any." -f $KuralAdi, $ArayuzAdi, $TailscaleAraligi)
    if ($kapatilacak.Count -gt 0) {
        Yaz ("Kapatilacak ({0}) kural (3389 icin acik giris izinleri): {1}" -f $kapatilacak.Count, ($kapatilacak -join ' | '))
    } else {
        Yaz 'Kapatilacak baska 3389 izin kurali bulunamadi.'
    }

    # ------------------------------------------------------------ 1. GUVENLIK AGI
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

    # ------------------------------------------------------------ 2-3. KURAL EKLE, ESKILERI KAPAT
    if (-not $gercek) {
        $k = Komut 'rdp_tailscale_kilit' ('-Dakika {0} -Uygula' -f $Dakika)
        Yaz ('Hicbir sey degistirilmedi. Gercek is icin Yonetici PowerShell ac ve calistir: ' + $k)
        Durum 'rdp_tailscale_kilit DryRun' 'bitti' ("DryRun: hicbir sey degismedi; kapatilacak {0} kural" -f $kapatilacak.Count) 'gerek yok' $k
        exit 0
    }

    if (Get-NetFirewallRule -DisplayName $KuralAdi -ErrorAction SilentlyContinue) {
        Remove-NetFirewallRule -DisplayName $KuralAdi
    }
    New-NetFirewallRule -DisplayName $KuralAdi -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow `
        -Profile Any -InterfaceAlias $ArayuzAdi -RemoteAddress $TailscaleAraligi | Out-Null

    if ($kapatilacak.Count -gt 0) {
        if (-not (Test-Path -LiteralPath $VeriKlasoru)) { New-Item -ItemType Directory -Path $VeriKlasoru -Force | Out-Null }
        Set-Content -LiteralPath $listeDosyasi -Value $kapatilacak -Encoding UTF8   # satir basina bir kural adi
        Disable-NetFirewallRule -Name $kapatilacak   # asla parametresiz: parametresiz cagri TUM kurallari kapatir
    }

    Write-Host ''
    Write-Host 'Tamam: kilit kuruldu. SIMDI KANIT (ikinci cihazdan, Tailscale baglantisiyla):'
    Write-Host '  1) Ikinci cihazda (B) Uzak Masaustu ile hedefin Tailscale adresine (100.x...) baglan: baglanmali.'
    Write-Host '  2) Ayni ev agindaki BASKA bir cihazdan hedefin yerel IP''sine (ipconfig ile bul) baglanmayi dene: baglanMAMALI. Boyle bir cihaz yoksa bu kontrolu atla ve DURUM''a yaz.'
    Write-Host ("  3) Ikisi de dogruysa ve kullanici 'kalsin' dediyse kalici yap: {0}   (yapmazsan {1} dk sonra her sey eski haline doner)" -f (Komut 'geri_al_zamanlayici' '-Iptal'), $Dakika)
    Write-Host ('  Ters yon (kilidi kaldirmak): ' + (Komut 'rdp_tailscale_kilit' '-Geri -Uygula'))
    $saat = (Get-Date).AddMinutes($Dakika).ToString('HH:mm')
    Durum 'rdp_tailscale_kilit -Uygula' 'yarim' ("kural '{0}' eklendi, {1} kural kapatildi; dogrulama bekliyor" -f $KuralAdi, $kapatilacak.Count) ("otomatik: {0} civarinda duvar yedege doner; hemen: {1}" -f $saat, (Komut 'rdp_tailscale_kilit' '-Geri -Uygula')) ('ikinci cihazdan dogrula, kalsin denince ' + (Komut 'geri_al_zamanlayici' '-Iptal'))
    exit 0
}
catch {
    Write-Host ("HATA: {0}" -f $_.Exception.Message)
    Write-Host 'Duvar ayari yarim kalmis olabilir; geri alma gorevi kurulduysa sure dolunca eski haline doner (geri_al_zamanlayici -Iptal ile iptal ETME).'
    exit 1
}
