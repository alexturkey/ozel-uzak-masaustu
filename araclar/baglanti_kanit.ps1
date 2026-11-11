<#
.SYNOPSIS
  Adım 2: iki bilgisayar arasındaki Tailscale bağlantısı DOĞRUDAN mı, RÖLE (aracı sunucu) üzerinden mi?
.DESCRIPTION
  YALNIZ OKUR. `tailscale status` ve `tailscale ping` çalıştırır (kullanıcının kendi makinesinde, Tailscale ağı içinde).
  Hüküm Türkçe verilir, çıkış koduna da yazılır:
    0  DOĞRUDAN
    10 RÖLE (DERP, Tailscale'in aracı sunucusu)
    11 EŞ RÖLE (aynı hesaptaki başka bir cihaz aracılık ediyor)
    20 EŞ YANIT VERMEDİ / belirsiz
    30 Tailscale kurulu değil
    2  Kullanım hatası (-Es verilmedi)
  Doğrudan yol yerel ağ adresiyse (192.168.x.x vb.) betik bunu AÇIKÇA söyler: o, internet üzerinden doğrudan bağlantı kanıtı DEĞİLDİR.
  Günlük: %LOCALAPPDATA%\dogrudan-uzak-masaustu\baglanti_kanit.log
.PARAMETER Es
  Karşı bilgisayarın Tailscale adı (ör. ofis-pc) ya da 100.x.y.z adresi. `tailscale status` listesinde görünür.
.PARAMETER Deneme
  En fazla kaç ping atılsın (varsayılan 10).
.PARAMETER SadeceIslevler
  Test için: işlevleri tanımlar, bir şey çalıştırmaz.
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File baglanti_kanit.ps1 -Es ofis-pc
#>
param(
    [string]$Es = '',
    [int]$Deneme = 10,
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
        Add-Content -Path (Join-Path $script:LogDizin 'baglanti_kanit.log') -Value ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Metin) -Encoding UTF8
    } catch { }
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

# `tailscale status` satırında ';' sonrası bağlantı türü yazar: direct / relay / peer-relay (belge: kb/1257).
function Cozumle-DurumSatiri {
    param([string]$Satir)
    $i = $Satir.IndexOf(';')
    if ($i -lt 0) { return [pscustomobject]@{ Tur = 'bilinmiyor'; Ayrinti = '' } }
    $kuyruk = $Satir.Substring($i + 1).Trim()
    # peer-relay, "relay" sözcüğünü de içerir: önce o denenir.
    if ($kuyruk -match '(?<![\w-])peer-relay(?![\w-])') { return [pscustomobject]@{ Tur = 'peer-relay'; Ayrinti = $kuyruk } }
    if ($kuyruk -match '(?<![\w-])relay(?![\w-])')      { return [pscustomobject]@{ Tur = 'relay'; Ayrinti = $kuyruk } }
    if ($kuyruk -match '(?<![\w-])direct(?![\w-])')     { return [pscustomobject]@{ Tur = 'direct'; Ayrinti = $kuyruk } }
    return [pscustomobject]@{ Tur = 'bilinmiyor'; Ayrinti = $kuyruk }
}
function Bul-EsDurumSatiri {
    param([string[]]$Satirlar, [string]$Es)
    foreach ($s in $Satirlar) {
        $t = ([string]$s) -split '\s+' | Where-Object { $_ -ne '' }
        if ($t.Count -ge 2 -and ($t[0] -eq $Es -or $t[1] -ieq $Es)) { return [string]$s }
    }
    return $null
}

