<#
.SYNOPSIS
  Köprü bekçisi: eşten mesaj gelince onu yerel gelen\ klasörüne alır, yolunu yazar ve ÇIKAR.
.DESCRIPTION
  Ajan bunu ARKA PLAN komutu olarak çalıştırır; betik çıkınca ajan (Claude Code) uyanır ve mesajı okur.
  Mesajı ÇALIŞTIRMAZ; yalnız taşır, sha256 alır, deftere yazar. Ağ, duvar, ayar değiştirmez.
  Windows'ta Taildrop gelen dosyayı kendisi İndirilenler'e koyar (ölçüldü); bekçi yalnız orayı tarar.
  Kabul edilen ad: kopru_<eş>_<NNN>_<konu>.md (çakışmada Windows'un eklediği " (1)" de tanınır), en çok azami_bayt.
  Tarayıcıyla inmiş dosya (Zone.Identifier taşır) eş mesajı sayılmaz. Yarım dosya alınmaz.
  Defterde aynı gönderen+NNN+sha varsa yeniden işlenmez (gelen\tekrar\ altına konur).
  Konu "dur" ise yerel DUR kurulur, köprü durur. Konu "kapat" ise yerel KAPALI kurulur (ajan uyanır, kullanıcıya söyler).
  KAPALI varken bekçi yalnız eşin "ac", "kapat" ve "dur" mesajını alır; aç/kapat yalnız buradaki son karardan yeniyse uygulanır; öbür mesajlar İndirilenler'de bekler, açılınca işlenir. Aynı anda tek bekçi çalışır.
  Eş henüz bulunmadıysa (es.json yok) bekçi 30 sn arayla keşfi kendisi dener; öbür bilgisayar kurulunca kendiliğinden bulur.
  Çıkış: 0 yeni mesaj (ya da -EkMesaj ile ek alındı) · 2 kullanım hatası · 3 zaman aşımı / ek henüz gelmedi · 4 DUR · 6 başka bekçi zaten çalışıyor
.PARAMETER EkMesaj
  Eki sonradan gelen bir mesajın yolu: yalnız o mesajın ekini (en çok 10 dk) bekler, alır, çıkar.
.EXAMPLE
  powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File araclar\kopru_bekle.ps1
#>
param(
    [int]$AzamiDakika = -1,
    [int]$AralikSaniye = 10,
    [string]$Indirilenler = '',
    [int]$EkBekleSaniye = -1,
    [string]$EkMesaj = '',
    [int]$KesifAralikSaniye = 30,
    [switch]$SadeceIslevler
)
$benimSadece = [bool]$SadeceIslevler   # kesif nokta ile yüklenince kendi -SadeceIslevler'ini bu kapsama yazar
. (Join-Path $PSScriptRoot 'kopru_kesif.ps1') -SadeceIslevler

function Ad-Desen {
    param([string[]]$Esler)
    $g = ($Esler | Where-Object { $_ } | Select-Object -Unique | ForEach-Object { [regex]::Escape($_) }) -join '|'
    return ('^kopru_(?<g>' + $g + ')_(?<n>\d{3})_(?<k>[a-z0-9-]{1,30})( \(\d+\))?\.md$')
}

# Ek: başlıktaki ad, bayt ve sha'ya UYAN dosyayı (ad ya da "ad (n)") bulur; uyanı taşır, uymayana dokunmaz.
function Isle-Ek {
    param([string]$Satir, [string]$Kok, [int]$BekleSaniye)
    if ($Satir -cnotmatch '^(?<ad>[A-Za-z0-9._-]{1,80}) sha256=(?<sha>[0-9a-f]{64}) bayt=(?<b>\d+)$') { return 'EK: başlık bozuk, alınmadı' }
    $ad = $Matches['ad']; $beklenen = $Matches['sha']; $bayt = [int64]$Matches['b']
    $govde = [System.IO.Path]::GetFileNameWithoutExtension($ad); $uzanti = [System.IO.Path]::GetExtension($ad)
    $desen = '^' + [regex]::Escape($govde) + '( \(\d+\))?' + [regex]::Escape($uzanti) + '$'
    $bitis = (Get-Date).AddSeconds($BekleSaniye)
    do {
        foreach ($f in @(Get-ChildItem -LiteralPath $Kok -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -cmatch $desen -and $_.Length -eq $bayt })) {
            if (Tarayicidan-Mi $f.FullName) { continue }
            if (-not (Dosya-Hazir -Yol $f.FullName)) { continue }
            if ((Al-Sha $f.FullName) -ne $beklenen) { continue }
            $hedefDizin = Kopru-AltDizin 'gelen\ek'
            $hedef = Join-Path $hedefDizin $ad
            if (Test-Path -LiteralPath $hedef) { $hedef = Join-Path $hedefDizin ((Get-Date).ToString('HHmmss', $script:Kultur) + '_' + $ad) }
            if (-not (Tasi $f.FullName $hedef)) { return ("EK: {0} bulundu ama taşınamadı (kilitli); yerinde: {1}" -f $ad, $f.FullName) }
            return ("EK: {0} sha esit bayt={1}" -f $hedef, $bayt)
        }
        if ((Get-Date) -ge $bitis) { break }
        Start-Sleep -Seconds 2
    } while ($true)
    return ("EK: {0} henüz gelmedi ({1} sn beklendi). Sonra al: kopru_bekle.ps1 -EkMesaj <mesaj yolu>" -f $ad, $BekleSaniye)
}

