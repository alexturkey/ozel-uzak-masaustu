<#
.SYNOPSIS
  Köprü betiklerinin ortak işlevleri (kopru_kesif, kopru_gonder, kopru_bekle bunu nokta ile yükler).
.DESCRIPTION
  Yalnız yerel köprü klasörüne yazar: %LOCALAPPDATA%\dogrudan-uzak-masaustu\kopru\
    es.json       eşin kimliği (kopru_kesif yazar)
    ayar.json     kişiye göre ayar (isteğe bağlı; KOPRU.md "Ayarlar")
    defter.jsonl  giden ve gelen her mesajın satırı (tek kaynak)
    sayac.txt     sıradaki giden mesaj numarası
    giden\ gelen\ gelen\ek\ gelen\tekrar\ test\
    DUR           varsa köprü durur (gönderme ve bekleme yapılmaz)
  Bu klasör repo DIŞINDADIR; mesajlar repoya girmez.
#>

$script:KopruDizin = Join-Path $env:LOCALAPPDATA 'dogrudan-uzak-masaustu\kopru'
$script:Kultur = [System.Globalization.CultureInfo]::InvariantCulture
$script:TarihBicim = 'yyyy-MM-ddTHH:mm:ss'
$script:KonuDesen = '^[a-z0-9-]{1,30}$'
$script:EkAdDesen = '^[A-Za-z0-9._-]{1,80}$'
$script:RehberSurumu = '2026-11-11'
$script:Cikti = New-Object System.Collections.ArrayList
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

# ---- Ayarlar: varsayılanlar ÖNERİDİR; ayar.json ile kişiye göre değişir ----
# profil "kendi"     : iki bilgisayar da senin (varsayılan). Frenler sessiz ve geniş.
# profil "paylasilan": ofis, aile ya da hesapta tanımadığın cihaz var. Frenler sıkı.
$script:Profiller = @{
    kendi      = @{ saatlik_tavan = 60; azami_bayt = 65536; okuma_bayt = 16384; ek_azami_mb = 1024; ek_bekle_saniye = 30; bekle_azami_dakika = 55 }
    paylasilan = @{ saatlik_tavan = 20; azami_bayt = 65536; okuma_bayt = 16384; ek_azami_mb = 100;  ek_bekle_saniye = 30; bekle_azami_dakika = 55 }
}
$script:Profiller.kendi.gelen_saatlik_uyanma = 120;  $script:Profiller.kendi.ek_serbest_yol = 1
$script:Profiller.paylasilan.gelen_saatlik_uyanma = 30; $script:Profiller.paylasilan.ek_serbest_yol = 0
function Ayar-Yukle {
    $profil = 'kendi'
    $a = $null
    $y = Join-Path $script:KopruDizin 'ayar.json'
    if (Test-Path $y) {
        try { $a = Get-Content -LiteralPath $y -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Write-Host 'UYARI: ayar.json okunamadı, varsayılanlar kullanılıyor.' }
        if ($a -and $a.profil -and $script:Profiller.ContainsKey([string]$a.profil)) { $profil = [string]$a.profil }
    }
    $script:Profil = $profil
    $script:Ayar = @{}
    foreach ($k in $script:Profiller[$profil].Keys) {
        $v = $script:Profiller[$profil][$k]
        if ($a -and $null -ne $a.$k) { try { $n = [int]$a.$k; if ($n -ge 0) { $v = $n } } catch { } }
        $script:Ayar[$k] = $v
    }
}
Ayar-Yukle

function Yaz {
    param([string]$Metin)
    [void]$script:Cikti.Add($Metin)
    Write-Host $Metin
}

function Simdi { return (Get-Date).ToString($script:TarihBicim, $script:Kultur) }

function Bul-Tailscale {
    $c = Get-Command tailscale -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($kok in @($env:ProgramW6432, $env:ProgramFiles)) {
        if (-not $kok) { continue }
        $yol = Join-Path $kok 'Tailscale\tailscale.exe'
        if (Test-Path $yol) { return $yol }
    }
    return $null
}

# Tailscale'i pencere açmadan, zaman aşımıyla çalıştırır. Sonuç: Kod (-1 = Tailscale yok, 124 = zaman aşımı), Satirlar.
# Testler bu işlevi gölgeler.
function Calistir-Tailscale {
    param([string[]]$Arg, [int]$ZamanAsimiSn = 60)
    $b = Bul-Tailscale
    if (-not $b) { return [pscustomobject]@{ Kod = -1; Satirlar = @() } }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $b
    $psi.Arguments = (($Arg | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEndAsync()
    $err = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($ZamanAsimiSn * 1000)) {
        try { $p.Kill() } catch { }
        return [pscustomobject]@{ Kod = 124; Satirlar = @("zaman aşımı ($ZamanAsimiSn sn): eş kapalı ya da uykuda olabilir") }
    }
    $metin = $out.Result + "`n" + $err.Result
    return [pscustomobject]@{ Kod = $p.ExitCode; Satirlar = @($metin -split "`r?`n" | Where-Object { $_ -ne '' }) }
}

# İndirilenler klasörü taşınmış olabilir (ör. başka sürücü, OneDrive): Windows'un bildiği yeri sor (shell:Downloads), yoksa %USERPROFILE%\Downloads.
function Bul-Indirilenler {
    try {
        $y = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
        if ($y -and (Test-Path -LiteralPath $y)) { return $y }
    } catch { }
    return (Join-Path $env:USERPROFILE 'Downloads')
}

function Kopru-Yol {
    param([string]$Ad = '')
    $d = $script:KopruDizin
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    if ($Ad) { return (Join-Path $d $Ad) }
    return $d
}

function Kopru-AltDizin {
    param([string]$Ad)
    $d = Kopru-Yol $Ad
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    return $d
}

function Dns-Etiket {
    param([string]$DnsName)
    $e = ([string]$DnsName -split '\.')[0].ToLowerInvariant()
    if ($e -cmatch '^[a-z0-9-]{1,63}$') { return $e }
    return ''
}

function Al-Sha {
    param([string]$Yol)
    return (Get-FileHash -LiteralPath $Yol -Algorithm SHA256).Hash.ToLowerInvariant()
}

# Aynı adlı kilit (iki bekçi, iki gönderim aynı anda çalışmasın). Alınamazsa $null.
function Al-MetinSha { param([string]$Metin)
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($Metin))) -replace '-', '').ToLowerInvariant() } finally { $h.Dispose() }
}

