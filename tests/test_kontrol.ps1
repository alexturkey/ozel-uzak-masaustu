# kontrol.ps1 testi. Gerçek sistem, ağ ya da Tailscale ÇAĞRILMAZ; okuyucular sahte işlevle gölgelenir.
# Çalıştırma: powershell -NoProfile -ExecutionPolicy Bypass -File tests\test_kontrol.ps1   (çıkış 0 = geçti)
$ErrorActionPreference = 'Stop'
$betik = Join-Path $PSScriptRoot '..\araclar\kontrol.ps1'
$script:Gecen = 0
$script:Kalan = 0
function Dogrula {
    param([string]$Ad, [bool]$Kosul, [string]$Not = '')
    if ($Kosul) { $script:Gecen++; Write-Host "  GEÇTİ  $Ad" }
    else { $script:Kalan++; Write-Host "  KALDI  $Ad  $Not" -ForegroundColor Red }
}

# Günlük gerçek klasöre yazmasın
$gecici = Join-Path ([System.IO.Path]::GetTempPath()) ('kontrol_test_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $gecici -Force | Out-Null
$env:LOCALAPPDATA = $gecici

Write-Host '[1] Sözdizimi'
$hatalar = $null; $belirtec = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($betik, [ref]$belirtec, [ref]$hatalar)
Dogrula 'kontrol.ps1 ayrıştırılıyor, sözdizimi hatası yok' ($hatalar.Count -eq 0) (($hatalar | ForEach-Object { $_.Message }) -join '; ')
$bayt = [System.IO.File]::ReadAllBytes($betik)
Dogrula 'dosya UTF-8 BOM ile başlıyor' ($bayt[0] -eq 0xEF -and $bayt[1] -eq 0xBB -and $bayt[2] -eq 0xBF)

. $betik -SadeceIslevler

Write-Host '[2] Çözümleyiciler'
Dogrula 'Core -> Home' ((Cozumle-Surum -Edition 'Core') -eq 'Home')
Dogrula 'CoreSingleLanguage -> Home' ((Cozumle-Surum -Edition 'CoreSingleLanguage') -eq 'Home')
Dogrula 'Professional -> Pro' ((Cozumle-Surum -Edition 'Professional') -eq 'Pro')
Dogrula 'Enterprise -> Pro' ((Cozumle-Surum -Edition 'Enterprise') -eq 'Pro')
Dogrula 'Education -> Pro' ((Cozumle-Surum -Edition 'Education') -eq 'Pro')
Dogrula 'boş -> Bilinmiyor' ((Cozumle-Surum -Edition '') -eq 'Bilinmiyor')

$uykuOrnek = @(
    '  Güç Ayarı GUID''i: 29f6c1db-86da-48c5-9fdb-f2b67b1f44da  (Uykuya geç)',
    '    Olası Ayar Dizini En Az: 0x00000000',
    '    Olası Ayar Dizini En Fazla: 0xffffffff',
    '    Geçerli AC Güç Ayarı Dizini: 0x00000000',
    '    Geçerli DC Güç Ayarı Dizini: 0x00000708'
)
$u = Cozumle-Uyku -Satirlar $uykuOrnek
Dogrula 'uyku: prizde 0 (hiç), pilde 1800 sn' ($u.PrizSaniye -eq 0 -and $u.PilSaniye -eq 1800)
Dogrula 'uyku: sayı yoksa $null' ($null -eq (Cozumle-Uyku -Satirlar @('hata')))

$ncOrnek = @(
    'Report:',
    "`t* UDP: true",
    "`t* IPv4: yes, 203.0.113.7:41641",
    "`t* IPv6: no, but OS has support",
    "`t* MappingVariesByDestIP: false",
    "`t* PortMapping: UPnP, NAT-PMP",
    "`t* Nearest DERP: Frankfurt"
)
$n = Cozumle-Netcheck -Satirlar $ncOrnek
Dogrula 'netcheck: UDP true okundu' ($n['UDP'] -eq 'true')
Dogrula 'netcheck: IPv4 adresi ayıklanıyor' ((Al-IpAdresi -Metin $n['IPv4']) -eq '203.0.113.7')
Dogrula 'netcheck: MappingVariesByDestIP false' ($n['MappingVariesByDestIP'] -eq 'false')
Dogrula 'netcheck: Nearest DERP okundu' ($n['Nearest DERP'] -eq 'Frankfurt')
Dogrula 'netcheck: boş çıktı = 0 alan' ((Cozumle-Netcheck -Satirlar @('alakasiz')).Count -eq 0)

Dogrula 'CGNAT 100.64.0.1' (Test-CgnatAraligi -Ip '100.64.0.1')
Dogrula 'CGNAT 100.127.255.254' (Test-CgnatAraligi -Ip '100.127.255.254')
Dogrula '100.128.0.1 CGNAT değil' (-not (Test-CgnatAraligi -Ip '100.128.0.1'))
Dogrula '100.63.255.255 CGNAT değil' (-not (Test-CgnatAraligi -Ip '100.63.255.255'))
Dogrula '8.8.8.8 CGNAT değil' (-not (Test-CgnatAraligi -Ip '8.8.8.8'))

Write-Host '[3] Calistir-Tailscale argümanları aktarıyor (sahte tailscale işlevi)'
function tailscale { return ('ARG:' + ($args -join ' ')) }
$o = Calistir-Tailscale -Arg @('netcheck')
Dogrula 'tailscale netcheck argümanı iletildi' (@($o)[0] -eq 'ARG:netcheck') ($o -join ',')
Remove-Item function:tailscale

# ---- Senaryolar: tüm okuyucular gölgelenir ----
function Sahte-Ortam {
    param([string]$Edition, [bool]$TsVar, [string[]]$Netcheck, [bool]$RdVar)
    $script:SEdition = $Edition; $script:STsVar = $TsVar; $script:SNetcheck = $Netcheck; $script:SRdVar = $RdVar
}
function Oku-EditionID { return $script:SEdition }
function Oku-SurumAdi { return 'Windows Sahte Sürüm' }
function Oku-UykuCikti { return $script:SUyku }
function Oku-Servis { param([string]$Ad)
    if ($Ad -eq 'Tailscale') { return [pscustomobject]@{ Var = $script:STsVar; Durum = 'Running'; Baslangic = 'Automatic' } }
    if ($script:SDort -contains $Ad) { return [pscustomobject]@{ Var = $true; Durum = 'Stopped'; Baslangic = 'Manual' } }
    if (@('Dnscache','iphlpsvc','netprofm','WinHttpAutoProxySvc') -contains $Ad) { return [pscustomobject]@{ Var = $true; Durum = 'Running'; Baslangic = 'Automatic' } }
    return [pscustomobject]@{ Var = $script:SRdVar; Durum = 'Running'; Baslangic = 'Automatic' } }
function Bul-Tailscale { if ($script:STsVar) { return 'tailscale' } else { return $null } }
function Calistir-Tailscale { param([string[]]$Arg) return $script:SNetcheck }
function Bul-RustDeskDosya { return $script:SRdVar }
$script:SUyku = $uykuOrnek
$script:SDort = @()

Write-Host '[4] Senaryo: Home, Tailscale yok, RustDesk yok'
Sahte-Ortam -Edition 'Core' -TsVar $false -Netcheck @() -RdVar $false
$script:Cikti.Clear()
$d = Kontrol-Calistir
$metin = $script:Cikti -join "`n"
Dogrula 'Home uyarısı ve Yol 3b' ($metin -match 'Home sürümü Uzak Masaüstü sunucusu OLAMAZ' -and $metin -match 'Yol 3b')
Dogrula '[YOK] Tailscale kurulu değil' ($metin -match '\[YOK\] Tailscale kurulu değil')
Dogrula 'RustDesk Home için gerekecek' ($metin -match 'Home için gerekecek')
Dogrula 'uyku prizde hiçbir zaman' ($metin -match 'Uyku \(prizde\): hiçbir zaman')
Dogrula 'DURUM satırı: 6 alanlı ASCII tablo satırı, Home, sıradaki 1' ($d -match '^\| \d\d:\d\d \| 0 on kontrol \| bitti \| Windows=Home, uyku=kapali, tailscale=yok, hizmetler4=tamam, rustdesk=yok \| yok \(yalniz okur\) \| 1 \(Tailscale kurulumu\) \|$' -and ($d -cmatch '^[\x20-\x7E]+$'))

Write-Host '[5] Senaryo: Pro, Tailscale var, netcheck iyi, CGNAT aralığı'
Sahte-Ortam -Edition 'Professional' -TsVar $true -Netcheck $ncOrnek -RdVar $false
$script:Cikti.Clear()
$d = Kontrol-Calistir -ModemWanIp '100.72.4.9'
$metin = $script:Cikti -join "`n"
Dogrula 'Pro: Yol 3a' ($metin -match 'Yol 3a')
Dogrula 'netcheck UDP TAMAM' ($metin -match '\[TAMAM\] netcheck UDP: true')
Dogrula 'kolay NAT TAMAM' ($metin -match 'MappingVariesByDestIP: false -> kolay NAT')
Dogrula 'CGNAT aralığı uyarısı' ($metin -match '100\.64\.0\.0/10 aralığında')
Dogrula 'DURUM satırı sıradaki 2, cgnat=var, 6 alan' ($d -match '\| 2 \(dogrudan mi role mi\) \|$' -and $d -match 'cgnat=var' -and (($d -split '\|').Count -eq 8))

Write-Host '[6] Senaryo: modem WAN adresi farklı / aynı'
$script:Cikti.Clear()
$d = Kontrol-Calistir -ModemWanIp '198.51.100.20'
Dogrula 'farklı adres: olası CGNAT' (($script:Cikti -join "`n") -match 'CGNAT\) olabilir' -and $d -match 'cgnat=olasi')
$script:Cikti.Clear()
$d = Kontrol-Calistir -ModemWanIp '203.0.113.7'
Dogrula 'aynı adres: CGNAT görünmüyor' (($script:Cikti -join "`n") -match 'CGNAT görünmüyor' -and $d -match 'cgnat=yok')

Write-Host '[7] Senaryo: zor NAT, UDP false'
$zor = @('Report:', "`t* UDP: false", "`t* MappingVariesByDestIP: true")
Sahte-Ortam -Edition 'Professional' -TsVar $true -Netcheck $zor -RdVar $true
$script:Cikti.Clear()
$d = Kontrol-Calistir
$metin = $script:Cikti -join "`n"
Dogrula 'UDP false uyarısı' ($metin -match '\[UYARI\] netcheck UDP: false')
Dogrula 'zor NAT uyarısı' ($metin -match 'zor NAT')
Dogrula 'RustDesk bulundu' ($metin -match '\[TAMAM\] RustDesk bulundu')

Write-Host '[8] Senaryo: netcheck okunamadı'
Sahte-Ortam -Edition 'Professional' -TsVar $true -Netcheck @('beklenmedik çıktı') -RdVar $false
$script:Cikti.Clear()
$d = Kontrol-Calistir
Dogrula 'okunamayan çıktı ham gösterilir, çökmez' ((($script:Cikti -join "`n") -match 'okunamadı') -and $d -match 'netcheck=okunamadi')

Write-Host '[9] Senaryo: sürüm bilinmiyor'
Sahte-Ortam -Edition '' -TsVar $false -Netcheck @() -RdVar $false
$script:Cikti.Clear()
$d = Kontrol-Calistir
Dogrula 'bilinmeyen sürümde winver yönlendirmesi' ((($script:Cikti -join "`n") -match 'winver') -and $d -match 'Windows=Bilinmiyor')

Write-Host '[10] Senaryo: 4 servis denetimi (yalniz okur)'
Sahte-Ortam -Edition 'Professional' -TsVar $false -Netcheck @() -RdVar $false
$script:Cikti.Clear()
$d = Kontrol-Calistir
Dogrula '4 servis calisiyor: TAMAM + durum ozeti' ((($script:Cikti -join "`n") -match '\[TAMAM\] Tailscale kurulumunun istedigi 4 Windows hizmeti') -and $d -match 'hizmetler4=tamam')
$script:SDort = @('netprofm', 'Dnscache')
$script:Cikti.Clear()
$d = Kontrol-Calistir
$metin = $script:Cikti -join "`n"
Dogrula 'durmus servisler adiyla UYARI' ($metin -match '\[UYARI\].*netprofm \(Stopped\)' -and $metin -match 'Dnscache \(Stopped\)' -and $metin -notmatch 'iphlpsvc \(')
Dogrula 'betik duzeltmez, ajana sor der' ($metin -match 'BASLATMAZ' -and $metin -match 'windows-install-error')
Dogrula 'durum ozeti hizmetler4=eksik, 6 alan' ($d -match 'hizmetler4=eksik' -and (($d -split '\|').Count -eq 8))
$script:SDort = @()
$govde = Get-Content $betik -Raw -Encoding UTF8
Dogrula 'betik hizmet baslatma/durdurma komutu icermiyor' ($govde -notmatch 'Start-Service|Set-Service|Stop-Service|sc\.exe\s+(start|config)')

Remove-Item -Recurse -Force $gecici -ErrorAction SilentlyContinue
Write-Host ''
Write-Host ("Sonuç: {0} geçti, {1} kaldı" -f $script:Gecen, $script:Kalan)
if ($script:Kalan -gt 0) { exit 1 }
exit 0