function Tara-Bir {
    param($Es, [string]$Indirilenler, [System.Collections.ArrayList]$Anahtarlar, [string[]]$YalnizKonu = @())
    $desen = Ad-Desen -Esler @(@($Es.adaylar) + $Es.dns)
    $gelen = Kopru-AltDizin 'gelen'
    $yeni = @()
    if (-not (Test-Path -LiteralPath $Indirilenler)) { return $yeni }
    $dosyalar = @(Get-ChildItem -LiteralPath $Indirilenler -File -ErrorAction SilentlyContinue | Where-Object { $_.Name.StartsWith('kopru_') -and $_.Name.EndsWith('.md') } | Sort-Object Name)
    foreach ($f in $dosyalar) {
        if ($f.Name -cnotmatch $desen) { continue }
        $g = $Matches['g']; $n = $Matches['n']; $k = $Matches['k']
        if ($YalnizKonu.Count -gt 0 -and $YalnizKonu -notcontains $k) { continue }   # köprü kapalı: yalnız 'ac'/'kapat' alınır, öbürleri yerinde bekler
        if ($script:Atlanan.ContainsKey($f.FullName)) { continue }
        if (Tarayicidan-Mi $f.FullName) { $script:Atlanan[$f.FullName] = 1; Yaz ("ATLANDI (tarayıcıyla inmiş, eş mesajı değil): {0}" -f $f.Name); continue }
        if ($f.Length -gt $script:Ayar.azami_bayt) { $script:Atlanan[$f.FullName] = 1; Yaz ("ATLANDI ({0} bayt üstü): {1}" -f $script:Ayar.azami_bayt, $f.Name); continue }
        if (-not (Dosya-Hazir -Yol $f.FullName)) { continue }
        $sha = Al-Sha $f.FullName
        $anahtar = "$g|$n|$sha"
        if ($Anahtarlar -contains $anahtar) {
            $t = Join-Path (Kopru-AltDizin 'gelen\tekrar') ((Get-Date).ToString('HHmmssfff', $script:Kultur) + '_' + $f.Name)
            if (Tasi $f.FullName $t) { Yaz ("TEKRAR (daha önce işlendi, atlandı): {0}" -f $f.Name) }
            continue
        }
        $hedef = Join-Path $gelen $f.Name
        if (Test-Path -LiteralPath $hedef) { $hedef = Join-Path $gelen ((Get-Date).ToString('HHmmss', $script:Kultur) + '_' + $f.Name) }
        if (-not (Tasi $f.FullName $hedef)) { continue }   # kilitli: sonraki tura
        $b = Oku-Baslik -Yol $hedef
        [void](Defter-Ekle @{ yon = 'gelen'; ad = $f.Name; gonderen = $g; no = $n; konu = $k; tur = $b['tur']; sha = $sha; anahtar = $anahtar })
        [void]$Anahtarlar.Add($anahtar)
        $yeni += [pscustomobject]@{ Yol = $hedef; Tur = $b['tur']; Gonderen = $g; No = $n; Konu = $k; Ek = $b['ek'] }
    }
    return $yeni
}

function Son-SaatGelen {
    param($Defter)
    $sinir = (Get-Date).AddMinutes(-60)
    $say = 0
    foreach ($k in $Defter) {
        if ($k.yon -ne 'gelen') { continue }
        $t = [datetime]::MinValue
        if ([datetime]::TryParseExact([string]$k.tarih, $script:TarihBicim, $script:Kultur, 'None', [ref]$t) -and $t -ge $sinir) { $say++ }
    }
    return $say
}

