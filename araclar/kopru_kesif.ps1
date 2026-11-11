<#
.SYNOPSIS
  Köprü keşfi: aynı Tailscale hesabındaki öbür Windows bilgisayarı bulur, kimliğini yerel es.json'a yazar.
.DESCRIPTION
  YALNIZ OKUR (`tailscale status --json`); ağ, duvar, ayar değiştirmez. Yazdığı tek dosya yerel es.json.
  Süzgeç iki adım: aday = aynı kullanıcı (UserID) + OS windows + dosya gönderilebilir (NoFileSharingReason boş);
  sonra çevrimiçi olan. Çıkış kodu:
    0  tek eş bulundu, es.json yazıldı
    2  aday yok (Tailscale yok / kapalı / öbür bilgisayar listede yok / dosya gönderimi kapalı); neden yazılır
    3  aday var ama çevrimdışı (öbür bilgisayar kapalı ya da uykuda); es.json yine yazılır, bekçi kurulabilir
    5  birden çok aday: hepsine merhaba gönderilir, cevap veren -Sec ile seçilir
.PARAMETER Sec
  Birden çok aday varken seçilen eşin DNS etiketi (ör. ofis-pc).
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\kopru_kesif.ps1
#>
param(
    [string]$Sec = '',
    [switch]$SadeceIslevler
)
. (Join-Path $PSScriptRoot 'kopru_ortak.ps1')

function Al-Durum {
    $r = Calistir-Tailscale -Arg @('status', '--json')
    if ($r.Kod -eq -1) { return $null }
    $satirlar = @($r.Satirlar)
    $bas = -1
    for ($i = 0; $i -lt $satirlar.Count; $i++) { if ($satirlar[$i].TrimStart().StartsWith('{')) { $bas = $i; break } }
    if ($bas -lt 0) { return 'bozuk' }
    try { return (($satirlar[$bas..($satirlar.Count - 1)] -join "`n") | ConvertFrom-Json) } catch { return 'bozuk' }
}

function Kesif-Calistir {
    param([string]$Sec = '')
    $d = Al-Durum
    if ($null -eq $d) { Yaz 'SONUC: Tailscale kurulu değil (REHBER Adım 1).'; return 2 }
    if ($d -is [string]) { Yaz 'SONUC: Tailscale durumu okunamadı (Tailscale çalışıyor mu?).'; return 2 }
    if ([string]$d.BackendState -ne 'Running') {
        Yaz ("SONUC: Tailscale açık değil ya da giriş yapılmamış (durum: {0})." -f $d.BackendState); return 2
    }
    $self = $d.Self
    $benimDns = Dns-Etiket $self.DNSName
    if (-not $benimDns) { $benimDns = ([string]$self.ID).ToLowerInvariant() -replace '[^a-z0-9]', '' ; $benimDns = $benimDns.Substring(0, [Math]::Min(8, $benimDns.Length)) }

    $ayniHesapWin = @()
    if ($d.Peer) {
        foreach ($p in $d.Peer.PSObject.Properties) {
            $v = $p.Value
            if ([string]$v.UserID -ne [string]$self.UserID) { continue }
            if ([string]$v.OS -ne 'windows') { continue }
            $ayniHesapWin += $v
        }
    }
    if ($ayniHesapWin.Count -eq 0) {
        Yaz 'SONUC: Aynı hesapta başka Windows bilgisayar görünmüyor. Öbür bilgisayarda Tailscale açık ve aynı hesapla giriş yapılmış mı?'
        return 2
    }
    $dosyaOlur = @($ayniHesapWin | Where-Object { -not $_.NoFileSharingReason })
    if ($dosyaOlur.Count -eq 0) {
        foreach ($v in $ayniHesapWin) { Yaz ("  {0}: dosya gönderilemiyor ({1})" -f (Dns-Etiket $v.DNSName), $v.NoFileSharingReason) }
        Yaz 'SONUC: Öbür bilgisayar var ama dosya gönderimi kapalı. Yönetim sayfasında Send Files (Taildrop) açılmalı (REHBER Adım 6a).'
        return 2
    }
    $cevrimici = @($dosyaOlur | Where-Object { $_.Online -eq $true })
    # Seçim: çevrimiçi tek aday; yoksa (hepsi kapalı) tek aday; birden çoksa -Sec ya da önceki seçim korunur.
    $havuz = @(if ($cevrimici.Count -gt 0) { $cevrimici } else { $dosyaOlur })
    $onceki = Es-Oku
    $istenen = if ($Sec) { $Sec.ToLowerInvariant() } elseif ($onceki -and $onceki.dns) { [string]$onceki.dns } else { '' }
    $secilen = $null
    if ($havuz.Count -eq 1) { $secilen = $havuz[0] }
    elseif ($istenen) { $secilen = @($havuz | Where-Object { (Dns-Etiket $_.DNSName) -eq $istenen })[0] }

    $es = [ordered]@{
        dns = ''; nodeId = ''; publicKey = ''; hostName = ''; cevrimici = $false
        benimDns = $benimDns; benimNodeId = [string]$self.ID
        adaylar = @($havuz | ForEach-Object { Dns-Etiket $_.DNSName } | Where-Object { $_ })
        tarih = Simdi
    }
    if ($secilen) {
        $es.dns = Dns-Etiket $secilen.DNSName
        $es.nodeId = [string]$secilen.ID
        $es.publicKey = [string]$secilen.PublicKey
        $es.hostName = [string]$secilen.HostName
        $es.cevrimici = ($secilen.Online -eq $true)
        $es.adaylar = @($es.dns)
        if ($onceki -and $onceki.dns -eq $es.dns -and $onceki.nodeId -and $onceki.nodeId -ne $es.nodeId) {
            Yaz ("UYARI: '{0}' adı artık başka bir cihazda (NodeID değişti). Aynı bilgisayar yeniden kurulduysa sorun yok; değilse kullanıcıya sor." -f $es.dns)
        }
    }
    if ($ayniHesapWin.Count -ge 2 -and $script:Profil -eq 'kendi') {
        Yaz 'NOT: Hesapta bu bilgisayardan başka birden çok Windows cihaz var. Hepsi senin değilse ayar.json profil "paylasilan" önerilir (KOPRU.md).'
    }
    ($es | ConvertTo-Json -Depth 3) | Set-Content -LiteralPath (Kopru-Yol 'es.json') -Encoding UTF8
    if ($cevrimici.Count -eq 0) {
        foreach ($v in $dosyaOlur) { Yaz ("  {0}: çevrimdışı" -f (Dns-Etiket $v.DNSName)) }
        Yaz 'SONUC: Öbür bilgisayar bulundu ama şu an kapalı ya da uykuda. es.json yazıldı; bekçiyi kur, eş açılınca mesajı gelir.'
        return 3
    }
    if ($secilen) {
        Yaz ("ES: {0} (çevrimiçi) · ben: {1}" -f $es.dns, $benimDns)
        Yaz 'SONUC: Eş bulundu. Sıradaki: bekçiyi kur (kopru_bekle.ps1), sonra kopru_gonder.ps1 -Merhaba'
        return 0
    }
    if ($Sec) { Yaz ("SONUC: '{0}' adaylar arasında yok." -f $Sec) }
    Yaz ("ADAYLAR: {0}" -f ($es.adaylar -join ', '))
    Yaz 'SONUC: Birden çok aday. Hepsine merhaba gönder (kopru_gonder.ps1 -Merhaba -Hedef <ad>); cevap vereni -Sec <ad> ile seç.'
    return 5
}

if ($SadeceIslevler) { return }
exit (Kesif-Calistir -Sec $Sec)
