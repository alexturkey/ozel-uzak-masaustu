<#
.SYNOPSIS
  Ön kontrol (adım 0): bu bilgisayarda Uzak Masaüstü yolu hangisi, Tailscale/RustDesk kurulu mu, ağ nasıl?
.DESCRIPTION
  YALNIZ OKUR. Hiçbir şeyi değiştirmez, kurmaz, indirmez. Tek ağ işi: Tailscale kuruluysa
  `tailscale netcheck` çalıştırır (kendi komutu; ağ koşullarını ölçer).
  Çıktı Türkçe, her satır [TAMAM] / [UYARI] / [YOK] / [BILGI] ile başlar; sonda tek "DURUM satırı" verilir.
  Günlük: %LOCALAPPDATA%\dogrudan-uzak-masaustu\kontrol.log
.PARAMETER ModemWanIp
  İsteğe bağlı. Modemin yönetim sayfasında gördüğün "WAN IP" (internet tarafı adres).
  Verirsen betik, internette görünen adresle karşılaştırıp CGNAT (operatörün adres paylaşımı) ipucu verir.
.PARAMETER SadeceIslevler
  Test için: işlevleri tanımlar, bir şey çalıştırmaz.
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File kontrol.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File kontrol.ps1 -ModemWanIp 100.72.4.9
#>
param(
    [string]$ModemWanIp = '',
    [switch]$SadeceIslevler
)

$script:LogDizin = Join-Path $env:LOCALAPPDATA 'dogrudan-uzak-masaustu'
$script:Cikti = New-Object System.Collections.ArrayList

function Yaz-Satir {
    param([string]$Metin)
    [void]$script:Cikti.Add($Metin)
    Write-Host $Metin
    try {
        if (-not (Test-Path $script:LogDizin)) { New-Item -ItemType Directory -Path $script:LogDizin -Force | Out-Null }
        Add-Content -Path (Join-Path $script:LogDizin 'kontrol.log') -Value ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Metin) -Encoding UTF8
    } catch { }
}

