<#
.SYNOPSIS
  Köprü: eşe tek mesaj (isteğe bağlı bir ek dosyayla) gönderir (Taildrop, `tailscale file cp`).
.DESCRIPTION
  Mesaj adı: kopru_<benimDns>_<NNN>_<konu>.md ; ilk satır `tur: istek|sonuc|bilgi`; başlık "---" ile biter.
  Mesaj en çok azami_bayt (64 KB); büyük içerik -Ek ile gider. Hata freni: saatte saatlik_tavan mesaj (ayar.json, 0 = sınırsız).
  DUR varsa gönderilmez (-Dur hariç); KAPALI varsa gönderilmez (-Ac, -Kapat, -Dur hariç). Her gönderim defter.jsonl'a yazılır. Aynı anda iki gönderim sırayla yürür (kilit).
  Çıkış: 0 gönderildi · 2 kullanım hatası / eş yok · 4 DUR · 5 köprü kapalı (KAPALI) · 6 boyut sınırı · 7 hata freni · 8 Tailscale gönderemedi · 9 kilit alınamadı
.PARAMETER Tur
  istek (cevap bekler) · sonuc (bir isteğin sonucu, cevap yazılmaz) · bilgi (cevap yazılmaz)
.PARAMETER Merhaba
  El sıkışma mesajını kendisi kurar (tur istek, konu merhaba).
.PARAMETER MerhabaTamam
  El sıkışma cevabı (tur sonuc, konu merhaba-tamam); -TanismaId gelen merhabadan alınır.
.PARAMETER TestMB
  Kanıt turu: 1, 10 ya da 100 MB rastgele test dosyası üretir ve ek olarak gönderir (konu dosya-testi).
.PARAMETER TestTemizle
  Yerel test\ ve gelen\ek\ altındaki test dosyalarını (test_<n>mb_<saat>.bin) siler; başka dosyaya dokunmaz.
.PARAMETER Kapat
  Köprüyü kapatır: yerel KAPALI kurar ve eşe 'kapat' mesajı yollar (eş kapalıysa mesaj gitmez, çıkış 8; yerel karar kalır). Tailscale ve RustDesk'e dokunmaz.
.PARAMETER Ac
  Köprüyü açar: yerel KAPALI'yı kaldırır, eşe 'ac' mesajı yollar (eşin bekçisi bunu bekler).
.PARAMETER Dur
  Eşe "dur" mesajı gönderir (eşin bekçisi durur, yeniden başlatma oradaki kullanıcının sözüyle).
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\kopru_gonder.ps1 -Merhaba
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\kopru_gonder.ps1 -Tur sonuc -Konu ping -Metin "doğrudan 15 ms"
#>
param(
    [ValidateSet('', 'istek', 'sonuc', 'bilgi')][string]$Tur = '',
    [string]$Konu = '',
    [string]$Metin = '',
    [string]$MetinDosyasi = '',
    [string]$Ek = '',
    [string]$Hedef = '',
    [switch]$Merhaba,
    [switch]$MerhabaTamam,
    [string]$TanismaId = '',
    [ValidateSet('evet', 'hayir')][string]$Uyanma = 'evet',
    [ValidateSet(0, 1, 10, 100)][int]$TestMB = 0,
    [switch]$TestTemizle,
    [switch]$Dur,
    [switch]$Kapat,
    [switch]$Ac,
    [switch]$Kuru,
    [switch]$SadeceIslevler
)
. (Join-Path $PSScriptRoot 'kopru_ortak.ps1')

# Sıradaki numara: sayac.txt ile defterdeki en yüksek giden numarasının büyüğü (+1). Bozuk sayaç defterden toparlanır.
function Sonraki-No {
    param($Defter)
    $n = 1
    $y = Kopru-Yol 'sayac.txt'
    if (Test-Path $y) {
        $ham = [string](Get-Content -LiteralPath $y -Raw -ErrorAction SilentlyContinue)
        $s = 0
        if ([int]::TryParse($ham.Trim(), [ref]$s) -and $s -gt 0) { $n = $s }
    }
    foreach ($k in $Defter) {
        if ($k.yon -ne 'giden' -or $k.durum -ne 'gitti') { continue }
        $s = 0
        if ([int]::TryParse([string]$k.no, [ref]$s) -and $s -ge $n) { $n = $s + 1 }
    }
    return $n
}

function Son-SaatGiden {
    param($Defter)
    $sinir = (Get-Date).AddMinutes(-60)
    $say = 0
    foreach ($k in $Defter) {
        if ($k.yon -ne 'giden' -or $k.durum -ne 'gitti') { continue }
        $t = [datetime]::MinValue
        if (-not [datetime]::TryParseExact([string]$k.tarih, $script:TarihBicim, $script:Kultur, 'None', [ref]$t)) { $say++; continue }
        if ($t -ge $sinir) { $say++ }
    }
    return $say
}