# `tailscale ping` yanıt satırı (belge örnekleri, kb/1257):
#   pong from another-device (100.104.93.78) via DERP(tor) in 53ms
#   pong from another-device (100.97.143.93) via peer-relay(192.168.64.2:7777:vni:1) in 4ms
#   pong from another-device (100.113.160.82) via 140.82.13.138:41641 in 35ms
function Cozumle-Pong {
    param([string]$Satir)
    if ($Satir -notmatch '^\s*pong from\s+.*?\s+via\s+(?<yol>\S+)\s+in\s+(?<ms>[\d\.,]+)\s*ms') { return $null }
    $yol = $Matches['yol']
    $ms = 0.0
    [void][double]::TryParse(($Matches['ms'] -replace ',', '.'), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$ms)
    $tur = 'bilinmiyor'
    if ($yol -match '^DERP\(') { $tur = 'relay' }
    elseif ($yol -match '^peer-relay\(') { $tur = 'peer-relay' }
    elseif ($yol -match '^\[?[0-9a-fA-F\.:]+\]?:\d+$') { $tur = 'direct' }
    return [pscustomobject]@{ Tur = $tur; Yol = $yol; Ms = $ms }
}
function Test-YerelAdres {
    param([string]$YolIpPort)
    $ip = $YolIpPort -replace '^\[', '' -replace '\]?:\d+$', ''
    if ($ip -match '^(\d{1,3})\.(\d{1,3})\.\d{1,3}\.\d{1,3}$') {
        $a = [int]$Matches[1]; $b = [int]$Matches[2]
        if ($a -eq 10) { return $true }
        if ($a -eq 192 -and $b -eq 168) { return $true }
        if ($a -eq 172 -and $b -ge 16 -and $b -le 31) { return $true }
        if ($a -eq 169 -and $b -eq 254) { return $true }
        if ($a -eq 100 -and $b -ge 64 -and $b -le 127) { return $true }
        return $false
    }
    if ($ip -match '^(fe80|fc|fd)') { return $true }
    return $false
}

# B2 rol teshis karti: yalniz belgeli netcheck alanlarindan neden yazar (kaynak: tailscale.com/kb/1411/device-connectivity, kb/1257). ASCII cikti.
function Cozumle-NetcheckAlan {
    param([string[]]$Satirlar)
    $r = @{}
    foreach ($s in $Satirlar) {
        if ([string]$s -match '^\s*\*?\s*(UDP|MappingVariesByDestIP)\s*:\s*(.*)$') { $r[$Matches[1]] = $Matches[2].Trim() }
    }
    return $r
}
function Yaz-RolKarti {
    Yaz-Satir ''
    Yaz-Satir '--- ROL NEDEN KARTI (bu bilgisayarda "tailscale netcheck" ile; karsi bilgisayar icin orada da calistir) ---'
    $nc = Calistir-Tailscale -Arg @('netcheck')
    $r = Cozumle-NetcheckAlan -Satirlar $nc
    $neden = 0
    if ($r.ContainsKey('UDP') -and $r['UDP'] -match '^false') {
        Yaz-Satir '[NEDEN] netcheck "UDP: false": bu ag giden UDP paketlerini engelliyor olabilir (ofis/okul/otel agi gibi). Kaynak: https://tailscale.com/kb/1411/device-connectivity'
        $neden++
    }
    if ($r.ContainsKey('MappingVariesByDestIP') -and $r['MappingVariesByDestIP'] -match '^true') {
        Yaz-Satir '[NEDEN] netcheck "MappingVariesByDestIP: true": zor NAT (modem her hedefe farkli port veriyor), role dusme olasiligi yuksek. Kaynak: https://tailscale.com/kb/1411/device-connectivity'
        $neden++
    }
    if ($r.Count -eq 0) {
        Yaz-Satir '[NEDEN] netcheck ciktisi okunamadi; neden soylenemiyor (tahmin yok). Ham ciktiyi kullaniciya goster.'
        foreach ($s in @($nc)) { if ($s) { Yaz-Satir ('        ' + $s) } }
    } elseif ($neden -eq 0) {
        Yaz-Satir '[NEDEN] netcheck bu bilgisayarda UDP engeli ya da zor NAT gostermiyor. Sorun karsi tarafta ya da yol henuz kurulmamis olabilir: Tailscale once DERP uzerinden baslar, sonra dogrudan yol dener. Kaynak: https://tailscale.com/kb/1257/connection-types'
    }
    Yaz-Satir 'SECENEKLER:'
    Yaz-Satir '  1) Rol ile devam: trafik sifreli, arac okuyamaz (https://tailscale.com/kb/1232/derp-servers). Yavas olabilir, hata degil.'
    Yaz-Satir '  2) Birkac dakika sonra bu betigi bir kez daha calistir (dogrudan yol sonradan kurulabilir).'
    Yaz-Satir '  3) Ikinci bilgisayari telefon hotspot''una al ve tekrar calistir: sorun ag mi, bilgisayar mi ayirir. Modemde port ACMA (rehber kurali).'
}

