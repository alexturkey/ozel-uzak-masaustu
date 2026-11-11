# baglanti_kanit.ps1 testi. Gerçek Tailscale ÇAĞRILMAZ; Calistir-Tailscale sahte işlevle gölgelenir.
# Çalıştırma: powershell -NoProfile -ExecutionPolicy Bypass -File tests\test_baglanti_kanit.ps1   (çıkış 0 = geçti)
$ErrorActionPreference = 'Stop'
$betik = Join-Path $PSScriptRoot '..\araclar\baglanti_kanit.ps1'
$script:Gecen = 0
$script:Kalan = 0
function Dogrula {
    param([string]$Ad, [bool]$Kosul, [string]$Not = '')
    if ($Kosul) { $script:Gecen++; Write-Host "  GEÇTİ  $Ad" }
    else { $script:Kalan++; Write-Host "  KALDI  $Ad  $Not" -ForegroundColor Red }
}

$gecici = Join-Path ([System.IO.Path]::GetTempPath()) ('kanit_test_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $gecici -Force | Out-Null
$env:LOCALAPPDATA = $gecici

Write-Host '[1] Sözdizimi'
$hatalar = $null; $belirtec = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($betik, [ref]$belirtec, [ref]$hatalar)
Dogrula 'baglanti_kanit.ps1 ayrıştırılıyor, sözdizimi hatası yok' ($hatalar.Count -eq 0) (($hatalar | ForEach-Object { $_.Message }) -join '; ')
$bayt = [System.IO.File]::ReadAllBytes($betik)
Dogrula 'dosya UTF-8 BOM ile başlıyor' ($bayt[0] -eq 0xEF -and $bayt[1] -eq 0xBB -and $bayt[2] -eq 0xBF)

. $betik -SadeceIslevler

Write-Host '[2] Pong çözümleme (örnekler Tailscale kb/1257 belgesinden)'
$p1 = Cozumle-Pong -Satir 'pong from another-device (100.104.93.78) via DERP(tor) in 53ms'
Dogrula 'DERP -> relay, 53 ms' ($p1.Tur -eq 'relay' -and $p1.Ms -eq 53)
$p2 = Cozumle-Pong -Satir 'pong from another-device (100.97.143.93) via peer-relay(192.168.64.2:7777:vni:1) in 4ms'
Dogrula 'peer-relay, 4 ms' ($p2.Tur -eq 'peer-relay' -and $p2.Ms -eq 4)
$p3 = Cozumle-Pong -Satir 'pong from another-device (100.113.160.82) via 140.82.13.138:41641 in 35ms'
Dogrula 'IP:port -> direct, 35 ms' ($p3.Tur -eq 'direct' -and $p3.Ms -eq 35 -and $p3.Yol -eq '140.82.13.138:41641')
Dogrula 'pong olmayan satır $null' ($null -eq (Cozumle-Pong -Satir 'direct connection not established'))
$p4 = Cozumle-Pong -Satir 'pong from x (100.1.1.1) via [2001:db8::1]:41641 in 7.5ms'
Dogrula 'IPv6:port -> direct, 7.5 ms' ($p4.Tur -eq 'direct' -and $p4.Ms -eq 7.5)

Write-Host '[3] Status satırı çözümleme (tür sözcükleri belgeden; satır düzeni örnek)'
Dogrula 'direct' ((Cozumle-DurumSatiri -Satir '100.1.1.2  ofis-pc  kul@  windows  active; direct 140.82.13.138:41641, tx 10 rx 20').Tur -eq 'direct')
Dogrula 'relay' ((Cozumle-DurumSatiri -Satir '100.1.1.2  ofis-pc  kul@  windows  active; relay "fra", tx 10 rx 20').Tur -eq 'relay')
Dogrula 'peer-relay (relay değil)' ((Cozumle-DurumSatiri -Satir '100.1.1.2  ofis-pc  kul@  windows  active; peer-relay 100.9.9.9:7777:vni:1').Tur -eq 'peer-relay')
Dogrula 'adında "direct" geçen cihaz yanıltmıyor' ((Cozumle-DurumSatiri -Satir '100.1.1.2  direct-pc  kul@  windows  idle').Tur -eq 'bilinmiyor')
$liste = @('100.1.1.1  benim-pc  kul@  windows  -', '100.1.1.2  ofis-pc  kul@  windows  active; direct 1.2.3.4:5')
Dogrula 'eş adla bulunuyor' ($null -ne (Bul-EsDurumSatiri -Satirlar $liste -Es 'ofis-pc'))
Dogrula 'eş IP ile bulunuyor' ($null -ne (Bul-EsDurumSatiri -Satirlar $liste -Es '100.1.1.2'))
Dogrula 'olmayan eş $null' ($null -eq (Bul-EsDurumSatiri -Satirlar $liste -Es 'yok-pc'))

Write-Host '[4] Yerel adres ayrımı'
Dogrula '192.168.1.5:41641 yerel' (Test-YerelAdres -YolIpPort '192.168.1.5:41641')
Dogrula '10.0.0.2:41641 yerel' (Test-YerelAdres -YolIpPort '10.0.0.2:41641')
Dogrula '172.20.1.1:1 yerel' (Test-YerelAdres -YolIpPort '172.20.1.1:1')
Dogrula '172.32.1.1:1 yerel değil' (-not (Test-YerelAdres -YolIpPort '172.32.1.1:1'))
Dogrula '140.82.13.138:41641 yerel değil' (-not (Test-YerelAdres -YolIpPort '140.82.13.138:41641'))
Dogrula '[fe80::1]:41641 yerel' (Test-YerelAdres -YolIpPort '[fe80::1]:41641')

# ---- Senaryolar ----
$script:SStatus = @()
$script:SPing = @()
$script:SVar = $true
function Bul-Tailscale { if ($script:SVar) { return 'tailscale' } else { return $null } }
function Calistir-Tailscale { param([string[]]$Arg)
    if ($Arg[0] -eq 'status') { return $script:SStatus }
    if ($Arg[0] -eq 'netcheck') { return $script:SNetcheck }
    if ($Arg -contains '--until-direct=false') { $script:SEkPingSayi++; return $script:SEk }
    $script:SSonPingArg = $Arg
    return $script:SPing }
$durumDirect = @('100.1.1.1  benim-pc  kul@  windows  -', '100.1.1.2  ofis-pc  kul@  windows  active; direct 140.82.13.138:41641, tx 1 rx 2')
$durumRelay = @('100.1.1.1  benim-pc  kul@  windows  -', '100.1.1.2  ofis-pc  kul@  windows  active; relay "fra", tx 1 rx 2')

Write-Host '[5] Senaryo: internet üzerinden doğrudan (çıkış 0)'
$script:SEkPingSayi = 0
$script:SEk = @('pong from ofis-pc (100.1.1.2) via 140.82.13.138:41641 in 34ms','pong from ofis-pc (100.1.1.2) via 140.82.13.138:41641 in 43ms','pong from ofis-pc (100.1.1.2) via 140.82.13.138:41641 in 37ms','pong from ofis-pc (100.1.1.2) via 140.82.13.138:41641 in 39ms')
$script:SStatus = $durumDirect
$script:SPing = @('pong from ofis-pc (100.1.1.2) via DERP(fra) in 60ms', 'pong from ofis-pc (100.1.1.2) via 140.82.13.138:41641 in 35ms')
$script:Cikti.Clear()
$kod = Kanit-Calistir -Es 'ofis-pc'
$metin = $script:Cikti -join "`n"
Dogrula 'çıkış kodu 0' ($kod -eq 0) "kod=$kod"
Dogrula 'HÜKÜM: DOĞRUDAN (internet)' ($metin -match 'HÜKÜM: DOĞRUDAN \(internet üzerinden')
Dogrula 'yerel ağ uyarısı YOK' ($metin -notmatch 'kanıtı DEĞİLDİR')
Dogrula 'DURUM satırı: 6 alanlı tablo satırı, bitti, sıradaki 3' ($metin -match '\| \d\d:\d\d \| 2 dogrudan mi role mi \| bitti \| DOGRUDAN 35ms 140\.82\.13\.138:41641 \| yok \(yalniz okur\) \| 3 \(uzak masaustu kurulumu\) \|')
Dogrula 'ping argümanları: --until-direct, --c=10, eş adı' (($script:SSonPingArg -contains '--until-direct') -and ($script:SSonPingArg -contains '--c=10') -and ($script:SSonPingArg -contains 'ofis-pc'))
Dogrula 'ek ping cagrildi (--until-direct=false --c=4)' ($script:SEkPingSayi -eq 1)
Dogrula 'kararli gecikme satiri: ilk olcum 35 vs ek pingler (ortanca 38)' ($metin -match 'Kararli gecikme \(ek 4 ping' -and $metin -match 'en az 34 ms, ortanca 38 ms, en cok 43 ms' -and $metin -match 'Ilk olcum \(35 ms\)')
Dogrula 'DURUM satiri kararli satirdan etkilenmedi' ($metin -match '\| bitti \| DOGRUDAN 35ms 140\.82\.13\.138:41641 \| yok')
$script:SEk = @('pong from ofis-pc (100.1.1.2) via 140.82.13.138:41641 in 40ms')
$script:Cikti.Clear()
$kod = Kanit-Calistir -Es 'ofis-pc'
Dogrula 'tek ek yanit yine de ozetlenir, cikis 0' ($kod -eq 0 -and ($script:Cikti -join "`n") -match 'ortanca 40 ms')
$script:SEk = @('pong from ofis-pc (100.1.1.2) via DERP(fra) in 60ms')
$script:Cikti.Clear()
$kod = Kanit-Calistir -Es 'ofis-pc'
Dogrula 'ek pingde dogrudan yok: olculemedi notu, hukum ve kod degismez' ($kod -eq 0 -and ($script:Cikti -join "`n") -match 'Kararli gecikme olculemedi' -and ($script:Cikti -join "`n") -match 'HÜKÜM: DOĞRUDAN')
$d = Ozetle-Gecikme -Ms @(10, 20, 30, 40)
Dogrula 'ortanca cift sayida: 25' ($d.Medyan -eq 25 -and $d.Min -eq 10 -and $d.Max -eq 40)
Dogrula 'bos olcum $null' ($null -eq (Ozetle-Gecikme -Ms @()))

Write-Host '[6] Senaryo: doğrudan ama yerel ağ (çıkış 0 + uyarı)'
$script:SPing = @('pong from ofis-pc (100.1.1.2) via 192.168.1.20:41641 in 2ms')
$script:Cikti.Clear()
$kod = Kanit-Calistir -Es 'ofis-pc'
$metin = $script:Cikti -join "`n"
Dogrula 'çıkış kodu 0' ($kod -eq 0)
Dogrula 'yerel ağ: internet kanıtı DEĞİLDİR uyarısı' ($metin -match 'kanıtı DEĞİLDİR' -and $metin -match 'hotspot')
Dogrula 'DURUM satırında internet kanıtı değil' ($metin -match 'internet kaniti degil')

Write-Host '[7] Senaryo: röle (çıkış 10)'
$script:SStatus = $durumRelay
$script:SPing = @('pong from ofis-pc (100.1.1.2) via DERP(fra) in 53ms', 'pong from ofis-pc (100.1.1.2) via DERP(fra) in 52ms')
$script:Cikti.Clear()
$kod = Kanit-Calistir -Es 'ofis-pc'
$metin = $script:Cikti -join "`n"
Dogrula 'çıkış kodu 10' ($kod -eq 10) "kod=$kod"
Dogrula 'HÜKÜM: RÖLE ve "hata değil" notu' ($metin -match 'HÜKÜM: RÖLE' -and $metin -match 'HATA değil')
Dogrula 'netcheck okunamadi: neden uydurulmaz' ($metin -match 'ROL NEDEN KARTI' -and $metin -match 'okunamadi; neden soylenemiyor' -and $metin -match 'SECENEKLER:')
$script:SNetcheck = @('Report:', "`t* UDP: false", "`t* MappingVariesByDestIP: true")
$script:Cikti.Clear()
$kod = Kanit-Calistir -Es 'ofis-pc'
$metin = $script:Cikti -join "`n"
Dogrula 'UDP false + zor NAT: iki kaynakli neden' ($kod -eq 10 -and $metin -match 'UDP: false' -and $metin -match 'MappingVariesByDestIP: true' -and $metin -match 'kb/1411')
Dogrula 'secenekler: 3 madde, port ACMA, hotspot' ($metin -match '1\) Rol ile devam' -and $metin -match '3\) Ikinci bilgisayari' -and $metin -match 'port ACMA')
$kartKismi = ($script:Cikti | Where-Object { $_ -match '^\[NEDEN\]|^  \d\)|^SECENEKLER|^---' }) -join ''
Dogrula 'kart satirlari ASCII' ($kartKismi -cmatch '^[\x20-\x7E]+$')
Dogrula 'kart port acmayi onermez' ($metin -notmatch 'UPnP' -and $metin -notmatch 'port ac(?!ma)(?! *\()' -or $metin -match 'port ACMA')
$script:SNetcheck = @('Report:', "`t* UDP: true", "`t* MappingVariesByDestIP: false")
$script:Cikti.Clear()
$kod = Kanit-Calistir -Es 'ofis-pc'
Dogrula 'netcheck temiz: genel aciklama, cikis 10' ($kod -eq 10 -and ($script:Cikti -join "`n") -match 'gostermiyor' -and ($script:Cikti -join "`n") -match 'kb/1257')
$script:SNetcheck = @()

Write-Host '[8] Senaryo: eş röle (çıkış 11)'
$script:SPing = @('pong from ofis-pc (100.1.1.2) via peer-relay(192.168.64.2:7777:vni:1) in 4ms')
$script:Cikti.Clear()
$kod = Kanit-Calistir -Es 'ofis-pc'
Dogrula 'çıkış kodu 11' ($kod -eq 11) "kod=$kod"
Dogrula 'HÜKÜM: EŞ RÖLE' (($script:Cikti -join "`n") -match 'HÜKÜM: EŞ RÖLE')
Dogrula 'esrole de neden karti verir' (($script:Cikti -join "`n") -match 'ROL NEDEN KARTI')

Write-Host '[9] Senaryo: yanıt yok (çıkış 20), "çalışıyor" denmez'
$script:SPing = @('direct connection not established')
$script:Cikti.Clear()
$kod = Kanit-Calistir -Es 'ofis-pc'
$metin = $script:Cikti -join "`n"
Dogrula 'çıkış kodu 20' ($kod -eq 20) "kod=$kod"
Dogrula 'EŞ YANIT VERMEDİ + çalışıyor DEME' ($metin -match 'EŞ YANIT VERMEDİ' -and $metin -match 'DEME')
Dogrula 'DURUM satırı yarim, kullaniciya sor' ($metin -match '\| 2 dogrudan mi role mi \| yarim \| YANIT-YOK \(status turu: relay\) \| yok \(yalniz okur\) \| kullaniciya sor \|')
$script:SPing = @()
$script:Cikti.Clear()
$kod = Kanit-Calistir -Es 'ofis-pc'
Dogrula 'boş ping çıktısı da 20, çökmüyor' ($kod -eq 20)

Write-Host '[10] Senaryo: listede olmayan eş'
$script:SPing = @('pong from x (100.9.9.9) via 140.82.13.138:41641 in 20ms')
$script:Cikti.Clear()
$kod = Kanit-Calistir -Es 'yok-pc'
Dogrula 'listede yok uyarısı, yine de ping denendi' (($script:Cikti -join "`n") -match 'listesinde yok' -and $kod -eq 0)

Write-Host '[11] Senaryo: -Es yok (çıkış 2), Tailscale yok (çıkış 30)'
$script:Cikti.Clear()
$kod = Kanit-Calistir -Es ''
Dogrula '-Es yoksa çıkış 2 ve liste gösterilir' ($kod -eq 2 -and ($script:Cikti -join "`n") -match 'ofis-pc')
$script:SVar = $false
$script:Cikti.Clear()
$kod = Kanit-Calistir -Es 'ofis-pc'
Dogrula 'Tailscale yok: çıkış 30' ($kod -eq 30 -and ($script:Cikti -join "`n") -match 'Tailscale kurulu değil')
Dogrula 'Tailscale yok: DURUM satırı diğer hükümlerle aynı biçimde' (($script:Cikti -join "`n") -match 'DURUM satırı \(DURUM\.md' -and ($script:Cikti -join "`n") -notmatch 'DURUM: ')

Remove-Item -Recurse -Force $gecici -ErrorAction SilentlyContinue
Write-Host ''
Write-Host ("Sonuç: {0} geçti, {1} kaldı" -f $script:Gecen, $script:Kalan)
if ($script:Kalan -gt 0) { exit 1 }
exit 0