function Al-Kilit {
    param([string]$Ad, [int]$BekleMs = 0)
    # Kilit adı köprü klasörüne bağlı: aynı klasöre tek bekçi/gönderici; testin geçici klasörü gerçek bekçiyle çakışmaz.
    $iz = (Al-MetinSha $script:KopruDizin.ToLowerInvariant()).Substring(0, 12)
    $m = New-Object System.Threading.Mutex($false, "Local\kopru_${Ad}_$iz")
    try { if ($m.WaitOne($BekleMs)) { return $m } } catch [System.Threading.AbandonedMutexException] { return $m }
    $m.Dispose()
    return $null
}
function Birak-Kilit { param($Kilit) if ($Kilit) { try { $Kilit.ReleaseMutex() } catch { }; $Kilit.Dispose() } }

# Deftere satır ekler; dosya o an başka süreçte açıksa birkaç kez dener (satır kaybolmasın).
function Defter-Ekle {
    param([hashtable]$Kayit)
    $Kayit['tarih'] = Simdi
    $satir = ($Kayit | ConvertTo-Json -Compress)
    $y = Kopru-Yol 'defter.jsonl'
    for ($i = 0; $i -lt 10; $i++) {
        try { Add-Content -LiteralPath $y -Value $satir -Encoding UTF8 -ErrorAction Stop; return $true } catch { Start-Sleep -Milliseconds 200 }
    }
    Write-Host "UYARI: deftere yazılamadı: $satir"
    return $false
}

function Defter-Oku {
    $y = Kopru-Yol 'defter.jsonl'
    if (-not (Test-Path $y)) { return @() }
    $sonuc = New-Object System.Collections.ArrayList
    foreach ($s in (Get-Content -LiteralPath $y -Encoding UTF8)) {
        if (-not $s.Trim()) { continue }
        try { [void]$sonuc.Add(($s | ConvertFrom-Json)) } catch { }
    }
    return $sonuc.ToArray()
}

function Es-Oku {
    $y = Kopru-Yol 'es.json'
    if (-not (Test-Path $y)) { return $null }
    try { return (Get-Content -LiteralPath $y -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

function Dur-Var { return (Test-Path (Kopru-Yol 'DUR')) }

# Dosya hâlâ yazılıyor mu? İki okuma arasında boyut değişmediyse ve sıfır değilse hazır.
function Dosya-Hazir {
    param([string]$Yol, [int]$BekleMs = 1000)
    try { $a = (Get-Item -LiteralPath $Yol).Length } catch { return $false }
    Start-Sleep -Milliseconds $BekleMs
    try { $b = (Get-Item -LiteralPath $Yol).Length } catch { return $false }
    return ($a -gt 0 -and $a -eq $b)
}

# Tarayıcıyla inen dosya Windows'ta Zone.Identifier akışı taşır; Taildrop ile gelen taşımaz (ölçüldü 2026-11-11).
function Tarayicidan-Mi {
    param([string]$Yol)
    try { return [bool](Get-Item -LiteralPath $Yol -Stream 'Zone.Identifier' -ErrorAction Stop) } catch { return $false }
}

# Dosyayı taşır; kilitliyse birkaç kez dener. Başaramazsa $false (dosya yerinde kalır, sonraki tura).
function Tasi {
    param([string]$Kaynak, [string]$Hedef)
    for ($i = 0; $i -lt 3; $i++) {
        try { Move-Item -LiteralPath $Kaynak -Destination $Hedef -ErrorAction Stop; return $true } catch { Start-Sleep -Milliseconds 500 }
    }
    return $false
}

# Mesajın ilk okuma_bayt kadarından başlık alanlarını okur (tur, konu, no, gonderen, ek ...). Gövdeyi yorumlamaz.
# Başlık "---" satırıyla biter; "---" yoksa başlık yok sayılır (tur = bilgi).
function Oku-Baslik {
    param([string]$Yol)
    $fs = [System.IO.File]::OpenRead($Yol)
    try {
        $buf = New-Object byte[] $script:Ayar.okuma_bayt
        $n = $fs.Read($buf, 0, $buf.Length)
    } finally { $fs.Close() }
    $metin = [System.Text.Encoding]::UTF8.GetString($buf, 0, $n).TrimStart([char]0xFEFF)
    $alan = @{}
    $bitti = $false
    foreach ($s in ($metin -split "`r?`n")) {
        if ($s -eq '---') { $bitti = $true; break }
        if ($s -cmatch '^([a-z_]{1,20}):\s*(.*)$') { $alan[$Matches[1]] = $Matches[2].Trim() }
    }
    if (-not $bitti) { $alan = @{} }
    if (@('istek', 'sonuc', 'bilgi') -notcontains $alan['tur']) { $alan['tur'] = 'bilgi' }
    return $alan
}