function Bekle-Calistir {
    param([int]$AzamiDakika = -1, [int]$AralikSaniye = 10, [string]$Indirilenler, [int]$EkBekleSaniye = -1, [string]$EkMesaj = '', [int]$KesifAralikSaniye = 30)
    if (-not $Indirilenler) { $Indirilenler = Bul-Indirilenler }
    if ($AzamiDakika -lt 0) { $AzamiDakika = $script:Ayar.bekle_azami_dakika }
    if ($EkBekleSaniye -lt 0) { $EkBekleSaniye = $script:Ayar.ek_bekle_saniye }
    $script:Atlanan = @{}
    if ($EkMesaj) {
        if (-not (Test-Path -LiteralPath $EkMesaj)) { Yaz 'HATA: mesaj yok.'; return 2 }
        $b = Oku-Baslik -Yol $EkMesaj
        if (-not $b['ek']) { Yaz 'HATA: bu mesajda ek satırı yok.'; return 2 }
        $sonuc = Isle-Ek -Satir $b['ek'] -Kok $Indirilenler -BekleSaniye 600
        Yaz $sonuc
        if ($sonuc -match 'sha esit') { return 0 } else { return 3 }
    }
    $kilit = Al-Kilit -Ad 'bekle'
    if (-not $kilit) { Yaz 'ZATEN CALISIYOR: başka bir bekçi açık; ikincisi gerekmez.'; return 6 }
    try {
        $bitis = (Get-Date).AddMinutes($AzamiDakika)
        # Eş henüz yoksa (öbür bilgisayar kurulmadı, Send Files kapalı) bekçi keşfi arayla kendisi dener.
        $es = Es-Oku
        $esler = @()
        if ($es) { $esler = @(@($es.adaylar) + $es.dns | Where-Object { $_ } | Select-Object -Unique) }
        if ($esler.Count -eq 0) { Yaz ('ES YOK: keşif {0} sn arayla yeniden denenecek (öbür bilgisayar kurulunca kendiliğinden bulunur).' -f $KesifAralikSaniye) }
        while ($esler.Count -eq 0) {
            if (Dur-Var) { Yaz 'DURDU: DUR dosyası var.'; return 4 }
            if ((Get-Date) -ge $bitis) { Yaz ('ZAMAN ASIMI: {0} dk içinde eş bulunamadı; bekçiyi yeniden başlat.' -f $AzamiDakika); return 3 }
            Start-Sleep -Seconds $KesifAralikSaniye
            [void](Kesif-Calistir)
            $es = Es-Oku
            if ($es) { $esler = @(@($es.adaylar) + $es.dns | Where-Object { $_ } | Select-Object -Unique) }
            if ($esler.Count -gt 0) { Yaz ('ES BULUNDU: ' + ($esler -join ',')) }
        }
        $defter = Defter-Oku
        $anahtarlar = New-Object System.Collections.ArrayList
        foreach ($k in $defter) { if ($k.yon -eq 'gelen' -and $k.anahtar) { [void]$anahtarlar.Add([string]$k.anahtar) } }
        Yaz ("BEKLIYOR es={0} bitis={1}" -f ($esler -join ','), $bitis.ToString('HH:mm:ss', $script:Kultur))
        if (Kapali-Var) { Yaz 'KAPALI: köprü kullanıcı isteğiyle kapalı; yalnız eşin "ac" ve acil "dur" mesajı alınır, öbür mesajlar açılınca işlenir.' }
        while ($true) {
            if (Dur-Var) { Yaz 'DURDU: DUR dosyası var. Yeniden başlatma kullanıcının sözüyle (DUR dosyasını o siler).'; return 4 }
            $yalniz = @(if (Kapali-Var) { 'ac', 'kapat', 'dur' })   # kapalıyken de acil 'dur' alınır
            $yeni = @(Tara-Bir -Es $es -Indirilenler $Indirilenler -Anahtarlar $anahtarlar -YalnizKonu $yalniz)
            if ($yeni.Count -gt 0) {
                # Hata freni: saatte çok uyanma olduysa birkaç dakika daha toplayıp tek seferde uyandır.
                $tavan = $script:Ayar.gelen_saatlik_uyanma
                if ($tavan -gt 0 -and (Son-SaatGelen (Defter-Oku)) -gt $tavan) {
                    Yaz ("UYARI: son 60 dakikada {0}'dan çok mesaj geldi (hata freni); 5 dk toplanıp birlikte veriliyor." -f $tavan)
                    $topla = (Get-Date).AddMinutes(5)
                    while ((Get-Date) -lt $topla -and -not (Dur-Var)) { Start-Sleep -Seconds $AralikSaniye; $yeni += @(Tara-Bir -Es $es -Indirilenler $Indirilenler -Anahtarlar $anahtarlar -YalnizKonu $yalniz) }
                }
                foreach ($m in ($yeni | Sort-Object Gonderen, No)) {
                    Yaz ("YENI: {0} tur={1} gonderen={2} no={3} konu={4}" -f $m.Yol, $m.Tur, $m.Gonderen, $m.No, $m.Konu)
                    if ($m.Ek) { Yaz (Isle-Ek -Satir $m.Ek -Kok $Indirilenler -BekleSaniye $EkBekleSaniye) }
                }
                if (@($yeni | Where-Object { $_.Konu -eq 'dur' }).Count -gt 0) {
                    Set-Content -LiteralPath (Kopru-Yol 'DUR') -Value ('eşten dur mesajı ' + (Simdi))
                    Yaz 'DURDU: eş dur mesajı gönderdi; yerel DUR kuruldu. Yeniden başlatma yalnız kullanıcının sözüyle.'
                    return 4
                }
                # Aç/kapat: mesajdaki karar zamanı yereldeki son karardan yeniyse uygulanır; en yeni karar kazanır.
                $anahtar = $null
                foreach ($m in @($yeni | Where-Object { $_.Konu -in @('ac', 'kapat') })) {
                    $z = [datetime]::MinValue
                    $ham = [string](Get-Content -LiteralPath $m.Yol -Raw -Encoding UTF8 -ErrorAction SilentlyContinue)
                    if ($ham -match 'karar_zamani: (\S+)') { [void][datetime]::TryParse($Matches[1], $script:Kultur, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$z) }
                    $z = $z.ToUniversalTime()
                    if (-not $anahtar -or $z -gt $anahtar.Zaman) { $anahtar = [pscustomobject]@{ Konu = $m.Konu; Zaman = $z } }
                }
                if ($anahtar) {
                    if ($anahtar.Zaman -le (Karar-Oku)) {
                        Yaz ("ESKI KARAR: eşin '{0}' mesajı buradaki son karardan eski, uygulanmadı." -f $anahtar.Konu)
                    } elseif ($script:Ayar.es_ac_kapat -eq 0) {
                        Yaz ("ISTEK: eş köprüyü '{0}' istiyor (es_ac_kapat 0: eş kendisi açıp kapatamaz). Kullanıcıya sor; onaylarsa kopru_gonder.ps1 -{1}." -f $anahtar.Konu, $(if ($anahtar.Konu -eq 'ac') { 'Ac' } else { 'Kapat' }))
                    } elseif ($anahtar.Konu -eq 'ac') {
                        if (Kapali-Var) { Remove-Item -LiteralPath (Kopru-Yol 'KAPALI') -Force -ErrorAction SilentlyContinue }
                        Karar-Yaz $anahtar.Zaman
                        Yaz 'ACILDI: eş köprüyü açtı; KAPALI kaldırıldı. Bekçiyi yeniden kur, kopru_durum.ps1 -Ping ile bak, kullanıcıya söyle.'
                    } else {
                        Set-Content -LiteralPath (Kopru-Yol 'KAPALI') -Value ('eşten kapat mesajı ' + (Simdi)) -Encoding UTF8
                        Karar-Yaz $anahtar.Zaman
                        Yaz 'KAPANDI: eş köprüyü kapattı; yerel KAPALI kuruldu. Kullanıcıya söyle; bekçiyi yeniden kur (yalnız "ac" ve "dur" bekler).'
                    }
                }
                Yaz ("SAAT: {0}" -f (Get-Date).ToString('HH:mm:ss', $script:Kultur))
                return 0
            }
            if ((Get-Date) -ge $bitis) { break }
            Start-Sleep -Seconds $AralikSaniye
        }
        Yaz ("ZAMAN ASIMI: {0} dk içinde mesaj gelmedi; bekçiyi yeniden başlat." -f $AzamiDakika)
        return 3
    } finally { Birak-Kilit $kilit }
}

if ($benimSadece) { return }
exit (Bekle-Calistir -AzamiDakika $AzamiDakika -AralikSaniye $AralikSaniye -Indirilenler $Indirilenler -EkBekleSaniye $EkBekleSaniye -EkMesaj $EkMesaj -KesifAralikSaniye $KesifAralikSaniye)