# Kararli gecikme: --until-direct ilk dogrudan pong'da durur, yol kurulurken alinan ilk deger yaniltici olabilir (canli deneme 1: 309 ms, sonra 34-43 ms).
# Dogrudan yol kuruldugunda ek pingle olcer; yalniz okur. Hukmu ve cikis kodunu degistirmez.
function Ozetle-Gecikme {
    param([double[]]$Ms)
    $sirali = @($Ms | Sort-Object)
    if ($sirali.Count -eq 0) { return $null }
    $orta = if ($sirali.Count % 2 -eq 1) { $sirali[[int](($sirali.Count - 1) / 2)] } else { ($sirali[$sirali.Count / 2 - 1] + $sirali[$sirali.Count / 2]) / 2 }
    return [pscustomobject]@{ Adet = $sirali.Count; Min = $sirali[0]; Medyan = $orta; Max = $sirali[-1] }
}
function Yaz-KararliGecikme {
    param([string]$Es, [double]$IlkMs)
    $ek = Calistir-Tailscale -Arg @('ping', '--until-direct=false', '--c=4', '--timeout=10s', $Es)
    $ms = @()
    foreach ($s in @($ek)) {
        $p = Cozumle-Pong -Satir $s
        if ($p -and $p.Tur -eq 'direct') { $ms += [double]$p.Ms }
    }
    $o = Ozetle-Gecikme -Ms $ms
    if ($null -eq $o) {
        Yaz-Satir ("[BILGI] Kararli gecikme olculemedi (ek pingde dogrudan yanit gelmedi). Yukaridaki {0} ms ilk olcumdur, kararli deger sayilmaz." -f $IlkMs)
        return 'kararli yok'
    }
    Yaz-Satir ("[BILGI] Kararli gecikme (ek {0} ping, yalniz dogrudan yanitlar): en az {1} ms, ortanca {2} ms, en cok {3} ms. Ilk olcum ({4} ms) yol kurulurken alinir, kararli deger bu satirdir." -f $o.Adet, $o.Min, $o.Medyan, $o.Max, $IlkMs)
    return ("kararli {0}ms" -f $o.Medyan)
}

