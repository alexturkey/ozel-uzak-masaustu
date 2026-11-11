# rdp_tailscale_kilit.ps1 testi. Gercek duvar/gorev degisikligi YOK: tum duvar komutlari sahte fonksiyonla golgelenir.
# Calistir: powershell -NoProfile -ExecutionPolicy Bypass -File tests\test_rdp_tailscale_kilit.ps1   (cikis 0 = gecti)
$ErrorActionPreference = 'Stop'
$betik = Join-Path (Split-Path $PSScriptRoot -Parent) 'araclar\rdp_tailscale_kilit.ps1'
$gecici = Join-Path ([IO.Path]::GetTempPath()) ('dg_test_rdp_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $gecici | Out-Null
$basarisiz = 0; $toplam = 0
function Dogrula([bool]$kosul, [string]$ad) {
    $script:toplam++
    if ($kosul) { Write-Host "  GECTI  $ad" } else { Write-Host "  KALDI  $ad"; $script:basarisiz++ }
}

# geri_al_zamanlayici yerine sahte betik (cagri ve cikis kodu kaydeder)
$sahteGeriAl = Join-Path $gecici 'sahte_geri_al.ps1'
Set-Content -LiteralPath $sahteGeriAl -Value @('$global:Cagri += ("GERIAL " + ($args -join '' ''))', 'exit $global:GeriAlKod')

# ---- sahte komutlar ----
function Get-CimInstance { param($ClassName) [pscustomobject]@{ OperatingSystemSKU = $global:Sku } }
function Get-NetAdapter { param($Name, $ErrorAction) if ($global:ArayuzVar) { return [pscustomobject]@{ Name = $Name; Status = 'Up' } } return $null }
function Get-NetFirewallPortFilter {
    foreach ($k in $global:Kurallar) { [pscustomobject]@{ LocalPort = $k.Port; Kural = $k } }
}
function Get-NetFirewallRule {
    param([Parameter(ValueFromPipeline = $true)]$InputObject, $DisplayName)
    process {
        if ($InputObject) { return $InputObject.Kural }
        if ($DisplayName) { return ($global:Kurallar | Where-Object { $_.DisplayName -eq $DisplayName } | Select-Object -First 1) }
    }
}
function New-NetFirewallRule { param($DisplayName, $Direction, $Protocol, $LocalPort, $Action, $Profile, $InterfaceAlias, $RemoteAddress)
    $global:Cagri += "New-NetFirewallRule $DisplayName"; $global:Yeni = @{ Port = $LocalPort; Arayuz = $InterfaceAlias; Adres = $RemoteAddress; Yon = $Direction; Eylem = $Action; Profil = $Profile; Proto = $Protocol } }
function Remove-NetFirewallRule { param($DisplayName) $global:Cagri += "Remove-NetFirewallRule $DisplayName" }
function Disable-NetFirewallRule { param([string[]]$Name) $global:Cagri += 'Disable-NetFirewallRule ' + ($Name -join ','); $global:Kapatilan = $Name }
function Enable-NetFirewallRule { param([string[]]$Name) $global:Cagri += 'Enable-NetFirewallRule ' + ($Name -join ',') }
function Test-DgYonetici { return $global:Yonetici }

function Kural($ad, $gorunen, $port = '3389', $acik = 'True', $yon = 'Inbound', $eylem = 'Allow') {
    [pscustomobject]@{ Name = $ad; DisplayName = $gorunen; Port = $port; Enabled = $acik; Direction = $yon; Action = $eylem }
}
function Calistir([hashtable]$Arglar) {
    $global:Cagri = @(); $global:LASTEXITCODE = $null; $global:Yeni = $null; $global:Kapatilan = $null
    $v = Join-Path $gecici ('veri_' + [guid]::NewGuid().ToString('N').Substring(0, 6))
    $cikti = (& $betik @Arglar -GeriAlYolu $sahteGeriAl -VeriKlasoru $v *>&1 | Out-String -Width 4000)
    return [pscustomobject]@{ Cikti = $cikti; Kod = $global:LASTEXITCODE; Cagri = $global:Cagri; Veri = $v }
}
function DurumSatiri($r) { @($r.Cikti -split "`r?`n" | Where-Object { $_ -match '^\| \d\d:\d\d \|' }) }
function Say($r, [string]$onEk) { @($r.Cagri | Where-Object { $_ -like "$onEk*" }).Count }
function Sira($r, [string]$onEk) { for ($i = 0; $i -lt $r.Cagri.Count; $i++) { if ($r.Cagri[$i] -like "$onEk*") { return $i } } return -1 }
function Varsayilan {
    $global:Yonetici = $true; $global:Sku = 48; $global:ArayuzVar = $true; $global:GeriAlKod = 0
    $global:Kurallar = @(
        (Kural 'RemoteDesktop-UserMode-In-TCP' 'Uzak Masaustu - TCP'),
        (Kural 'RemoteDesktop-UserMode-In-UDP' 'Uzak Masaustu - UDP'),
        (Kural 'DigerKural' 'Baska port' '8080'),
        (Kural 'KapaliRdp' 'Kapali rdp' '3389' 'False'),
        (Kural 'CikisRdp' 'Cikis rdp' '3389' 'True' 'Outbound'),
        (Kural 'EngelRdp' 'Engel rdp' '3389' 'True' 'Inbound' 'Block')
    )
}

try {
    Write-Host 'test_rdp_tailscale_kilit'
    Varsayilan

    # 1. sozdizimi + BOM
    $hatalar = $null; $null = [System.Management.Automation.Language.Parser]::ParseFile($betik, [ref]$null, [ref]$hatalar)
    Dogrula ($hatalar.Count -eq 0) 'sozdizimi hatasiz'
    $b = [IO.File]::ReadAllBytes($betik)[0..2]
    Dogrula ($b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) 'UTF-8 BOM var'

    # 2. Home -> dur
    foreach ($homeSku in 98, 99, 100, 101) {
        Varsayilan; $global:Sku = $homeSku
        $r = Calistir @{ Uygula = $true }
        Dogrula ($r.Kod -eq 5 -and $r.Cagri.Count -eq 0) "Home (SKU $homeSku) cikis 5, hicbir sey degismedi"
    }
    Dogrula ($r.Cikti -match 'Home') 'Home mesaji Turkce aciklama tasiyor'

    # 3. Tailscale arayuzu yok
    Varsayilan; $global:ArayuzVar = $false
    $r = Calistir @{ Uygula = $true }
    Dogrula ($r.Kod -eq 6 -and $r.Cagri.Count -eq 0) 'arayuz yoksa cikis 6, hicbir sey degismedi'

    # 4. varsayilan DryRun
    Varsayilan
    $r = Calistir @{}
    Dogrula ($r.Kod -eq 0) 'DryRun cikis 0'
    Dogrula ((Say $r 'New-NetFirewallRule') -eq 0 -and (Say $r 'Disable-NetFirewallRule') -eq 0 -and (Say $r 'Remove') -eq 0) 'DryRun duvara dokunmadi'
    Dogrula ((Say $r 'GERIAL') -eq 1 -and ($r.Cagri -join ' ') -notmatch 'Uygula') 'DryRun guvenlik agini yalniz DryRun cagirdi'
    Dogrula (($r.Cikti -replace '\s*\r?\n','') -match 'RemoteDesktop-UserMode-In-TCP' -and ($r.Cikti -replace '\s*\r?\n','') -match 'RemoteDesktop-UserMode-In-UDP') 'DryRun kapatilacak kurallari listeledi'
    Dogrula ($r.Cikti -notmatch 'DigerKural|KapaliRdp|CikisRdp|EngelRdp') 'yalniz acik+giris+izin+3389 kurallari secildi'
    Dogrula ($r.Cikti -match '\[DRYRUN\]') 'DryRun etiketi'
    $ds = @(DurumSatiri $r)
    Dogrula ($ds.Count -eq 1 -and (($ds[0] -split ' \| ').Count -eq 6)) 'DryRun sonunda tek 6 alanli DURUM satiri'
    Dogrula ($r.Cikti -match [regex]::Escape('powershell -NoProfile -ExecutionPolicy Bypass -File araclar\rdp_tailscale_kilit.ps1 -Dakika 10 -Uygula')) 'DryRun ipucu tam calistirma bicimiyle'
    Dogrula ($r.Cikti -cnotmatch '[^\x00-\x7F]') 'DryRun ciktisi ASCII'

    # 4b. varsayilan GeriAlYolu gercek geri_al_zamanlayici.ps1'i buluyor (DryRun, zararsiz)
    Varsayilan; $global:Cagri = @()
    $o = (& $betik -VeriKlasoru (Join-Path $gecici 'v4b') *>&1 | Out-String -Width 4000)
    Dogrula (($global:LASTEXITCODE -eq 0) -and ($o -match 'geri_al_zamanlayici|Plan: 1\) duvar')) 'varsayilan GeriAlYolu cozuldu'

    # 5. yonetici degil
    Varsayilan; $global:Yonetici = $false
    $r = Calistir @{ Uygula = $true }
    Dogrula ($r.Kod -eq 2 -and $r.Cagri.Count -eq 0) 'yonetici degilse cikis 2, degisiklik yok'

    # 6. gercek akis: sira ve parametreler
    Varsayilan
    $r = Calistir @{ Uygula = $true; Dakika = 5 }
    Dogrula ($r.Kod -eq 0) '-Uygula cikis 0'
    $iG = Sira $r 'GERIAL'; $iN = Sira $r 'New-NetFirewallRule'; $iD = Sira $r 'Disable-NetFirewallRule'
    Dogrula ($iG -eq 0) 'ILK is guvenlik agi'
    Dogrula ($r.Cagri[$iG] -match '-Dakika 5' -and $r.Cagri[$iG] -match '-Uygula') 'guvenlik agi -Dakika 5 -Uygula ile cagrildi'
    Dogrula ($iG -lt $iN -and $iN -lt $iD) 'sira: guvenlik agi, yeni kural, sonra eskileri kapat'
    Dogrula ($global:Yeni.Port -eq 3389 -and $global:Yeni.Arayuz -eq 'Tailscale' -and $global:Yeni.Adres -eq '100.64.0.0/10') 'yeni kural 3389 + Tailscale arayuzu + 100.64.0.0/10'
    Dogrula ($global:Yeni.Yon -eq 'Inbound' -and $global:Yeni.Eylem -eq 'Allow' -and $global:Yeni.Profil -eq 'Any' -and $global:Yeni.Proto -eq 'TCP') 'yeni kural giris/izin/profil Any/TCP'
    Dogrula ((@($global:Kapatilan) -join ',') -eq 'RemoteDesktop-UserMode-In-TCP,RemoteDesktop-UserMode-In-UDP') 'tam olarak ilgili iki kural -Name ile kapatildi'
    $liste = Join-Path $r.Veri 'kapatilan_kurallar.txt'
    Dogrula ((Test-Path $liste) -and (@(Get-Content $liste).Count -eq 2)) 'kapatilan kurallar geri alma icin kaydedildi'
    Dogrula ($r.Cikti -match 'Iptal') 'cikti kalici yapma (-Iptal) yolunu soyluyor'
    Dogrula ($r.Cikti -match [regex]::Escape('-File araclar\geri_al_zamanlayici.ps1 -Iptal')) '-Iptal ipucu tam calistirma bicimiyle'
    Dogrula (($r.Cikti -match [regex]::Escape('1) Ikinci cihazda (B) Uzak Masaustu ile hedefin Tailscale adresine (100.x...) baglan: baglanmali.')) -and ($r.Cikti -match [regex]::Escape("2) Ayni ev agindaki BASKA bir cihazdan hedefin yerel IP'sine (ipconfig ile bul) baglanmayi dene: baglanMAMALI. Boyle bir cihaz yoksa bu kontrolu atla ve DURUM'a yaz."))) 'kanit 1) ve 2) satirlari yeni metinle'
    Dogrula ($r.Cikti -match [regex]::Escape('-File araclar\rdp_tailscale_kilit.ps1 -Geri -Uygula')) '-Geri ipucu tam calistirma bicimiyle'
    $ds = @(DurumSatiri $r)
    Dogrula ($ds.Count -eq 1 -and (($ds[0] -split ' \| ').Count -eq 6) -and $ds[0] -match '\| yarim \|') 'Uygula sonunda tek 6 alanli DURUM satiri (yarim)'
    Dogrula ($r.Cagri[0] -match '-DurumSatiriYok') 'alt betigin kendi DURUM satiri bastirildi'
    Dogrula ($r.Cikti -cnotmatch '[^\x00-\x7F]') 'Uygula ciktisi ASCII'

    # 7. guvenlik agi kurulamazsa duvara dokunma
    Varsayilan; $global:GeriAlKod = 4
    $r = Calistir @{ Uygula = $true }
    Dogrula ($r.Kod -eq 7) 'guvenlik agi basarisizsa cikis 7'
    Dogrula ((Say $r 'New-NetFirewallRule') -eq 0 -and (Say $r 'Disable') -eq 0) 'guvenlik agi yoksa duvar degismedi'

    # 8. kapatilacak kural yoksa parametresiz Disable cagrilmaz (tum kurallari kapatir!)
    Varsayilan; $global:Kurallar = @((Kural 'DigerKural' 'Baska port' '8080'))
    $r = Calistir @{ Uygula = $true }
    Dogrula ($r.Kod -eq 0 -and (Say $r 'New-NetFirewallRule') -eq 1) 'kural yoksa bile yeni kural eklendi'
    Dogrula ((Say $r 'Disable-NetFirewallRule') -eq 0) 'kapatilacak yoksa Disable HIC cagrilmadi'

    # 9. kendi kuralimiz tekrar kapatilmaz, yeniden calistirmada eski kural silinip yenilenir
    Varsayilan; $global:Kurallar += (Kural 'BizimKural' 'RDP yalniz Tailscale')
    $r = Calistir @{ Uygula = $true }
    Dogrula ((@($global:Kapatilan) -notcontains 'BizimKural')) 'kendi kurali kapatilmadi'
    Dogrula ((Say $r 'Remove-NetFirewallRule') -eq 1 -and (Say $r 'New-NetFirewallRule') -eq 1) 'eski kendi kurali silinip yenisi eklendi (tekrar calistirma guvenli)'

    # 10. -Geri: kurali siler, kapatilanlari acar, bekleyen geri alma gorevini de kaldirir
    Varsayilan
    $r1 = Calistir @{ Uygula = $true }
    $global:Kurallar += (Kural 'BizimKural' 'RDP yalniz Tailscale')
    function GeriCalistir([hashtable]$a) {
        $global:Cagri = @(); $global:LASTEXITCODE = $null
        $o = (& $betik @a -GeriAlYolu $sahteGeriAl -VeriKlasoru $r1.Veri *>&1 | Out-String -Width 4000)
        return [pscustomobject]@{ Cikti = $o; Kod = $global:LASTEXITCODE; Cagri = $global:Cagri }
    }
    $g = GeriCalistir @{ Geri = $true; Uygula = $true }
    Dogrula ($g.Kod -eq 0) '-Geri -Uygula cikis 0'
    Dogrula ((Say $g 'Enable-NetFirewallRule') -eq 1) '-Geri kapatilan kurallari yeniden acti'
    Dogrula ((Say $g 'Remove-NetFirewallRule') -eq 1) '-Geri kendi kuralini sildi'
    Dogrula (@($g.Cagri | Where-Object { $_ -match '^GERIAL' -and $_ -match '-Iptal' }).Count -eq 1) '-Geri bekleyen geri alma gorevini -Iptal ile kaldirdi'
    $ds = @(DurumSatiri $g)
    Dogrula ($ds.Count -eq 1 -and (($ds[0] -split ' \| ').Count -eq 6) -and $ds[0] -match '\| bitti \|') '-Geri sonunda 6 alanli DURUM satiri (bitti)'
    Dogrula ($g.Cikti -match 'Tamam: kilit geri alindi\.') '-Geri tam cikti satiri'
    $g = GeriCalistir @{ Geri = $true }
    Dogrula ($g.Kod -eq 0 -and (Say $g 'Enable') -eq 0 -and (Say $g 'Remove') -eq 0) '-Geri DryRun duvara dokunmadi'
    Dogrula (@($g.Cagri | Where-Object { $_ -match '^GERIAL' -and $_ -match '-Iptal' -and $_ -match '-DryRun' }).Count -eq 1) '-Geri DryRun, -Iptal -DryRun ozetini cagirdi'
    Dogrula ((@(DurumSatiri $g)).Count -eq 1) '-Geri DryRun tek DURUM satiri'
    $global:GeriAlKod = 4
    $g = GeriCalistir @{ Geri = $true; Uygula = $true }
    Dogrula ($g.Kod -eq 8) 'gorev kaldirilamazsa -Geri cikis 8'
    Dogrula ((Say $g 'Remove-NetFirewallRule') -eq 1) 'cikis 8 durumunda bile kural geri alinmisti'
    $global:GeriAlKod = 0
}
finally {
    Remove-Item -LiteralPath $gecici -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ("Sonuc: {0} test, {1} basarisiz" -f $toplam, $basarisiz)
if ($basarisiz -gt 0) { exit 1 } else { exit 0 }
