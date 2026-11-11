# kopru_kesif / kopru_gonder / kopru_bekle / kopru_durum testi. Gerçek Tailscale ÇAĞRILMAZ:
# işlev testlerinde Calistir-Tailscale gölgelenir; yarış testinde PATH'e sahte tailscale.cmd konur.
# Çalıştırma: powershell -NoProfile -ExecutionPolicy Bypass -File tests\test_kopru.ps1   (çıkış 0 = geçti)
$ErrorActionPreference = 'Stop'
$script:Gecen = 0
$script:Kalan = 0
function Dogrula {
    param([string]$Ad, [bool]$Kosul, [string]$Not = '')
    if ($Kosul) { $script:Gecen++; Write-Host "  GEÇTİ  $Ad" }
    else { $script:Kalan++; Write-Host "  KALDI  $Ad  $Not" -ForegroundColor Red }
}

$gecici = Join-Path ([System.IO.Path]::GetTempPath()) ('kopru_test_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $gecici -Force | Out-Null
$env:LOCALAPPDATA = Join-Path $gecici 'yerel'
$indir = Join-Path $gecici 'Downloads'
New-Item -ItemType Directory -Path $indir -Force | Out-Null
$araclar = Join-Path $PSScriptRoot '..\araclar'

Write-Host '[1] Sözdizimi ve kodlama'
foreach ($ad in 'kopru_ortak', 'kopru_kesif', 'kopru_gonder', 'kopru_bekle', 'kopru_durum') {
    $b = Join-Path $araclar "$ad.ps1"
    $h = $null; $t = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($b, [ref]$t, [ref]$h)
    Dogrula "$ad ayrıştırılıyor" ($h.Count -eq 0) (($h | ForEach-Object { $_.Message }) -join '; ')
    $by = [System.IO.File]::ReadAllBytes($b)
    Dogrula "$ad UTF-8 BOM" ($by[0] -eq 0xEF -and $by[1] -eq 0xBB -and $by[2] -eq 0xBF)
}

. (Join-Path $araclar 'kopru_kesif.ps1') -SadeceIslevler
. (Join-Path $araclar 'kopru_gonder.ps1') -SadeceIslevler
. (Join-Path $araclar 'kopru_bekle.ps1') -SadeceIslevler
. (Join-Path $araclar 'kopru_durum.ps1') -SadeceIslevler

# ---- Sahte Tailscale ----
$script:SJson = ''
$script:SVar = $true
$script:SCpKod = 0
$script:SCp = New-Object System.Collections.ArrayList
function Calistir-Tailscale { param([string[]]$Arg, [int]$ZamanAsimiSn = 60)
    if (-not $script:SVar) { return [pscustomobject]@{ Kod = -1; Satirlar = @() } }
    if ($Arg[0] -eq 'status') { return [pscustomobject]@{ Kod = 0; Satirlar = @($script:SJson -split "`n") } }
    if ($Arg[0] -eq 'file' -and $Arg[1] -eq 'cp') {
        [void]$script:SCp.Add($Arg[2])
        if ($script:SCpKod -eq 0) { Copy-Item -LiteralPath $Arg[2] -Destination $script:SAlici }
        return [pscustomobject]@{ Kod = $script:SCpKod; Satirlar = @('sahte hata: no such peer') } }
    return [pscustomobject]@{ Kod = 0; Satirlar = @() }
}
function Durum-Json { param([object[]]$Esler, [string]$Backend = 'Running')
    $peer = [ordered]@{}
    $i = 0
    foreach ($e in $Esler) { $i++; $peer["nodekey:$i"] = $e }
    return (@{ BackendState = $Backend; Self = @{ ID = 'nSELF123456'; UserID = 7; DNSName = 'ben-pc.ornek.ts.net.'; OS = 'windows' }; Peer = $peer } | ConvertTo-Json -Depth 5)
}
function Es { param([string]$Dns, [string]$Os = 'windows', [bool]$Online = $true, [int]$Uid = 7, [string]$Neden = '', [string]$Id = '')
    if (-not $Id) { $Id = "n$Dns" }
    $h = @{ ID = $Id; PublicKey = "nodekey:$Dns"; HostName = $Dns.ToUpperInvariant(); DNSName = "$Dns.ornek.ts.net."; OS = $Os; Online = $Online; UserID = $Uid }
    if ($Neden) { $h.NoFileSharingReason = $Neden }
    return $h
}
function Sifirla { $script:Cikti.Clear(); Remove-Item -Recurse -Force (Join-Path $env:LOCALAPPDATA 'dogrudan-uzak-masaustu') -ErrorAction SilentlyContinue; Ayar-Yukle }
function Metin { return ($script:Cikti -join "`n") }
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Birak { param([string]$Ad, [string]$Icerik) [System.IO.File]::WriteAllText((Join-Path $indir $Ad), $Icerik, $utf8) }

Write-Host '[2] Keşif'
Sifirla; $script:SVar = $false
Dogrula 'Tailscale yok: 2' ((Kesif-Calistir) -eq 2 -and (Metin) -match 'kurulu değil')
$script:SVar = $true
Sifirla; $script:SJson = Durum-Json -Esler @() -Backend 'NeedsLogin'
Dogrula 'giriş yok: 2' ((Kesif-Calistir) -eq 2 -and (Metin) -match 'NeedsLogin')
Sifirla; $script:SJson = Durum-Json -Esler @((Es 'telefon' -Os 'iOS'), (Es 'baskasi-pc' -Uid 9))
Dogrula 'yalnız telefon ve başka hesap: 2, eş yok' ((Kesif-Calistir) -eq 2 -and (Metin) -match 'başka Windows bilgisayar görünmüyor')
Sifirla; $script:SJson = Durum-Json -Esler @((Es 'ofis-pc' -Neden 'Taildrop disabled'))
Dogrula 'Send Files kapalı: 2, neden yazılı' ((Kesif-Calistir) -eq 2 -and (Metin) -match 'Send Files')
Sifirla; $script:SJson = Durum-Json -Esler @((Es 'ofis-pc' -Online $false))
Dogrula 'çevrimdışı: 3 ama es.json yazıldı (bekçi kurulabilir)' ((Kesif-Calistir) -eq 3 -and (Es-Oku).dns -eq 'ofis-pc' -and (Es-Oku).cevrimici -eq $false)
Sifirla; $script:SJson = Durum-Json -Esler @((Es 'ofis-pc'), (Es 'telefon' -Os 'iOS'))
$k = Kesif-Calistir
$es = Es-Oku
Dogrula 'tek eş: 0' ($k -eq 0) "kod=$k"
Dogrula 'es.json alanları' ($es.dns -eq 'ofis-pc' -and $es.nodeId -eq 'nofis-pc' -and $es.publicKey -eq 'nodekey:ofis-pc' -and $es.hostName -eq 'OFIS-PC' -and $es.benimDns -eq 'ben-pc' -and $es.cevrimici -eq $true)
$script:SJson = Durum-Json -Esler @((Es 'ofis-pc' -Id 'nBASKA'))
$script:Cikti.Clear()
Dogrula 'aynı ad başka NodeID: uyarı' ((Kesif-Calistir) -eq 0 -and (Metin) -match 'NodeID değişti')
Sifirla; $script:SJson = Durum-Json -Esler @((Es 'ofis-pc'), (Es 'ev-pc'))
Dogrula '2 aday: 5, dns boş, paylasilan notu' ((Kesif-Calistir) -eq 5 -and -not (Es-Oku).dns -and @((Es-Oku).adaylar).Count -eq 2 -and (Metin) -match 'paylasilan')
$script:Cikti.Clear()
Dogrula '-Sec ile seçim: 0' ((Kesif-Calistir -Sec 'ev-pc') -eq 0 -and (Es-Oku).dns -eq 'ev-pc')
$script:Cikti.Clear()
Dogrula 'yeniden keşifte önceki seçim korunur' ((Kesif-Calistir) -eq 0 -and (Es-Oku).dns -eq 'ev-pc')

Write-Host '[3] Gönderme'
Sifirla; $script:SJson = Durum-Json -Esler @((Es 'ofis-pc')); [void](Kesif-Calistir)
$script:SAlici = $indir
$script:Cikti.Clear()
$k = Gonder-Calistir -Tur istek -Konu 'ping' -Metin 'ölç lütfen'
$giden = Join-Path (Kopru-Yol 'giden') 'kopru_ben-pc_001_ping.md'
Dogrula 'gönderildi: 0, ad doğru' ($k -eq 0 -and (Test-Path $giden)) (Metin)
Dogrula 'ilk satır tur: istek, başlık --- ile biter' ((Get-Content $giden -Encoding UTF8)[0] -eq 'tur: istek' -and (Get-Content $giden -Encoding UTF8)[4] -eq '---')
Dogrula 'sayaç 2 oldu' ((Get-Content (Kopru-Yol 'sayac.txt')).Trim() -eq '2')
Dogrula 'defter tarihi değişmez biçimde' ((Defter-Oku)[0].tarih -match '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d$')
$script:Cikti.Clear()
Dogrula 'geçersiz konu: 2' ((Gonder-Calistir -Tur bilgi -Konu 'Kötü Konu' -Metin 'x') -eq 2)
Dogrula 'tur yok: 2' ((Gonder-Calistir -Konu 'a' -Metin 'x') -eq 2)
Dogrula '64 KB üstü: 6' ((Gonder-Calistir -Tur bilgi -Konu 'buyuk' -Metin ('a' * 70000)) -eq 6)
Dogrula 'liste dışı hedef: 2' ((Gonder-Calistir -Tur bilgi -Konu 'a' -Metin 'x' -Hedef 'yabanci-pc') -eq 2)
$script:Cikti.Clear()
Dogrula 'kuru: 0, gönderim yok' ((Gonder-Calistir -Tur bilgi -Konu 'kuru' -Metin 'x' -Kuru) -eq 0 -and $script:SCp.Count -eq 1)
$script:SCpKod = 1
Dogrula 'tailscale hatası: 8, sayaç ilerlemedi' ((Gonder-Calistir -Tur bilgi -Konu 'hata' -Metin 'x') -eq 8 -and (Get-Content (Kopru-Yol 'sayac.txt')).Trim() -eq '2')
$script:SCpKod = 0
Set-Content (Kopru-Yol 'sayac.txt') 'bozuk'
$script:Cikti.Clear()
Dogrula 'bozuk sayaç defterden toparlanır (002)' ((Gonder-Calistir -Merhaba) -eq 0 -and (Test-Path (Join-Path (Kopru-Yol 'giden') 'kopru_ben-pc_002_merhaba.md')))
$mh = Get-Content (Join-Path (Kopru-Yol 'giden') 'kopru_ben-pc_002_merhaba.md') -Encoding UTF8 -Raw
Dogrula 'merhaba gövdesi tanisma_id, node_id, uyanma' ($mh -match 'tanisma_id: [a-f0-9]{12}' -and $mh -match 'node_id: nSELF123456' -and $mh -match 'uyanma: evet')
Dogrula 'merhaba-tamam kötü id: 2' ((Gonder-Calistir -MerhabaTamam -TanismaId 'X;rm') -eq 2)
$script:Cikti.Clear()
Dogrula 'test dosyası 1 MB ek ile: 0' ((Gonder-Calistir -TestMB 1) -eq 0 -and (Metin) -match 'ek: test_1mb_\d{6}\.bin sha256=[0-9a-f]{64} bayt=1048576')
$cpOnce = $script:SCp.Count
$testDosya = @(Get-ChildItem (Kopru-Yol 'test'))[0].FullName
Dogrula 'aynı ek ikinci kez gitmez, yalnız mesaj gider' ((Gonder-Calistir -Tur bilgi -Konu 'tekrar-ek' -Metin 'x' -Ek $testDosya) -eq 0 -and $script:SCp.Count -eq $cpOnce + 1)
Dogrula 'ek adı kurala uymuyor: 2' ((Gonder-Calistir -Tur bilgi -Konu 'a' -Metin 'x' -Ek (Join-Path $gecici 'yok dosya.bin')) -eq 2)
New-Item -ItemType Directory -Force -Path (Kopru-Yol 'gelen\ek') | Out-Null
Set-Content (Join-Path (Kopru-Yol 'gelen\ek') 'test_1mb_123456.bin') 'x'
Set-Content (Join-Path (Kopru-Yol 'gelen\ek') 'test_1mb_123456.binx') 'x'
Set-Content (Join-Path (Kopru-Yol 'gelen\ek') 'onemli.txt') 'x'
[void](Test-Temizle)
$ekd = Kopru-Yol 'gelen\ek'
Dogrula 'temizlik yalnız test_<n>mb_<saat>.bin' (-not (Test-Path (Join-Path $ekd 'test_1mb_123456.bin')) -and (Test-Path (Join-Path $ekd 'test_1mb_123456.binx')) -and (Test-Path (Join-Path $ekd 'onemli.txt')) -and @(Get-ChildItem (Kopru-Yol 'test')).Count -eq 0)
New-Item -ItemType File -Path (Kopru-Yol 'DUR') | Out-Null
Dogrula 'DUR: 4' ((Gonder-Calistir -Tur bilgi -Konu 'a' -Metin 'x') -eq 4)
$script:Cikti.Clear()
Dogrula 'DUR varken -Dur yine gider (eşe haber)' ((Gonder-Calistir -Dur) -eq 0 -and (Metin) -match '_dur\.md')
Remove-Item (Kopru-Yol 'DUR')
$script:Ayar.saatlik_tavan = 3
Dogrula 'hata freni: 7' ((Gonder-Calistir -Tur bilgi -Konu 'a' -Metin 'x') -eq 7)
$script:Ayar.saatlik_tavan = 0
Dogrula 'tavan 0 = sınırsız' ((Gonder-Calistir -Tur bilgi -Konu 'a' -Metin 'x') -eq 0)
Set-Content (Kopru-Yol 'ayar.json') '{ "saatlik_tavan": 2 }'; Ayar-Yukle
Dogrula 'ayar.json okunur, profil kendi' ($script:Ayar.saatlik_tavan -eq 2 -and $script:Profil -eq 'kendi' -and $script:Ayar.gelen_saatlik_uyanma -eq 120)
Set-Content (Kopru-Yol 'ayar.json') '{ "profil": "paylasilan", "saatlik_tavan": -5 }'; Ayar-Yukle
Dogrula 'paylasilan profil; negatif değer yok sayılır' ($script:Profil -eq 'paylasilan' -and $script:Ayar.saatlik_tavan -eq 20 -and $script:Ayar.ek_serbest_yol -eq 0)
$disari = Join-Path $gecici 'disari.bin'; Set-Content $disari 'x'
Dogrula 'paylasilan: depo/köprü dışı ek reddedilir' ((Gonder-Calistir -Tur bilgi -Konu 'a' -Metin 'x' -Ek $disari) -eq 2)
Set-Content (Kopru-Yol 'ayar.json') '{ bozuk'; Ayar-Yukle
Dogrula 'bozuk ayar.json: varsayılan' ($script:Profil -eq 'kendi' -and $script:Ayar.saatlik_tavan -eq 60)
Remove-Item (Kopru-Yol 'ayar.json'); Ayar-Yukle

Write-Host '[4] Bekçi'
Get-ChildItem $indir -File | Remove-Item
Sifirla; $script:SJson = Durum-Json -Esler @((Es 'ofis-pc')); [void](Kesif-Calistir)
Birak 'kopru_ofis-pc_001_ping.md' "tur: istek`nkonu: ping`nno: 001`ngonderen: ofis-pc`n---`nölç"
Birak 'kopru_yabanci_001_ping.md' "tur: istek`n---`nx"
Birak 'kopru_ofis-pc_002_buyuk.md' ('a' * 70000)
Birak 'kopru_ofis-pc_007_web.md' "tur: istek`n---`ntarayıcıdan"
Set-Content -LiteralPath (Join-Path $indir 'kopru_ofis-pc_007_web.md') -Stream 'Zone.Identifier' -Value "[ZoneTransfer]`r`nZoneId=3"
Birak 'notlar.md' 'x'
$script:Cikti.Clear()
$k = Bekle-Calistir -AzamiDakika 1 -AralikSaniye 1 -Indirilenler $indir -EkBekleSaniye 3
Dogrula 'yeni mesaj: 0' ($k -eq 0) (Metin)
Dogrula 'YENI satırı tur=istek gonderen=ofis-pc' ((Metin) -match 'YENI: .*kopru_ofis-pc_001_ping\.md tur=istek gonderen=ofis-pc no=001 konu=ping')
Dogrula 'gelen\ klasörüne taşındı' ((Test-Path (Join-Path (Kopru-Yol 'gelen') 'kopru_ofis-pc_001_ping.md')) -and -not (Test-Path (Join-Path $indir 'kopru_ofis-pc_001_ping.md')))
Dogrula 'yabancı önek ve başka dosya dokunulmadı' ((Test-Path (Join-Path $indir 'kopru_yabanci_001_ping.md')) -and (Test-Path (Join-Path $indir 'notlar.md')))
Dogrula '64 KB üstü atlandı, yerinde' ((Metin) -match 'ATLANDI \(65536' -and (Test-Path (Join-Path $indir 'kopru_ofis-pc_002_buyuk.md')))
Dogrula 'tarayıcıyla inmiş (Zone.Identifier) atlandı, yerinde' ((Metin) -match 'tarayıcıyla inmiş' -and (Test-Path (Join-Path $indir 'kopru_ofis-pc_007_web.md')))
Remove-Item (Join-Path $indir 'kopru_ofis-pc_002_buyuk.md'), (Join-Path $indir 'kopru_ofis-pc_007_web.md')
Birak 'kopru_ofis-pc_001_ping (1).md' "tur: istek`nkonu: ping`nno: 001`ngonderen: ofis-pc`n---`nölç"
Birak 'kopru_ofis-pc_003_not.md' "konu: not`n---`ntür satırı yok"
$script:Cikti.Clear()
$k = Bekle-Calistir -AzamiDakika 1 -AralikSaniye 1 -Indirilenler $indir -EkBekleSaniye 3
Dogrula 'tekrar işlenmedi (TEKRAR satırı), yalnız 003 yeni' ($k -eq 0 -and (Metin) -match 'TEKRAR' -and (Metin) -notmatch 'YENI: .*001_ping' -and (Metin) -match '003_not\.md tur=bilgi')
Dogrula 'tekrar dosyası tekrar\ altına' (@(Get-ChildItem (Kopru-Yol 'gelen\tekrar')).Count -eq 1)
Birak 'kopru_ofis-pc_004_bom.md' ([string][char]0xFEFF + "tur: istek`n---`nx")
Birak 'kopru_ofis-pc_005_cizgisiz.md' "tur: istek`nek: rapor.pdf sha256=$('0'*64) bayt=1"
$script:Cikti.Clear()
[void](Bekle-Calistir -AzamiDakika 1 -AralikSaniye 1 -Indirilenler $indir -EkBekleSaniye 1)
Dogrula 'BOMlu başlık: tur=istek' ((Metin) -match '004_bom\.md tur=istek')
Dogrula '--- yoksa başlık yok: tur=bilgi, ek aranmaz' ((Metin) -match '005_cizgisiz\.md tur=bilgi' -and (Metin) -notmatch 'EK: ')
$gercek = [byte[]](1..200)
$sha = [System.BitConverter]::ToString((New-Object System.Security.Cryptography.SHA256Managed).ComputeHash($gercek)).Replace('-', '').ToLowerInvariant()
[System.IO.File]::WriteAllBytes((Join-Path $indir 'test_1mb_000001.bin'), [byte[]](@(201..255) + @(1..145)))
[System.IO.File]::WriteAllBytes((Join-Path $indir 'test_1mb_000001 (1).bin'), $gercek)
Birak 'kopru_ofis-pc_006_dosya-testi.md' "tur: bilgi`nkonu: dosya-testi`nek: test_1mb_000001.bin sha256=$sha bayt=200`n---`n"
$script:Cikti.Clear()
$k = Bekle-Calistir -AzamiDakika 1 -AralikSaniye 1 -Indirilenler $indir -EkBekleSaniye 3
Dogrula 'ek: sha uyan "(1)" alındı' ($k -eq 0 -and (Metin) -match 'EK: .*test_1mb_000001\.bin sha esit bayt=200')
Dogrula 'ek: uymayan aynı adlı dosyaya dokunulmadı' (Test-Path (Join-Path $indir 'test_1mb_000001.bin'))
Birak 'kopru_ofis-pc_008_dosya-testi.md' "tur: bilgi`nek: gec.bin sha256=$sha bayt=200`n---`n"
$script:Cikti.Clear()
[void](Bekle-Calistir -AzamiDakika 1 -AralikSaniye 1 -Indirilenler $indir -EkBekleSaniye 1)
Dogrula 'gelmeyen ek: "henüz gelmedi" + -EkMesaj yolu' ((Metin) -match 'henüz gelmedi' -and (Metin) -match '-EkMesaj')
[System.IO.File]::WriteAllBytes((Join-Path $indir 'gec.bin'), $gercek)
$script:Cikti.Clear()
Dogrula '-EkMesaj ile geç gelen ek alınır' ((Bekle-Calistir -Indirilenler $indir -EkMesaj (Join-Path (Kopru-Yol 'gelen') 'kopru_ofis-pc_008_dosya-testi.md')) -eq 0 -and (Metin) -match 'gec\.bin sha esit')
Birak 'kopru_ofis-pc_009_dur.md' "tur: bilgi`n---`ndur"
$script:Cikti.Clear()
Dogrula 'dur mesajı: 4, DUR kuruldu' ((Bekle-Calistir -AzamiDakika 1 -AralikSaniye 1 -Indirilenler $indir) -eq 4 -and (Dur-Var))
$script:Cikti.Clear()
Dogrula 'DUR varken bekçi: 4' ((Bekle-Calistir -AzamiDakika 1 -AralikSaniye 1 -Indirilenler $indir) -eq 4)
Remove-Item (Kopru-Yol 'DUR')
$script:Cikti.Clear()
$t0 = Get-Date
Dogrula 'boş kutuda zaman aşımı: 3' ((Bekle-Calistir -AzamiDakika 0 -AralikSaniye 1 -Indirilenler $indir) -eq 3 -and ((Get-Date) - $t0).TotalSeconds -lt 30)
Remove-Item (Kopru-Yol 'es.json')
$script:SJson = Durum-Json -Esler @()
$script:Cikti.Clear()
Dogrula 'es.json yok, eş de yok: keşif dener, zaman aşımı 3' ((Bekle-Calistir -AzamiDakika 0 -Indirilenler $indir -KesifAralikSaniye 1) -eq 3 -and (Metin) -match 'ES YOK')
$script:SJson = Durum-Json -Esler @((Es 'ofis-pc'))
Birak 'kopru_ofis-pc_010_merhaba.md' "tur: istek`n---`nmerhaba"
$script:Cikti.Clear()
Dogrula 'es.json yok, eş sonradan geldi: bekçi kendisi bulur ve mesajı alır' ((Bekle-Calistir -AzamiDakika 1 -AralikSaniye 1 -Indirilenler $indir -KesifAralikSaniye 1) -eq 0 -and (Metin) -match 'ES BULUNDU: ofis-pc' -and (Metin) -match '010_merhaba')

Write-Host '[5] Uçtan uca (sahte taşıma) ve durum'
Get-ChildItem $indir -File | Remove-Item
Sifirla; $script:SJson = Durum-Json -Esler @((Es 'ofis-pc')); [void](Kesif-Calistir)
$e = Es-Oku; $e.adaylar = @('ben-pc'); ($e | ConvertTo-Json) | Set-Content (Kopru-Yol 'es.json') -Encoding UTF8
[void](Gonder-Calistir -Tur sonuc -Konu 'olcum' -Metin 'doğrudan 15 ms')
$script:Cikti.Clear()
Dogrula 'gönderilen mesaj bekçiye ulaştı' ((Bekle-Calistir -AzamiDakika 1 -AralikSaniye 1 -Indirilenler $indir) -eq 0 -and (Metin) -match 'kopru_ben-pc_001_olcum\.md tur=sonuc')
$script:Cikti.Clear()
Dogrula 'durum: defter sayıları' ((Metin) -eq '' -and ((Durum-Calistir) -in 0, 1) -and (Metin) -match 'giden 1 · gelen 1')

Write-Host '[6] Yarış: iki süreç aynı anda 8er mesaj (sahte tailscale.cmd)'
$sahte = Join-Path $gecici 'sahte_bin'; New-Item -ItemType Directory -Force $sahte | Out-Null
Set-Content (Join-Path $sahte 'tailscale.cmd') "@echo off`r`nif ""%1""==""file"" copy /y %3 ""$indir"" >nul`r`nexit /b 0" -Encoding ASCII
Get-ChildItem $indir -File | Remove-Item
Sifirla; [void](Kesif-Calistir)
$env:PATH = "$sahte;$env:PATH"
$gb = (Resolve-Path (Join-Path $araclar 'kopru_gonder.ps1')).Path
$is = "1..8 | ForEach-Object { & '$gb' -Tur bilgi -Konu yaris -Metin x | Out-Null }"
$isDosya = Join-Path $gecici 'yaris_isci.ps1'; [System.IO.File]::WriteAllText($isDosya, $is, (New-Object System.Text.UTF8Encoding($true)))
$p = @(1, 2 | ForEach-Object { Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $isDosya + '"') -WindowStyle Hidden -PassThru })
$p | ForEach-Object { [void]$_.WaitForExit(180000) }
$gitti = @(Defter-Oku | Where-Object { $_.durum -eq 'gitti' })
Dogrula '16 mesaj, 16 benzersiz numara, 16 dosya' ($gitti.Count -eq 16 -and @($gitti | ForEach-Object { $_.no } | Select-Object -Unique).Count -eq 16 -and @(Get-ChildItem $indir -Filter 'kopru_*.md').Count -eq 16) ("gitti=$($gitti.Count)")

Remove-Item -Recurse -Force $gecici -ErrorAction SilentlyContinue
Write-Host ''
Write-Host ("Sonuç: {0} geçti, {1} kaldı" -f $script:Gecen, $script:Kalan)
if ($script:Kalan -gt 0) { exit 1 }
exit 0