function Kanit-Calistir {
    param([string]$Es, [int]$Deneme = 10)
    $saat = Get-Date -Format 'HH:mm'
    $kod = 20
    $kisa = ''
    Yaz-Satir '=== 2. DOĞRUDAN MI, RÖLE Mİ? (yalnız okur) ==='

    if (-not (Bul-Tailscale)) {
        Yaz-Satir '[YOK] Tailscale kurulu değil. Önce Adım 1.'
        Yaz-Satir ''
        Yaz-Satir 'DURUM satırı (DURUM.md dosyasına ekle):'
        Yaz-Satir ("| {0} | 2 dogrudan mi role mi | yarim | Tailscale yok | yok (yalniz okur) | 1 (Tailscale kurulumu) |" -f $saat)
        return 30
    }

    $durum = Calistir-Tailscale -Arg @('status')
    if (-not $Es) {
        Yaz-Satir '[BILGI] -Es verilmedi. Tailscale ağındaki cihazlar (tailscale status):'
        foreach ($s in $durum) { Yaz-Satir ("        " + $s) }
        Yaz-Satir 'Karşı bilgisayarın adını ya da 100.x.y.z adresini seç ve tekrar çalıştır: baglanti_kanit.ps1 -Es <ad>'
        return 2
    }

    $esSatiri = Bul-EsDurumSatiri -Satirlar $durum -Es $Es
    $durumTur = 'listede-yok'
    if ($esSatiri) {
        $d = Cozumle-DurumSatiri -Satir $esSatiri
        $durumTur = $d.Tur
        Yaz-Satir ("[BILGI] tailscale status: {0}" -f $esSatiri.Trim())
        Yaz-Satir ("[BILGI] status bağlantı türü: {0}" -f $durumTur)
    } else {
        Yaz-Satir ("[UYARI] '{0}' tailscale status listesinde yok. Ad yanlış olabilir ya da cihaz aynı hesapta değil; ping yine de denenecek." -f $Es)
    }

    # Ping: doğrudan yol kurulunca durur (--until-direct); ilk paketler röleden gidebilir, bu normaldir (belge: kb/1257).
    $ping = Calistir-Tailscale -Arg @('ping', '--until-direct', "--c=$Deneme", '--timeout=10s', $Es)
    $pongler = @()
    foreach ($s in $ping) {
        $p = Cozumle-Pong -Satir $s
        if ($p) { $pongler += $p }
    }
    $ham = ($ping | Where-Object { $_ -ne '' }) -join ' / '
    Yaz-Satir ("[BILGI] tailscale ping çıktısı: {0}" -f $ham)

    $dogrudan = $pongler | Where-Object { $_.Tur -eq 'direct' } | Select-Object -Last 1
    $peerRelay = $pongler | Where-Object { $_.Tur -eq 'peer-relay' } | Select-Object -Last 1
    $relay = $pongler | Where-Object { $_.Tur -eq 'relay' } | Select-Object -Last 1
    $kurulamadi = ($ping -join "`n") -match 'direct connection not established'

    if ($dogrudan) {
        if (Test-YerelAdres -YolIpPort $dogrudan.Yol) {
            Yaz-Satir ("[TAMAM] HÜKÜM: DOĞRUDAN, yerel ağ adresi üzerinden ({0}), {1} ms." -f $dogrudan.Yol, $dogrudan.Ms)
            Yaz-Satir '[UYARI] İki bilgisayar aynı yerel ağda (ya da aynı modemin arkasında). Bu, internet üzerinden doğrudan bağlantının kanıtı DEĞİLDİR. Gerçek kanıt için ikinci bilgisayarı telefon hotspot''una al ve bu betiği tekrar çalıştır.'
            $kisa = "DOGRUDAN-yerel-ag {0}ms (internet kaniti degil)" -f $dogrudan.Ms
        } else {
            Yaz-Satir ("[TAMAM] HÜKÜM: DOĞRUDAN (internet üzerinden, aracı yok): {0}, {1} ms." -f $dogrudan.Yol, $dogrudan.Ms)
            $kisa = "DOGRUDAN {0}ms {1}" -f $dogrudan.Ms, $dogrudan.Yol
        }
        $kod = 0
        [void](Yaz-KararliGecikme -Es $Es -IlkMs $dogrudan.Ms)
    } elseif ($peerRelay) {
        Yaz-Satir ("[UYARI] HÜKÜM: EŞ RÖLE: trafik aynı hesaptaki başka bir cihaz üzerinden geçiyor ({0}), {1} ms. Doğrudan yol kurulamadı." -f $peerRelay.Yol, $peerRelay.Ms)
        $kisa = "ESROLE {0}ms" -f $peerRelay.Ms
        $kod = 11
        Yaz-RolKarti
    } elseif ($relay) {
        Yaz-Satir ("[UYARI] HÜKÜM: RÖLE (DERP aracı sunucusu): {0}, {1} ms. Doğrudan yol kurulamadı." -f $relay.Yol, $relay.Ms)
        Yaz-Satir '        Bu bir HATA değil, normal yedek yoldur (şifreli trafik aracıdan geçer, aracı okuyamaz). Doğrudan olmasını istiyorsan: iki cihazın da kontrol.ps1 çıktısına bak (UDP engeli, zor NAT).'
        $kisa = "ROLE {0}ms" -f $relay.Ms
        $kod = 10
        Yaz-RolKarti
    } else {
        if ($kurulamadi) { Yaz-Satir '[UYARI] "direct connection not established" yazdı ve hiç yanıt (pong) gelmedi.' }
        Yaz-Satir '[UYARI] HÜKÜM: EŞ YANIT VERMEDİ ya da çıktı okunamadı. Karşı bilgisayar kapalı/uykuda olabilir, aynı hesapta olmayabilir ya da Tailscale çalışmıyor olabilir. Yukarıdaki ham çıktıyı kullanıcıya göster; "çalışıyor" DEME.'
        $kisa = "YANIT-YOK (status turu: $durumTur)"
        $kod = 20
    }

    Yaz-Satir ''
    Yaz-Satir 'DURUM satırı (DURUM.md dosyasına ekle):'
    Yaz-Satir ("| {0} | 2 dogrudan mi role mi | {1} | {2} | yok (yalniz okur) | {3} |" -f $saat, $(if ($kod -eq 0 -or $kod -eq 10 -or $kod -eq 11) { 'bitti' } else { 'yarim' }), $kisa, $(if ($kod -eq 0 -or $kod -eq 10) { '3 (uzak masaustu kurulumu)' } else { 'kullaniciya sor' }))
    return $kod
}

if ($SadeceIslevler) { return }
$k = Kanit-Calistir -Es $Es -Deneme $Deneme
exit $k