# ---- Okuyucular (testte gölgelenir) ----
function Oku-EditionID {
    try { (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop).EditionID } catch { '' }
}
function Oku-SurumAdi {
    try { (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption } catch { '' }
}
function Oku-Servis {
    param([string]$Ad)
    try {
        $s = Get-Service -Name $Ad -ErrorAction Stop
        [pscustomobject]@{ Var = $true; Durum = [string]$s.Status; Baslangic = [string]$s.StartType }
    } catch {
        [pscustomobject]@{ Var = $false; Durum = ''; Baslangic = '' }
    }
}
function Oku-UykuCikti {
    # Dil bağımsız: yalnız 0x........ sayıları okunur (Türkçe Windows'ta metinler Türkçe çıkar).
    try { (powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE) 2>$null } catch { @() }
}
function Bul-Tailscale {
    $c = Get-Command tailscale -ErrorAction SilentlyContinue
    if ($c) { return 'tailscale' }
    $yol = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    if (Test-Path $yol) { return $yol }
    return $null
}
function Calistir-Tailscale {
    param([string[]]$Arg)
    $b = Bul-Tailscale
    if (-not $b) { return $null }
    $ham = & $b @Arg 2>&1
    return @($ham | ForEach-Object { [string]$_ })
}
function Bul-RustDeskDosya {
    $yol = Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'
    return (Test-Path $yol)
}

# ---- Çözümleyiciler ----
function Cozumle-Surum {
    param([string]$Edition)
    # Microsoft: Pro, Enterprise, Education ve Server sürümleri uzak masaüstü sunucusu olabilir; Home olamaz.
    # EditionID adları (Core, Professional...) Windows'un kendi kayıt defteri değeridir (belge değil, gözlem).
    if ($Edition -match '^Core') { return 'Home' }
    if ($Edition -match '^(Professional|Enterprise|Education|Server)') { return 'Pro' }
    return 'Bilinmiyor'
}
function Cozumle-Uyku {
    param([string[]]$Satirlar)
    $hex = @()
    foreach ($s in $Satirlar) {
        foreach ($m in [regex]::Matches([string]$s, '0x[0-9a-fA-F]{8}')) { $hex += $m.Value }
    }
    if ($hex.Count -lt 2) { return $null }
    $ac = [Convert]::ToInt64($hex[$hex.Count - 2].Substring(2), 16)
    $dc = [Convert]::ToInt64($hex[$hex.Count - 1].Substring(2), 16)
    return [pscustomobject]@{ PrizSaniye = $ac; PilSaniye = $dc }
}
function Cozumle-Netcheck {
    param([string[]]$Satirlar)
    $r = @{}
    foreach ($s in $Satirlar) {
        if ([string]$s -match '^\s*\*?\s*(UDP|IPv4|IPv6|MappingVariesByDestIP|HairPinning|PortMapping|Nearest DERP)\s*:\s*(.*)$') {
            $r[$Matches[1]] = $Matches[2].Trim()
        }
    }
    return $r
}
function Test-CgnatAraligi {
    param([string]$Ip)
    if ($Ip -notmatch '^(\d{1,3})\.(\d{1,3})\.\d{1,3}\.\d{1,3}$') { return $false }
    $a = [int]$Matches[1]; $b = [int]$Matches[2]
    return ($a -eq 100 -and $b -ge 64 -and $b -le 127)
}
function Al-IpAdresi {
    param([string]$Metin)
    if ($Metin -match '(\d{1,3}(?:\.\d{1,3}){3})') { return $Matches[1] }
    return ''
}

function Kontrol-Calistir {
    param([string]$ModemWanIp = '')
    $durumOzet = New-Object System.Collections.ArrayList
    Yaz-Satir '=== 0. ÖN KONTROL (yalnız okur, hiçbir şeyi değiştirmez) ==='

    # 1) Windows sürümü
    $ed = Oku-EditionID
    $ad = Oku-SurumAdi
    $tur = Cozumle-Surum -Edition $ed
    if ($tur -eq 'Pro') {
        Yaz-Satir ("[TAMAM] Windows: {0} (EditionID: {1}). Bu sürüm Uzak Masaüstü sunucusu olabilir -> Yol 3a (yerleşik Uzak Masaüstü, yalnız Tailscale üzerinden)." -f $ad, $ed)
    } elseif ($tur -eq 'Home') {
        Yaz-Satir ("[UYARI] Windows: {0} (EditionID: {1}). Home sürümü Uzak Masaüstü sunucusu OLAMAZ -> Yol 3b (RustDesk)." -f $ad, $ed)
    } else {
        Yaz-Satir ("[UYARI] Windows sürümü anlaşılamadı (EditionID: '{0}'). Ajan: 'winver' çıktısını kullanıcıya göster, Home mu Pro mu sor." -f $ed)
    }
    [void]$durumOzet.Add("Windows=$tur")

    # 2) Uyku
    $uyku = Cozumle-Uyku -Satirlar (Oku-UykuCikti)
    if ($null -eq $uyku) {
        Yaz-Satir '[BILGI] Uyku süresi okunamadı. Ayarlar > Sistem > Güç bölümünden "uyku"yu "hiçbir zaman" yap (uzaktaki bilgisayar uyursa bağlanılamaz).'
        [void]$durumOzet.Add('uyku=okunamadi')
    } elseif ($uyku.PrizSaniye -eq 0) {
        Yaz-Satir '[TAMAM] Uyku (prizde): hiçbir zaman. Uzak bilgisayar kendiliğinden uyumaz.'
        [void]$durumOzet.Add('uyku=kapali')
    } else {
        Yaz-Satir ("[UYARI] Uyku (prizde): {0} saniye sonra uyuyor. Uzaktan bağlanılacak bilgisayarda 'hiçbir zaman' yapılmalı (Ayarlar > Sistem > Güç)." -f $uyku.PrizSaniye)
        [void]$durumOzet.Add("uyku=$($uyku.PrizSaniye)sn")
    }

    # 3) Tailscale
    $tsExe = Bul-Tailscale
    $tsHizmet = Oku-Servis -Ad 'Tailscale'
    if ($tsExe) {
        $hz = if ($tsHizmet.Var) { "hizmet {0}/{1}" -f $tsHizmet.Durum, $tsHizmet.Baslangic } else { 'hizmet bulunamadı' }
        Yaz-Satir ("[TAMAM] Tailscale kurulu ({0})." -f $hz)
        [void]$durumOzet.Add('tailscale=kurulu')
    } else {
        Yaz-Satir '[YOK] Tailscale kurulu değil -> Adım 1 (kurulum).'
        [void]$durumOzet.Add('tailscale=yok')
    }

    # 3b) Tailscale kurulumunun istedigi 4 Windows hizmeti (yalniz okur; kaynak: tailscale.com/docs/reference/troubleshooting/windows/windows-install-error)
    $gerekli = @('Dnscache', 'iphlpsvc', 'netprofm', 'WinHttpAutoProxySvc')
    $calismayan = New-Object System.Collections.ArrayList
    foreach ($ad4 in $gerekli) {
        $h = Oku-Servis -Ad $ad4
        if (-not ($h.Var -and $h.Durum -eq 'Running')) { [void]$calismayan.Add(("{0} ({1})" -f $ad4, $(if ($h.Var) { $h.Durum } else { 'bulunamadi' }))) }
    }
    if ($calismayan.Count -eq 0) {
        Yaz-Satir '[TAMAM] Tailscale kurulumunun istedigi 4 Windows hizmeti calisiyor (Dnscache, iphlpsvc, netprofm, WinHttpAutoProxySvc).'
        [void]$durumOzet.Add('hizmetler4=tamam')
    } else {
        Yaz-Satir ("[UYARI] Tailscale kurulumu su Windows hizmetlerinin calismasini ister, calismayan: {0}. Belgeye gore bu hizmetler calismiyorsa kurulum kendiliginden basarisiz olur. Betik hizmetleri BASLATMAZ, duzeltmez. Ajan: bunu kullaniciya goster, hizmeti baslatmadan once sor. Kaynak: https://tailscale.com/docs/reference/troubleshooting/windows/windows-install-error" -f ($calismayan -join ', '))
        [void]$durumOzet.Add('hizmetler4=eksik')
    }

    # 4) RustDesk
    $rdHizmet = Oku-Servis -Ad 'RustDesk'
    $rdDosya = Bul-RustDeskDosya
    if ($rdHizmet.Var -or $rdDosya) {
        $hz = if ($rdHizmet.Var) { "hizmet {0}/{1}" -f $rdHizmet.Durum, $rdHizmet.Baslangic } else { 'hizmet yok (taşınabilir sürüm olabilir; UAC ekranı için kurulu sürüm gerekir)' }
        Yaz-Satir ("[TAMAM] RustDesk bulundu ({0})." -f $hz)
        [void]$durumOzet.Add('rustdesk=var')
    } else {
        $not = if ($tur -eq 'Home') { 'Home için gerekecek (Yol 3b).' } else { 'Pro için gerekmez (Yol 3a).' }
        Yaz-Satir ("[YOK] RustDesk kurulu değil. {0}" -f $not)
        [void]$durumOzet.Add('rustdesk=yok')
    }

    # 5) Ağ (netcheck)
    $genelIp = ''
    if ($tsExe) {
        $nc = Calistir-Tailscale -Arg @('netcheck')
        $r = Cozumle-Netcheck -Satirlar $nc
        if ($r.Count -eq 0) {
            Yaz-Satir '[BILGI] tailscale netcheck çıktısı okunamadı; ham çıktı günlüğe yazıldı. Ajan: çıktıyı kullanıcıya göster.'
            foreach ($s in $nc) { Yaz-Satir ("        " + $s) }
            [void]$durumOzet.Add('netcheck=okunamadi')
        } else {
            if ($r.ContainsKey('UDP')) {
                if ($r['UDP'] -match '^true') { Yaz-Satir '[TAMAM] netcheck UDP: true (giden UDP paketleri ulaşıyor; doğrudan bağlantı için gerekli).' }
                else { Yaz-Satir ("[UYARI] netcheck UDP: {0}. Bu ağ UDP'yi engelliyor olabilir; bağlantı büyük olasılıkla röleden (aracı) gider." -f $r['UDP']) }
            }
            if ($r.ContainsKey('IPv4')) {
                $genelIp = Al-IpAdresi -Metin $r['IPv4']
                Yaz-Satir ("[BILGI] İnternette görünen adres (netcheck IPv4): {0}" -f $r['IPv4'])
            }
            if ($r.ContainsKey('MappingVariesByDestIP')) {
                if ($r['MappingVariesByDestIP'] -match '^true') {
                    Yaz-Satir '[UYARI] MappingVariesByDestIP: true -> zor NAT (modem her hedefe başka port veriyor); doğrudan bağlantı zor olur, röle olası.'
                } elseif ($r['MappingVariesByDestIP'] -match '^false') {
                    Yaz-Satir '[TAMAM] MappingVariesByDestIP: false -> kolay NAT veya NAT yok; doğrudan bağlantı olası.'
                }
            }
            if ($r.ContainsKey('PortMapping')) { Yaz-Satir ("[BILGI] PortMapping: {0}" -f $r['PortMapping']) }
            if ($r.ContainsKey('Nearest DERP')) { Yaz-Satir ("[BILGI] En yakın röle (DERP): {0}" -f $r['Nearest DERP']) }
            [void]$durumOzet.Add("netcheck=UDP:$($r['UDP']);zorNAT:$($r['MappingVariesByDestIP'])")
        }
    } else {
        Yaz-Satir '[BILGI] Tailscale yok, ağ ölçümü (netcheck) Adım 1 sonrası yapılır.'
    }

    # 6) CGNAT ipucu
    if ($ModemWanIp) {
        if (Test-CgnatAraligi -Ip $ModemWanIp) {
            Yaz-Satir ("[UYARI] Modem WAN IP'si {0}, 100.64.0.0/10 aralığında: operatör adres paylaşıyor (CGNAT). Modemde port açmak işe yaramaz; rehber zaten port açmıyor, Tailscale yolu uygundur." -f $ModemWanIp)
            [void]$durumOzet.Add('cgnat=var')
        } elseif ($genelIp -and $genelIp -ne $ModemWanIp) {
            Yaz-Satir ("[UYARI] Modem WAN IP'si ({0}) internette görünen adresten ({1}) farklı: arada adres paylaşımı (CGNAT) olabilir. Bu bir ipucudur, kesin hüküm değil." -f $ModemWanIp, $genelIp)
            [void]$durumOzet.Add('cgnat=olasi')
        } elseif ($genelIp) {
            Yaz-Satir '[TAMAM] Modem WAN IP adresi internette görünen adresle aynı: CGNAT görünmüyor.'
            [void]$durumOzet.Add('cgnat=yok')
        } else {
            Yaz-Satir '[BILGI] Karşılaştırmak için internette görünen adres gerekli (Tailscale kurulunca netcheck verir).'
        }
    } else {
        Yaz-Satir '[BILGI] CGNAT ipucu için modem arayüzünden "WAN IP"yi oku, betiği -ModemWanIp <adres> ile tekrar çalıştır (isteğe bağlı).'
    }

    $saat = Get-Date -Format 'HH:mm'
    $satir = "| {0} | 0 on kontrol | bitti | {1} | yok (yalniz okur) | {2} |" -f $saat, ($durumOzet -join ', '), $(if ($tsExe) { '2 (dogrudan mi role mi)' } else { '1 (Tailscale kurulumu)' })
    Yaz-Satir ''
    Yaz-Satir 'DURUM satırı (DURUM.md dosyasına ekle):'
    Yaz-Satir $satir
    return $satir
}

if ($SadeceIslevler) { return }
$null = Kontrol-Calistir -ModemWanIp $ModemWanIp
exit 0
