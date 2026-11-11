# rustdesk_tailscale_kilit.ps1 testi. Gercek duvar/gorev degisikligi YOK: tum duvar komutlari sahte fonksiyonla golgelenir.
# Calistir: powershell -NoProfile -ExecutionPolicy Bypass -File tests\test_rustdesk_tailscale_kilit.ps1   (cikis 0 = gecti)
$ErrorActionPreference = 'Stop'
$betik = Join-Path (Split-Path $PSScriptRoot -Parent) 'araclar\rustdesk_tailscale_kilit.ps1'
$gecici = Join-Path ([IO.Path]::GetTempPath()) ('dg_test_rd_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $gecici | Out-Null
$basarisiz = 0; $toplam = 0; $global:Tum = @()
function Dogrula([bool]$kosul, [string]$ad) {
    $script:toplam++
    if ($kosul) { Write-Host "  GECTI  $ad" } else { Write-Host "  KALDI  $ad"; $script:basarisiz++ }
}

# geri_al_zamanlayici yerine sahte betik (cagri ve cikis kodu kaydeder)
$sahteGeriAl = Join-Path $gecici 'sahte_geri_al.ps1'
Set-Content -LiteralPath $sahteGeriAl -Value @('$global:Cagri += ("GERIAL " + ($args -join '' ''))', 'exit $global:GeriAlKod')

# ---- sahte duvar komutlari (durum $global:Var icinde tutulur) ----
function Get-NetFirewallRule {
    [CmdletBinding()] param($DisplayName)
    $global:Var | Where-Object { $_.DisplayName -like $DisplayName }
}
function New-NetFirewallRule {
    [CmdletBinding()] param($DisplayName, $Direction, $Protocol, $LocalPort, $Action, $Profile, $RemoteAddress)
    $global:Cagri += "New-NetFirewallRule $DisplayName"
    if ($global:NewHata) { throw 'sahte New hatasi' }
    $o = [pscustomobject]@{ DisplayName = $DisplayName; Direction = $Direction; Protocol = $Protocol; LocalPort = $LocalPort; Action = $Action; Profile = $Profile; RemoteAddress = $RemoteAddress }
    if (-not $global:NewSessiz) { $global:Var = @($global:Var) + $o }
}
function Remove-NetFirewallRule {
    [CmdletBinding()] param([Parameter(ValueFromPipeline = $true)]$InputObject, $DisplayName)
    process {
        $ad = if ($InputObject) { $InputObject.DisplayName } else { $DisplayName }
        $global:Cagri += "Remove-NetFirewallRule $ad"
        if (-not $global:RemoveTakili) { $global:Var = @($global:Var | Where-Object { $_.DisplayName -ne $ad }) }
    }
}
function Disable-NetFirewallRule { param([string[]]$Name) $global:Cagri += 'Disable-NetFirewallRule ' + ($Name -join ',') }
function Enable-NetFirewallRule { param([string[]]$Name) $global:Cagri += 'Enable-NetFirewallRule ' + ($Name -join ',') }
function Test-DgYonetici { return $global:Yonetici }

function Calistir([hashtable]$Arglar) {
    $global:Cagri = @(); $global:LASTEXITCODE = $null
    $cikti = (& $betik @Arglar -GeriAlYolu $sahteGeriAl *>&1 | Out-String -Width 4000)
    $global:Tum += $global:Cagri
    return [pscustomobject]@{ Cikti = $cikti; Kod = $global:LASTEXITCODE; Cagri = $global:Cagri }
}
function DurumSatiri($r) { @($r.Cikti -split "`r?`n" | Where-Object { $_ -match '^\| \d\d:\d\d \|' }) }
function Say($r, [string]$onEk) { @($r.Cagri | Where-Object { $_ -like "$onEk*" }).Count }
function Sira($r, [string]$onEk) { for ($i = 0; $i -lt $r.Cagri.Count; $i++) { if ($r.Cagri[$i] -like "$onEk*") { return $i } } return -1 }
function Varsayilan {
    $global:Yonetici = $true; $global:GeriAlKod = 0; $global:Var = @()
    $global:NewHata = $false; $global:NewSessiz = $false; $global:RemoteTakili = $false; $global:RemoveTakili = $false
}
# adres araliklari icinde IP var mi
function Aralikta([string[]]$araliklar, [string]$ip) {
    $x = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
    foreach ($a in $araliklar) {
        $p = $a -split '-'
        $lo = [System.Net.IPAddress]::Parse($p[0]).GetAddressBytes(); $hi = [System.Net.IPAddress]::Parse($p[1]).GetAddressBytes()
        if ($lo.Length -ne $x.Length) { continue }
        $buyuk = $true; $kucuk = $true
        for ($i = 0; $i -lt $x.Length; $i++) {
            if ($x[$i] -lt $lo[$i]) { $buyuk = $false; break }
            if ($x[$i] -gt $lo[$i]) { break }
        }
        for ($i = 0; $i -lt $x.Length; $i++) {
            if ($x[$i] -gt $hi[$i]) { $kucuk = $false; break }
            if ($x[$i] -lt $hi[$i]) { break }
        }
        if ($buyuk -and $kucuk) { return $true }
    }
    return $false
}

try {
    Write-Host 'test_rustdesk_tailscale_kilit'
    Varsayilan

    # 1. sozdizimi, BOM, ASCII, ic ad yok
    $hatalar = $null; $null = [System.Management.Automation.Language.Parser]::ParseFile($betik, [ref]$null, [ref]$hatalar)
    Dogrula ($hatalar.Count -eq 0) 'sozdizimi hatasiz'
    $bayt = [IO.File]::ReadAllBytes($betik)
    Dogrula ($bayt[0] -eq 0xEF -and $bayt[1] -eq 0xBB -and $bayt[2] -eq 0xBF) 'UTF-8 BOM var'
    Dogrula (@($bayt | Where-Object { $_ -gt 127 }).Count -eq 3) 'BOM disinda ASCII disi bayt yok'
    $metin = Get-Content -LiteralPath $betik -Raw
    Dogrula ($metin -notmatch '(?i)inceleyici|ek karar|\bmain\b') 'repoya ic ad girmemis'
    Dogrula ($metin -notmatch '(?m)^\s*(Disable|Enable)-NetFirewallRule') 'betik Disable/Enable-NetFirewallRule cagirmiyor'

    # 2. DryRun (seceneksiz): hicbir sey degismez
    Varsayilan
    $r = Calistir @{}
    Dogrula ($r.Kod -eq 0) 'DryRun cikis 0'
    Dogrula ((Say $r 'New-NetFirewallRule') -eq 0 -and (Say $r 'Remove-NetFirewallRule') -eq 0) 'DryRun duvara dokunmadi'
    Dogrula ($r.Cikti -match '\[DRYRUN\]') 'DryRun [DRYRUN] etiketli'
    Dogrula ($r.Cikti -match 'TCP 21118' -and $r.Cikti -match 'UDP 21119') 'DryRun iki kurali da anlatti'
    Dogrula ((Say $r 'GERIAL') -eq 1 -and ($r.Cagri -join ' ') -notmatch 'GERIAL.*-Uygula') 'DryRun zamanlayiciyi -Uygula olmadan cagirdi'
    Dogrula ($r.Cikti -match 'powershell -NoProfile -ExecutionPolicy Bypass -File araclar\\rustdesk_tailscale_kilit\.ps1 -Dakika 10 -Uygula') 'ipucu tam calistirma bicimi'
    $d = @(DurumSatiri $r)
    Dogrula ($d.Count -eq 1 -and (($d[0] -split '\|').Count - 2) -eq 6) 'DryRun tek 6 alanli DURUM satiri'
    Dogrula (@($bayt).Count -gt 0 -and -not ($r.Cikti -cmatch '[^\x00-\x7F]')) 'cikti ASCII'
    Varsayilan; $global:Yonetici = $false
    $r = Calistir @{}
    Dogrula ($r.Kod -eq 0) 'DryRun yoneticisiz de calisir'

    # 3. yonetici degil
    Varsayilan; $global:Yonetici = $false
    $r = Calistir @{ Uygula = $true }
    Dogrula ($r.Kod -eq 2 -and $r.Cagri.Count -eq 0) '-Uygula yoneticisiz: cikis 2, hicbir sey degismedi'
    $r = Calistir @{ Geri = $true; Uygula = $true }
    Dogrula ($r.Kod -eq 2 -and $r.Cagri.Count -eq 0) '-Geri -Uygula yoneticisiz: cikis 2'

    # 4. -Uygula
    Varsayilan
    $r = Calistir @{ Uygula = $true; Dakika = 15 }
    Dogrula ($r.Kod -eq 0) '-Uygula cikis 0'
    Dogrula ((Sira $r 'GERIAL') -eq 0 -and (Sira $r 'New-NetFirewallRule') -gt 0) 'guvenlik agi duvar kurallarindan ONCE'
    Dogrula (($r.Cagri[0]) -match '-Dakika 15' -and $r.Cagri[0] -match '-Uygula' -and $r.Cagri[0] -match '-DurumSatiriYok') 'zamanlayici -Dakika 15 -Uygula -DurumSatiriYok ile cagrildi'
    Dogrula ((Say $r 'New-NetFirewallRule') -eq 2 -and $global:Var.Count -eq 2) 'iki engel kurali kuruldu'
    $tcp = $global:Var | Where-Object { $_.Protocol -eq 'TCP' }; $udp = $global:Var | Where-Object { $_.Protocol -eq 'UDP' }
    Dogrula ($tcp.LocalPort -eq 21118 -and $udp.LocalPort -eq 21119) 'TCP 21118 ve UDP 21119'
    Dogrula (@($global:Var | Where-Object { $_.Direction -ne 'Inbound' -or $_.Action -ne 'Block' -or $_.Profile -ne 'Any' }).Count -eq 0) 'hepsi Inbound, Block, Profil Any'
    $adr = @($tcp.RemoteAddress)
    foreach ($ip in '192.168.1.5', '8.8.8.8', '10.0.0.2', '100.63.255.255', '100.128.0.0', '169.254.1.1', 'fe80::1', '2001:db8::1', 'fd7a:115c:a1df:ffff:ffff:ffff:ffff:ffff', 'fd7a:115c:a1e1::') {
        Dogrula (Aralikta $adr $ip) "engel kapsiyor: $ip"
    }
    foreach ($ip in '100.64.0.0', '100.100.100.100', '100.127.255.255', 'fd7a:115c:a1e0::1', 'fd7a:115c:a1e0:ffff:ffff:ffff:ffff:ffff', '127.0.0.1', '127.255.255.255', '::1') {
        Dogrula (-not (Aralikta $adr $ip)) "engel kapsamiyor (Tailscale ya da loopback): $ip"
    }
    $d = @(DurumSatiri $r)
    Dogrula ($d.Count -eq 1 -and $d[0] -match '\| yarim \|' -and (($d[0] -split '\|').Count - 2) -eq 6) '-Uygula 6 alanli DURUM satiri, yarim'
    Dogrula ($r.Cikti -match 'Tamam: engel kurallari kuruldu' -and $r.Cikti -match 'geri_al_zamanlayici\.ps1 -Iptal') 'kanit ve kalici yapma ipucu var'
    Dogrula (-not ($r.Cikti -cmatch '[^\x00-\x7F]')) '-Uygula ciktisi ASCII'

    # 5. yeniden -Uygula eski kurali degistirir
    $once = $global:Var.Count
    $r = Calistir @{ Uygula = $true }
    Dogrula ($r.Kod -eq 0 -and $global:Var.Count -eq $once -and (Say $r 'Remove-NetFirewallRule') -eq 2) 'ikinci -Uygula kopya birakmaz'

    # 6. guvenlik agi kurulamazsa duvara dokunulmaz
    Varsayilan; $global:GeriAlKod = 3
    $r = Calistir @{ Uygula = $true }
    Dogrula ($r.Kod -eq 7 -and (Say $r 'New-NetFirewallRule') -eq 0 -and $global:Var.Count -eq 0) 'zamanlayici hatasi: cikis 7, kural kurulmadi'

    # 7. kural kurulamazsa yalan basari yok
    Varsayilan; $global:NewHata = $true
    $r = Calistir @{ Uygula = $true }
    Dogrula ($r.Kod -eq 1 -and $r.Cikti -match 'HATA' -and $r.Cikti -notmatch 'Tamam: engel') 'New hatasi: cikis 1, "Tamam" yazmaz'
    Varsayilan; $global:NewSessiz = $true
    $r = Calistir @{ Uygula = $true }
    Dogrula ($r.Kod -eq 1 -and $r.Cikti -match 'Kural kurulamadi' -and $r.Cikti -notmatch 'Tamam: engel') 'kural gorunmuyorsa: cikis 1'

    # 8. -Geri
    Varsayilan
    $null = Calistir @{ Uygula = $true }
    $r = Calistir @{ Geri = $true }
    Dogrula ($r.Kod -eq 0 -and $global:Var.Count -eq 2 -and (Say $r 'Remove-NetFirewallRule') -eq 0 -and (Say $r 'GERIAL') -eq 0) '-Geri (DryRun) hicbir sey degistirmez'
    $r = Calistir @{ Geri = $true; Uygula = $true }
    Dogrula ($r.Kod -eq 0 -and $global:Var.Count -eq 0) '-Geri -Uygula iki kurali siler'
    Dogrula (($r.Cagri -join '|') -match 'GERIAL -Iptal -DurumSatiriYok') '-Geri bekleyen geri alma gorevini de kaldirir'
    $d = @(DurumSatiri $r)
    Dogrula ($d.Count -eq 1 -and $d[0] -match '\| bitti \|') '-Geri 6 alanli DURUM satiri, bitti'
    Varsayilan
    $null = Calistir @{ Uygula = $true }
    $global:GeriAlKod = 1
    $r = Calistir @{ Geri = $true; Uygula = $true }
    Dogrula ($r.Kod -eq 8 -and $global:Var.Count -eq 0) 'gorev kaldirilamazsa cikis 8, kural yine de silinmisti'
    Varsayilan
    $null = Calistir @{ Uygula = $true }
    $global:RemoveTakili = $true
    $r = Calistir @{ Geri = $true; Uygula = $true }
    Dogrula ($r.Kod -eq 1 -and $r.Cikti -match 'silinemedi') 'kural silinemezse cikis 1 (yalan basari yok)'

    # 9. hicbir senaryoda Disable/Enable cagrilmadi
    Dogrula (@($global:Tum | Where-Object { $_ -like 'Disable-*' -or $_ -like 'Enable-*' }).Count -eq 0) 'hicbir senaryoda Disable/Enable-NetFirewallRule cagrilmadi'
}
catch {
    Write-Host ("  KALDI  beklenmeyen test hatasi: {0}" -f $_.Exception.Message)
    $basarisiz++
}
finally {
    if (Test-Path -LiteralPath $gecici) { Remove-Item -LiteralPath $gecici -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-Host ("Sonuc: {0} test, {1} basarisiz" -f $toplam, $basarisiz)
if ($basarisiz -gt 0) { exit 1 }
exit 0
