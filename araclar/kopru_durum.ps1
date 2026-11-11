<#
.SYNOPSIS
  Köprü durumu (YALNIZ OKUR): eş kim, bekçi çalışıyor mu, DUR var mı, ayar profili, son mesajlar.
.DESCRIPTION
  Kapanış mesajının ve "köprü çalışıyor mu?" sorusunun tek komutu. Ağa bir şey göndermez;
  -Ping verilirse eşe 4 Tailscale ping'i atar ve yolu yazar (doğrudan / röle).
  Çıkış: 0 köprü hazır (eş var, bekçi çalışıyor, DUR yok) · 1 eksik var (satırlarda yazılı)
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\kopru_durum.ps1
#>
param([int]$Son = 6, [switch]$Ping, [switch]$SadeceIslevler)
. (Join-Path $PSScriptRoot 'kopru_ortak.ps1')

function Durum-Calistir {
    param([int]$Son = 6)
    $tamam = $true
    $es = Es-Oku
    if ($es -and $es.dns) { Yaz ("ES: {0} · ben: {1} · keşif {2}" -f $es.dns, $es.benimDns, $es.tarih) }
    else { Yaz 'ES: yok (kopru_kesif.ps1 çalıştır)'; $tamam = $false }
    $k = Al-Kilit -Ad 'bekle'
    if ($k) { Birak-Kilit $k; Yaz 'BEKCI: çalışmıyor (kopru_bekle.ps1 arka planda kurulmalı)'; $tamam = $false }
    else { Yaz 'BEKCI: çalışıyor' }
    if (Dur-Var) { Yaz 'DUR: VAR (köprü durdu; yeniden başlatma kullanıcının sözüyle)'; $tamam = $false } else { Yaz 'DUR: yok' }
    Yaz ("AYAR: profil {0} · saatlik_tavan {1} · gelen_saatlik_uyanma {2} · ek_azami_mb {3}" -f $script:Profil, $script:Ayar.saatlik_tavan, $script:Ayar.gelen_saatlik_uyanma, $script:Ayar.ek_azami_mb)
    $d = @(Defter-Oku)
    $giden = @($d | Where-Object { $_.yon -eq 'giden' -and $_.durum -eq 'gitti' }).Count
    $gelen = @($d | Where-Object { $_.yon -eq 'gelen' }).Count
    $hata = @($d | Where-Object { $_.durum -eq 'hata' }).Count
    Yaz ("DEFTER: giden {0} · gelen {1} · gönderim hatası {2}" -f $giden, $gelen, $hata)
    foreach ($s in ($d | Where-Object { $_.ad -like 'kopru_*' } | Select-Object -Last $Son)) {
        Yaz ("  {0} {1,-5} {2} {3}" -f $s.tarih, $s.yon, $s.ad, $(if ($s.durum -eq 'hata') { 'HATA' } else { '' }))
    }
    if ($Ping -and $es -and $es.dns) {
        $r = Calistir-Tailscale -Arg @('ping', '--until-direct=false', '--c=4', [string]$es.dns) -ZamanAsimiSn 30
        $pong = @($r.Satirlar | Where-Object { $_ -like 'pong *' })
        foreach ($s in $pong) { Yaz ("PING: {0}" -f $s) }
        if ($pong.Count -eq 0) { Yaz 'PING: yanıt yok (eş kapalı ya da uykuda olabilir)'; $tamam = $false }
        elseif ($pong[-1] -match 'via DERP') { Yaz 'YOL: röle (DERP; çalışır ama yavaş olabilir)' }
        elseif ($pong[-1] -match 'via (\d{1,3}(\.\d{1,3}){3}|\[[0-9a-fA-F:]+\]):\d+ in') { Yaz 'YOL: doğrudan' }
        else { Yaz 'YOL: bilinmiyor (peer-relay ya da yeni bir biçim; satıra bak)' }
    }
    Yaz $(if ($tamam) { 'SONUC: köprü hazır' } else { 'SONUC: eksik var (yukarıda)' })
    if ($tamam) { return 0 } else { return 1 }
}

if ($SadeceIslevler) { return }
exit (Durum-Calistir -Son $Son -Ping:$Ping)
