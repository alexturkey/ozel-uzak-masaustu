<#
.SYNOPSIS
  Tailscale ve RustDesk'i bu bilgisayarda kapatır ya da açar (seçenek). Seçeneksiz: yalnız durumu okur.
.DESCRIPTION
  Köprüyü kapatmak için bu betik gerekmez (kopru_gonder.ps1 -Kapat). Bu, bir adım ötesidir: bilgisayarı ağdan ve uzak
  masaüstünden tamamen ayırır. YALNIZ bu bilgisayarın başındaki kullanıcının kendi sözüyle çalışır; eşten gelen istekle
  asla çalışmaz. Uzaktan bağlıyken kapatırsan bağlantın kopar ve bilgisayara biri gidip açana kadar ulaşamazsın.
  -Kapat ve -Ac, -Onay olmadan yalnız ne yapacağını yazar. RustDesk servisini durdurmak/başlatmak yönetici ister:
  betik yetki istemez (pencere açmaz), yönetici değilse komutu yazar.
  Çıkış: 0 tamam (ya da yalnız durum) · 2 kullanım hatası / -Onay yok · 3 kısmen (yönetici gerekti) · 8 Tailscale hatası
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\kopru_servis.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File araclar\kopru_servis.ps1 -Kapat -Onay
#>
param([switch]$Kapat, [switch]$Ac, [switch]$Onay, [switch]$SadeceIslevler)
. (Join-Path $PSScriptRoot 'kopru_ortak.ps1')

function Yonetici-Mi {
    $k = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $k.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Servis-Durum {
    $ts = Get-Service -Name 'Tailscale' -ErrorAction SilentlyContinue
    $rd = Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue
    $durum = 'bilinmiyor'
    $r = Calistir-Tailscale -Arg @('status', '--json') -ZamanAsimiSn 20
    if ($r.Kod -eq 0) { try { $durum = [string](($r.Satirlar -join "`n") | ConvertFrom-Json).BackendState } catch { } }
    Yaz ("TAILSCALE: servis {0} · ağ {1}" -f $(if ($ts) { "$($ts.Status)/$($ts.StartType)" } else { 'yok' }), $durum)
    Yaz ("RUSTDESK: servis {0}" -f $(if ($rd) { "$($rd.Status)/$($rd.StartType)" } else { 'yok (servis olarak kurulu değil)' }))
    return [pscustomobject]@{ Tailscale = $ts; RustDesk = $rd; Ag = $durum }
}

function Servis-Calistir {
    param([switch]$Kapat, [switch]$Ac, [switch]$Onay)
    if ($Kapat -and $Ac) { Yaz 'HATA: -Kapat ve -Ac birlikte olmaz.'; return 2 }
    $d = Servis-Durum
    if (-not $Kapat -and -not $Ac) { return 0 }
    $yonetici = Yonetici-Mi
    if ($Kapat) {
        Yaz 'UYARI: Tailscale ağı ve RustDesk kapanır. Bu bilgisayara uzaktan bağlıysan bağlantın kopar; açmak için başına biri gelmeli.'
        Yaz '  Yapılacak: tailscale down · RustDesk servisi durdurulur (yönetici).'
    } else {
        Yaz '  Yapılacak: RustDesk servisi başlatılır (yönetici) · tailscale up.'
    }
    if ($Kapat -and ([string]$env:SESSIONNAME) -like 'RDP-*') { Yaz 'RED: bu oturum Uzak Masaüstü (RDP) üzerinden; servisleri kapatırsan bağlantın kopar. Bilgisayarın başındayken çalıştır.'; return 2 }
    if (-not $Onay) { Yaz 'ONAY YOK: hiçbir şey değişmedi. Kullanıcı kendi sözüyle onaylarsa aynı komut -Onay ile çalıştırılır.'; return 2 }
    $kod = 0
    if ($Kapat) {
        $r = Calistir-Tailscale -Arg @('down') -ZamanAsimiSn 30
        if ($r.Kod -ne 0) { Yaz ("HATA: tailscale down: {0}" -f (($r.Satirlar | Select-Object -First 2) -join ' ')); $kod = 8 } else { Yaz 'TAILSCALE: kapatıldı (tailscale down). Açmak: bu betik -Ac -Onay ya da tepsiden Connect.' }
        if ($d.RustDesk -and $d.RustDesk.Status -eq 'Running') {
            if ($yonetici) {
                Stop-Service -Name 'RustDesk' -ErrorAction SilentlyContinue
                if ((Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue).Status -eq 'Stopped') { Yaz 'RUSTDESK: servis durduruldu.' } else { Yaz 'HATA: RustDesk servisi durmadı.'; if ($kod -eq 0) { $kod = 3 } }
            }
            else { Yaz 'YONETICI GEREKLI: Başlat menüsünde PowerShell''e sağ tıkla > Yönetici olarak çalıştır, şunu yaz: Stop-Service RustDesk'; if ($kod -eq 0) { $kod = 3 } }
        }
    } else {
        if ($d.RustDesk -and $d.RustDesk.Status -ne 'Running') {
            if ($yonetici) {
                Start-Service -Name 'RustDesk' -ErrorAction SilentlyContinue
                if ((Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue).Status -eq 'Running') { Yaz 'RUSTDESK: servis başlatıldı.' } else { Yaz 'HATA: RustDesk servisi başlamadı.'; $kod = 3 }
            }
            else { Yaz 'YONETICI GEREKLI: Başlat menüsünde PowerShell''e sağ tıkla > Yönetici olarak çalıştır, şunu yaz: Start-Service RustDesk'; $kod = 3 }
        }
        $r = Calistir-Tailscale -Arg @('up') -ZamanAsimiSn 60
        if ($r.Kod -ne 0) { Yaz ("HATA: tailscale up: {0}. Tepsideki Tailscale simgesinden Connect de." -f (($r.Satirlar | Select-Object -First 2) -join ' ')); $kod = 8 } else { Yaz 'TAILSCALE: açıldı (tailscale up).' }
    }
    [void](Servis-Durum)
    return $kod
}

if ($SadeceIslevler) { return }
exit (Servis-Calistir -Kapat:$Kapat -Ac:$Ac -Onay:$Onay)