function Test-Uret {
    param([int]$MB)
    $d = Kopru-AltDizin 'test'
    $yol = Join-Path $d ('test_{0}mb_{1}.bin' -f $MB, (Get-Date).ToString('HHmmss', $script:Kultur))
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $buf = New-Object byte[] 1048576
    $fs = [System.IO.File]::Create($yol)
    try { for ($i = 0; $i -lt $MB; $i++) { $rng.GetBytes($buf); $fs.Write($buf, 0, $buf.Length) } } finally { $fs.Close() }
    return $yol
}

function Test-Temizle {
    $sil = @()
    foreach ($alt in @('test', 'gelen\ek')) {
        $d = Kopru-Yol $alt
        if (Test-Path $d) { $sil += Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -cmatch '^(\d{6}_)?test_\d{1,3}mb_\d{6}\.bin$' } }
    }
    foreach ($f in $sil) { Remove-Item -LiteralPath $f.FullName -Force }
    Yaz ("TEMIZLENDI: {0} test dosyası" -f $sil.Count)
    return 0
}

# paylasilan profilde ek yalnız depo ya da köprü klasöründen gider (ek_serbest_yol = 0).
function Ek-YoluUygun {
    param([string]$Yol)
    if ($script:Ayar.ek_serbest_yol -ne 0) { return $true }
    $tam = [System.IO.Path]::GetFullPath($Yol)
    foreach ($kok in @((Kopru-Yol), (Split-Path $PSScriptRoot -Parent))) {
        $k = [System.IO.Path]::GetFullPath($kok).TrimEnd('\') + '\'
        if ($tam.StartsWith($k, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Gonder-Calistir {
    param([string]$Tur, [string]$Konu, [string]$Metin, [string]$MetinDosyasi, [string]$Ek, [string]$Hedef,
          [switch]$Merhaba, [switch]$MerhabaTamam, [string]$TanismaId, [string]$Uyanma = 'evet', [int]$TestMB = 0, [switch]$Dur, [switch]$Kapat, [switch]$Ac, [switch]$Kuru)
    $es = Es-Oku
    if (-not $es) { Yaz 'HATA: es.json yok. Önce kopru_kesif.ps1 çalıştır.'; return 2 }
    $alici = if ($Hedef) { $Hedef.ToLowerInvariant() } else { [string]$es.dns }
    if (-not $alici) { Yaz 'HATA: eş seçilmemiş (birden çok aday). -Hedef <ad> ver ya da kopru_kesif.ps1 -Sec <ad>.'; return 2 }
    if ($Hedef -and (@($es.adaylar) -notcontains $alici)) { Yaz ("HATA: '{0}' keşfedilen adaylar arasında yok." -f $alici); return 2 }
    if ((Dur-Var) -and -not $Dur) { Yaz 'DURDU: DUR dosyası var, gönderilmedi.'; return 4 }
    if (@(@([bool]$Merhaba, [bool]$MerhabaTamam, [bool]$Dur, [bool]$Kapat, [bool]$Ac, ($TestMB -gt 0)) | Where-Object { $_ }).Count -gt 1) { Yaz 'HATA: -Merhaba, -MerhabaTamam, -Dur, -Kapat, -Ac, -TestMB birlikte kullanılmaz.'; return 2 }
    if ((Kapali-Var) -and -not ($Ac -or $Dur -or $Kapat)) { Yaz 'KAPALI: köprü kapalı, gönderilmedi. Açmak için kullanıcı "köprüyü aç" der (kopru_gonder.ps1 -Ac).'; return 5 }

    if ($Merhaba) {
        $Tur = 'istek'; $Konu = 'merhaba'
        $Metin = "tanisma_id: {0}`nnode_id: {1}`noturum_baslangic: {2}`nrehber_surumu: {3}`nuyanma: {4}" -f `
            ([guid]::NewGuid().ToString('N').Substring(0, 12)), $es.benimNodeId, (Simdi), $script:RehberSurumu, $Uyanma
    } elseif ($MerhabaTamam) {
        if ($TanismaId -cnotmatch '^[a-z0-9]{6,32}$') { Yaz 'HATA: -TanismaId gelen merhabadaki değer olmalı.'; return 2 }
        $Tur = 'sonuc'; $Konu = 'merhaba-tamam'
        $Metin = "tanisma_id: {0}`nnode_id: {1}`nrehber_surumu: {2}`nuyanma: {3}" -f $TanismaId, $es.benimNodeId, $script:RehberSurumu, $Uyanma
    } elseif ($Kapat) {
        $Tur = 'bilgi'; $Konu = 'kapat'
        if (-not $Metin) { $Metin = 'Kullanıcı köprüyü kapattı. Açmak için iki taraftan biri "köprüyü aç" der.' }
        $karar = [datetime]::UtcNow; $Metin = "karar_zamani: $($karar.ToString('o', $script:Kultur))`n$Metin"
    } elseif ($Ac) {
        $Tur = 'bilgi'; $Konu = 'ac'
        if (-not $Metin) { $Metin = 'Kullanıcı köprüyü açtı.' }
        $karar = [datetime]::UtcNow; $Metin = "karar_zamani: $($karar.ToString('o', $script:Kultur))`n$Metin"
    } elseif ($Dur) {
        $Tur = 'bilgi'; $Konu = 'dur'
        if (-not $Metin) { $Metin = 'Kullanıcı köprüyü durdurdu.' }
    } elseif ($TestMB -gt 0) {
        if (-not $Tur) { $Tur = 'bilgi' }
        $Konu = 'dosya-testi'
    }
    if (-not $Tur) { Yaz 'HATA: -Tur istek|sonuc|bilgi gerekli.'; return 2 }
    if ($Konu -cnotmatch $script:KonuDesen) { Yaz 'HATA: -Konu yalnız küçük harf, rakam ve - (en çok 30).'; return 2 }
    if ($MetinDosyasi) {
        if (-not (Test-Path -LiteralPath $MetinDosyasi)) { Yaz 'HATA: metin dosyası yok.'; return 2 }
        $Metin = Get-Content -LiteralPath $MetinDosyasi -Raw -Encoding UTF8
    }

    $kilit = Al-Kilit -Ad 'gonder' -BekleMs 120000
    if (-not $kilit) { Yaz 'HATA: başka bir gönderim sürüyor (2 dk beklendi).'; return 9 }
    try {
        $defter = Defter-Oku
        if ($script:Ayar.saatlik_tavan -gt 0 -and -not ($Dur -or $Kapat -or $Ac) -and (Son-SaatGiden $defter) -ge $script:Ayar.saatlik_tavan) {
            Yaz ("DURDU: son 60 dakikada {0} mesaj gitti (hata freni). Kullanıcıya sor: sınırı kaldırmak için ayar.json'a ""saatlik_tavan"": 0." -f $script:Ayar.saatlik_tavan)
            return 7
        }
        if ($TestMB -gt 0 -and -not $Kuru) { $Ek = Test-Uret -MB $TestMB }
        $ekSatir = ''; $ekSha = ''; $ekBayt = 0
        if ($Ek -and -not $Kuru) {
            if (-not (Test-Path -LiteralPath $Ek -PathType Leaf)) { Yaz 'HATA: ek dosyası yok.'; return 2 }
            $ekAd = Split-Path $Ek -Leaf
            if ($ekAd -cnotmatch $script:EkAdDesen) { Yaz 'HATA: ek adı yalnız harf, rakam, . _ - (en çok 80). Türkçe/boşluklu adı önce kopyalayıp yeniden adlandır.'; return 2 }
            if (-not (Ek-YoluUygun $Ek)) { Yaz 'HATA: paylasilan profilde ek yalnız depo ya da köprü klasöründen gider (ayar ek_serbest_yol).'; return 2 }
            $ekBayt = (Get-Item -LiteralPath $Ek).Length
            if ($script:Ayar.ek_azami_mb -gt 0 -and $ekBayt -gt ([int64]$script:Ayar.ek_azami_mb * 1MB)) { Yaz ("HATA: ek {0} MB sınırını aşıyor (ayar ek_azami_mb)." -f $script:Ayar.ek_azami_mb); return 6 }
            $ekSha = Al-Sha $Ek
            $ekSatir = "ek: {0} sha256={1} bayt={2}" -f $ekAd, $ekSha, $ekBayt
        }

        $no = Sonraki-No $defter
        if ($no -gt 999) { Yaz 'HATA: numara 999u geçti; yeni tanışma gerekir (KOPRU.md "Sıfırlama").'; return 2 }
        $nnn = '{0:D3}' -f $no
        $ad = 'kopru_{0}_{1}_{2}.md' -f $es.benimDns, $nnn, $Konu
        $baslik = @("tur: $Tur", "konu: $Konu", "no: $nnn", "gonderen: $($es.benimDns)")
        if ($ekSatir) { $baslik += $ekSatir }
        $icerik = (($baslik + '---' + $Metin) -join "`n") + "`n"
        $bayt = [System.Text.Encoding]::UTF8.GetByteCount($icerik)
        if ($bayt -gt $script:Ayar.azami_bayt) { Yaz ("HATA: mesaj {0} bayt, {1} bayt sınırı aşıldı. Büyük içerik -Ek ile gider." -f $bayt, $script:Ayar.azami_bayt); return 6 }
        if ($Kuru) { Yaz ("KURU: {0} -> {1} ({2} bayt, tur {3})" -f $ad, $alici, $bayt, $Tur); return 0 }
        # Aç/kapat: yerel karar gönderimden ÖNCE uygulanır (kullanıcının sözü yerelde her durumda geçerli); eş kapalıysa mesaj gitmez.
        if ($Kapat) { Set-Content -LiteralPath (Kopru-Yol 'KAPALI') -Value ('kullanıcı kapattı ' + (Simdi)) -Encoding UTF8; Karar-Yaz $karar; Yaz 'KAPANDI: yerel KAPALI kuruldu; eşe "kapat" gidiyor. Tailscale ve RustDesk açık kalır.' }
        if ($Ac) { if (Kapali-Var) { Remove-Item -LiteralPath (Kopru-Yol 'KAPALI') -Force -ErrorAction SilentlyContinue }; Karar-Yaz $karar; Yaz 'ACILDI: yerel KAPALI kaldırıldı; eşe "ac" gidiyor.' }

        $yol = Join-Path (Kopru-AltDizin 'giden') $ad
        [System.IO.File]::WriteAllText($yol, $icerik, (New-Object System.Text.UTF8Encoding($false)))
        $sha = Al-Sha $yol
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        if ($Ek) {
            $dahaOnce = @($defter | Where-Object { $_.yon -eq 'giden' -and $_.durum -in @('gitti', 'ek-gitti') -and $_.ek_sha -eq $ekSha -and $_.alici -eq $alici })
            if ($dahaOnce.Count -eq 0) {
                $zaman = 60 + [int]($ekBayt / 1MB) * 10
                $r = Calistir-Tailscale -Arg @('file', 'cp', $Ek, "${alici}:") -ZamanAsimiSn $zaman
                if ($r.Kod -ne 0) {
                    [void](Defter-Ekle @{ yon = 'giden'; ad = (Split-Path $Ek -Leaf); alici = $alici; durum = 'hata'; hata = (($r.Satirlar | Select-Object -First 2) -join ' ') })
                    Yaz ("HATA: ek gönderilemedi: {0}. Eş kapalı ya da uykuda olabilir; Taildrop bekletmez. Eş açılınca aynı komutu yeniden çalıştır (bak: kopru_durum.ps1 -Ping)." -f (($r.Satirlar | Select-Object -First 2) -join ' ')); return 8
                }
                [void](Defter-Ekle @{ yon = 'giden'; ad = (Split-Path $Ek -Leaf); alici = $alici; durum = 'ek-gitti'; ek_sha = $ekSha })
            }
        }
        $r = Calistir-Tailscale -Arg @('file', 'cp', $yol, "${alici}:") -ZamanAsimiSn 60
        $sw.Stop()
        if ($r.Kod -ne 0) {
            [void](Defter-Ekle @{ yon = 'giden'; ad = $ad; alici = $alici; sha = $sha; durum = 'hata'; hata = (($r.Satirlar | Select-Object -First 2) -join ' ') })
            Yaz ("HATA: gönderilemedi: {0}. Eş kapalı ya da uykuda olabilir; Taildrop bekletmez. Eş açılınca aynı komutu yeniden çalıştır, numara değişmez (bak: kopru_durum.ps1 -Ping). Ek gittiyse yeniden yüklenmez." -f (($r.Satirlar | Select-Object -First 2) -join ' '))
            if ($Kapat -or $Ac) { Yaz 'NOT: yerel karar uygulandı ama eşe ulaşmadı; eş açılınca aynı komutu (-Kapat ya da -Ac) yeniden çalıştır.' }
            return 8
        }
        Set-Content -LiteralPath (Kopru-Yol 'sayac.txt') -Value ($no + 1)
        [void](Defter-Ekle @{ yon = 'giden'; ad = $ad; alici = $alici; no = $nnn; konu = $Konu; tur = $Tur; sha = $sha; sure_ms = $sw.ElapsedMilliseconds; durum = 'gitti'; ek_sha = $ekSha })
        Yaz ("GONDERILDI ad={0} sha={1} sure_ms={2}{3}" -f $ad, $sha.Substring(0, 12), $sw.ElapsedMilliseconds, $(if ($ekSatir) { " $ekSatir" } else { '' }))
        return 0
    } finally { Birak-Kilit $kilit }
}

if ($SadeceIslevler) { return }
if ($TestTemizle) { exit (Test-Temizle) }
exit (Gonder-Calistir -Tur $Tur -Konu $Konu -Metin $Metin -MetinDosyasi $MetinDosyasi -Ek $Ek -Hedef $Hedef `
    -Merhaba:$Merhaba -MerhabaTamam:$MerhabaTamam -TanismaId $TanismaId -Uyanma $Uyanma -TestMB $TestMB -Dur:$Dur -Kapat:$Kapat -Ac:$Ac -Kuru:$Kuru)
