# Kaynaklar

Bu rehberdeki her sayı, port numarası ve ayar adı aşağıdaki kaynaklardan birine dayanır. Alıntılar **harfiyen** ve kaynağın kendi dilinde bırakıldı (çoğu İngilizce); altına Türkçe tek satır açıklama eklendi.
Okuma tarihi hepsinde **2026-11-11**. Fiyat, limit, ayar ve komut adları zamanla değişir: yayın gününde sayfalara yeniden bakın.

Kaynak türü etiketi: **belge** (resmî sayfa, ham metinden alıntı), **ikincil** (ticari blog, forum; yalnız yön gösterir, kanıt sayılmaz), **özet** (arama ya da okuma aracının özeti; ham sayfa alıntılanamadı), **ilke** (bir belgeye değil çalışma ilkesine dayanır).

Bölümler: [Tailscale](#tailscale) · [Windows](#windows) · [RustDesk](#rustdesk) · [Standartlar](#standartlar) · [Güvenilirlik ve olgunluk](#güvenilirlik-ve-olgunluk) · [Türkiye](#türkiye-operatör-ve-mevzuat) · [Doğrulanmayanlar](#doğrulanmayanlar-ve-kritik-kontroller) · [İlke maddeleri](#ilke-maddeleri)

---

## Tailscale

**[K1] "How NAT traversal works", https://tailscale.com/blog/how-nat-traversal-works** (belge; sayfada yazı tarihi "August 21, 2020")
- Kural: "For UDP, the rule is: packets must flow out before packets can flow back in."
- Yan kanal: "In Tailscale, our coordination server and fleet of DERP (Detour Encrypted Routing Protocol) servers act as our side channel."
- UDP eşleme süresi: "If no packets are seen for a while (a common value for UDP is 30 seconds), the firewall forgets about the session, and we have to start over."
- Röle: "we use this communication path both as a data relay when NAT traversal fails (in the same role as TURN in other systems) and as the side channel to help with NAT traversal. DERP is both our fallback of last resort to get connectivity, and our helper to upgrade to a peer-to-peer connection, when that's possible."
- HTTP üzerinden: "It runs over HTTP, which is handy on networks with strict outbound rules, and relays encrypted payloads based on the destination's public key."
- Doğrudan oranı (yazarın tahmini, ölçüm değil): "If you stopped reading now and implemented just the above, I'd estimate you could get a direct connection over 90% of the time, and your relays guarantee some connectivity all the time."
- İki zor NAT (genel başarı oranı değil, belirli bir senaryo): "after 20 seconds in the same regime as the previous setup (256 probes from one side, 2048 from the other), our chance of success is… 0.01%." ve "To hit a 99.9% chance of success, we need each side to send 170,000 probes. At 100 packets/sec, that's 28 minutes of trying before we can communicate."
- UDP engeli: "we've observed that the UC Berkeley guest Wi-Fi blocks all outbound UDP except for DNS traffic. No amount of clever NAT tricks is going to get around the firewall eating your packets."
- CGNAT: "your home router SNATs your devices to an 'intermediate' IP address, and further out in the ISP's network a second layer of NAT devices map those intermediate IPs onto a smaller number of public IPs. This is 'carrier-grade NAT', or CGNAT for short." ve "Prior to CGNAT, enterprising users could work around NAT traversal difficulties by manually configuring port forwarding on their home routers. But you can't reconfigure the ISP's CGNAT!"
- Hairpin: "hairpinning works on some NATs and not others. In fact, a great many otherwise well-behaved NAT devices don't support hairpinning".
- Açıklama: NAT delme tekniği yıllardır belgeli; tanıştırıcı (koordinasyon sunucusu) ve röle (DERP) bu işin normal parçaları. "%0,01" yalnız iki taraf da zor NAT ve 20 sn'lik kaba deneme için; "%90" yazarın tahmini.

**[K2] "Connection types", https://tailscale.com/kb/1257/connection-types** (belge; yeni adres https://tailscale.com/docs/reference/connection-types)
- "Direct connections usually provide the lowest latency and highest throughput, while relayed connections are a fallback when direct connectivity isn't possible." ; "The primary difference between them is performance, not security."
- "All connections start as relayed through a DERP server, and Tailscale then tries to upgrade them to a direct connection. If that fails, Tailscale tries to connect them using a peer relay. If that fails, the connection remains relayed through the DERP server." ; "Here, the first few packets go through the nearest DERP server while Tailscale negotiates a direct connection."
- "In most environments, Tailscale successfully establishes direct connections, but some network configurations (hard NAT) can prevent this and force Tailscale to use relayed connections instead."
- "using a relayed connection when a direct connection would be possible is one of the most common causes of" (performans sorunları; cümle sayfada böyle devam ediyor).
- Nasıl görülür: "You can determine which connection type you're using by communicating between devices and then inspecting `tailscale status` or `tailscale ping`." ; "If the output contains "direct", the connection is direct." ; "If the output includes "relay", the connection is relayed through a DERP server." ; "If the output includes "peer-relay", the connection is relayed through a peer relay device."
- Örnek çıktılar (sayfadan): `... active; offers exit node; direct 140.82.13.138:41641` (doğrudan) ve `... active; relay "tor"` (DERP röle); `tailscale ping` örnekleri: "pong from another-device (100.104.93.78) via DERP(tor) in 53ms" / "pong from another-device (100.97.143.93) via peer-relay(192.168.64.2:7777:vni:1) in 4ms" / "pong from another-device (100.113.160.82) via 140.82.13.138:41641 in 35ms" / "direct connection not established".
- Açıklama: `baglanti_kanit.ps1` bu ifadelere bakar. Satır düzeninin (`;` sonrası tür) tam biçimi belgede verilmiyor, bkz. "Doğrulanmayanlar".

**[K3] CLI başvurusu, https://tailscale.com/kb/1080/cli** (belge; yeni adres https://tailscale.com/docs/reference/tailscale-cli)
- `tailscale ping`: "Attempt to ping another device exclusively over Tailscale." ; "`--until-direct`, `--until-direct=false` Stop once a direct path is established. Defaults to true." ; "`--c` Maximum number of pings to send. Defaults to 10." (yani `--c=10` yazmak gereksiz, varsayılan zaten 10) ; "`--timeout=<duration>` Maximum amount of time to wait before giving up on a ping."
- `tailscale netcheck`: "Get a report on your current physical network conditions. This command is provided to help debug connection troubles."
- `tailscale status`: "`--active`: Filter output to only peers with active sessions", "`--json`: Output in JSON format (WARNING: format subject to change)." ; bağlantı türü: "It also includes the connection type, which can be `direct`, `relay`, or `peer-relay`."
- `tailscale ip`: "Get a device's Tailscale IP address." ; "By default, this command returns both an 100.x.y.z IPv4 address and an IPv6 address for the current device. You can return only an IPv4 or IPv6 address by passing either the -4 or -6 flags."
- Oturumu kapatma: "Disconnect from Tailscale and expire the current log in." ; "The next time you run `tailscale up`, you'll need to reauthenticate your device."
- Açıklama: `--until-direct` belgeli (doğrudan yol kurulunca durur).

**[K4] Fiyat sayfası ve SSS, https://tailscale.com/pricing ve https://tailscale.com/kb/1251/pricing-faq** (belge)
- "Personal ... For individuals who want to securely connect devices, servers, or software. Access nearly all of Tailscale's offerings and products for free, indefinitely. $0 Free forever ... Unlimited user devices Up to 6 users".
- "Our Personal plan is for individuals who want to use Tailscale at home. This is a free plan and is only suitable for non-commercial use of Tailscale."
- Açıklama: Kişisel plan ücretsiz, 6 kullanıcıya kadar, ticari olmayan kullanım için. DERP/röle kotası bu iki sayfada **bulunamadı**. Plan sayıları değişebilir.

**[K5] "DERP servers", https://tailscale.com/kb/1232/derp-servers** (belge)
- "DERP (Designated Encrypted Relay for Packets) servers manage device connections and NAT traversal." ; "A DERP server blindly forwards already-encrypted traffic from one device to another." ; "If there aren't any peer relays available, it then falls back to DERP servers."
- Açıklama: Röle şifreli trafiği körü körüne iletir.

**[K6] "Install Tailscale on Windows", https://tailscale.com/kb/1022/install-windows** (belge)
- "requires Windows 10 or later or Windows Server 2016 or later." ; "Download the latest `.exe` installer." ; "Under your account, select **Log in** to launch a browser window..." ; "a new Tailscale icon will appear in your system tray".
- Açıklama: Sayfa Windows Home desteğini ve yönetici gereksinimini ayrıca **belirtmiyor**.

**[K7] "Run in unattended mode", https://tailscale.com/kb/1088/run-unattended** (belge)
- "enable unattended mode, also referred to as Server mode." ; arayüz: tepsi simgesi > Preferences > "Run unattended"; komut: `tailscale set --unattended=true`; "The Tailscale client continues to run with the configured profile even after the Windows user logs out."
- Sorun giderme bölümü: "make sure the Tailscale service is set to Automatic and is currently Running."
- Açıklama: Kullanıcı oturumu kapansa da Tailscale çalışır (uzaktan erişimde şart).

**[K8] `tailscale up` bayrakları, https://tailscale.com/kb/1241/tailscale-up** (belge)
- "--shields-up: Block incoming connections from other devices on your Tailscale network." ; "--unattended: (Windows only) Run in unattended mode where Tailscale keeps running even after the current user logs out."

**[K9] "Device connectivity", https://tailscale.com/kb/1411/device-connectivity** (özet: ham alıntı yerine araç özeti)
- `netcheck` alan adları: UDP "Shows whether the device can send outbound UDP packets"; MappingVariesByDestIP "most important field for explaining why a device doesn't get direct connections ... True ... indicates hard NAT and a likely relayed connection"; PortMapping "UPnP, NAT-PMP, or PCP". Sayfada `netcheck` örnek çıktısı yok.

**[K10] "Tailscale IP addresses", https://tailscale.com/kb/1015/100.x-addresses** (belge; yeni adres https://tailscale.com/docs/concepts/tailscale-ip-addresses)
- "IP addresses from the CGNAT range are special-use IPv4 addresses from the 100.64.0.0/10 subnet (100.64.0.0 through 100.127.255.255)." ; "reserved for internet service provider (ISP) networks and routing equipment rather than private networks."
- Açıklama: Tailscale'in cihaz adresleri 100.64.0.0/10'dan verilir. Modemdeki "WAN IP" bu aralıktaysa bu **operatörün** ortak NAT'ının işaretidir (bkz. [K25]); aynı aralık, iki ayrı anlam.

**[K11] Headscale (Tailscale koordinasyon sunucusunun açık kaynaklı karşılığı), https://github.com/juanfont/headscale** (belge: README)
- "It implements a narrow scope, a _single_ Tailscale network (tailnet)" ; "we do not support nor encourage the use of reverse proxies and container to run Headscale."
- Açıklama: Kendi sunucusunu işletmek isteyenler için ek seçenek; ana yol değil.

---

## Windows

**[K12] "Enable Remote Desktop on your PC", https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/remotepc/remote-desktop-allow-access** (belge; sayfa güncelleme tarihi 2026-02-16)
- "You can use Remote Desktop to connect to computers running Windows Professional, Enterprise, Education editions, and Windows Server editions. These editions can act as hosts for incoming Remote Desktop connections. However, Windows Home editions can't serve as Remote Desktop hosts, though they can be used as clients to connect to other systems that support Remote Desktop hosting."
- "Select **Start**, select **Settings**, then select **System**. Select **Remote Desktop**, toggle the option **Enable Remote Desktop** to **On**." ; "Enabling Remote Desktop opens a port on your PC, making it accessible to devices on your local network."
- "Only enable Remote Desktop on trusted networks, such as your home network".
- "Make sure all accounts with remote access have strong, unique passwords to help protect your PC."
- "Network Level Authentication (NLA) adds an extra layer of security to Remote Desktop connections. With NLA enabled, users must authenticate themselves before a remote session is established" ; "Enabling NLA is recommended for most environments ... For best security, keep NLA enabled whenever possible."
- Açıklama: Home RDP sunucusu olamaz; Pro/Enterprise/Education olabilir. NLA (bağlantıdan önce kimlik sorma) açık kalmalı.

**[K13] "Allow access to your PC from outside your PC's network", https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/remotepc/remote-desktop-allow-outside-access** (belge)
- "If you need to connect to your PC from outside of the network your PC is running on, you need to enable that access. You have a couple of options: use port forwarding or set up a VPN."
- "You're opening your PC up to the internet, which isn't recommended. If you must, make sure you have a strong password set for your PC. It's preferable to use a VPN".
- "If you connect to your local area network by using a virtual private network (VPN), you don't have to open your PC to the public internet."
- Açıklama: Microsoft da modemde port açmayı önermiyor, VPN (burada Tailscale) öneriyor.

**[K14] "How to use Remote Desktop" (Windows 11), https://support.microsoft.com/en-us/windows/how-to-use-remote-desktop-5fe128d5-8fb1-7a23-3b8a-41e636865e8c** (belge)
- "The PC you want to connect to (the remote PC) must be running Windows Pro edition of Windows. The device you connect from (the client device) can be running any edition of Windows (Pro or Home), or even a different operating system altogether." ; "confirm that Edition shows Windows 11 Pro".
- Açıklama: Windows 11'de de aynı kural: bağlanılan bilgisayar Pro olmalı.

**[K15] `netsh advfirewall`, https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/netsh-advfirewall** (belge)
- "export `<path\filename>`: Exports the current firewall policy settings to a specified file." ; "import `<path\filename>`: Imports firewall policy settings from a specified file into the current policy store."
- Örnekler: `netsh advfirewall export "C:\folder\firewall_backup.wfw"` ve `netsh advfirewall import "C:\folder\firewall_config.wfw"`.
- Açıklama: Duvar ayarını yedekleyip geri yükleme yolu (`geri_al_zamanlayici.ps1` bunu kullanır).

**[K16] Zamanlanmış görev cmdlet'leri (ScheduledTasks)** (belge): https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasksettingsset , .../new-scheduledtasktrigger , .../new-scheduledtaskprincipal , .../register-scheduledtask
- `-Hidden`: "Indicates that the task is hidden in the Task Scheduler UI." ; `-Once`: "Indicates that a trigger starts a task once at a time specified in the *At* parameter." ; `-StartWhenAvailable`: "Indicates that Task Scheduler can start the task at any time after its scheduled time has passed." ; `-ExecutionTimeLimit`: "Specifies the amount of time that Task Scheduler is allowed to complete the task."
- "Well-known accounts are: NT AUTHORITY\SYSTEM, NT AUTHORITY\LOCALSERVICE, NT AUTHORITY\NETWORKSERVICE, and the well-known security identifiers (SIDs) for all three accounts." ; `-LogonType` değerleri arasında `ServiceAccount`; `-RunLevel`: "Highest. Tasks run by using the highest privileges."
- Not: "Hidden" arayüzde gizli demektir; pencerenin hiç açılmaması görevin SYSTEM hesabıyla arka planda çalışmasından gelir (ilke, belgeden doğrulanmadı).

**[K17] Güvenlik duvarı cmdlet'leri (NetSecurity)** (belge): https://learn.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule , .../disable-netfirewallrule
- `-InterfaceAlias`: "Specifies the alias of the interface that applies to the traffic." ; `-RemoteAddress`: "Specifies that network packets with matching IP addresses match this rule. This parameter value is an IPv4 or IPv6 address, subnet, range or keyword." (biçim: "IPv4 Subnet (by network bit count): 1.2.3.4/24") ; `-Profile`: "The acceptable values for this parameter are: Any, Domain, Private, Public, or NotApplicable. The default value is Any."
- Disable-NetFirewallRule: "IMPORTANT NOTE: Running this cmdlet without parameters disables all Windows Firewall rules on the target computer." ; "A Disabled rule will not actively modify system behavior, but the rule still exists on the computer ... so it can be re-enabled." ; `-Name`: "Specifies that only matching firewall rules of the indicated name are disabled."
- Açıklama: Parametresiz `Disable-NetFirewallRule` bütün duvar kurallarını kapatır; betikler yalnız adlandırılmış kuralları kapatır.

**[K18] Windows sürümünü (Home mu) makineyle okumak** (belge): https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-operatingsystem , https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getproductinfo
- `Win32_OperatingSystem.OperatingSystemSKU` alanı var; GetProductInfo değerleri: PRODUCT_CORE_N = 0x00000062 (98), PRODUCT_CORE_COUNTRYSPECIFIC = 0x00000063 (99), PRODUCT_CORE_SINGLELANGUAGE = 0x00000064 (100); win32_operatingsystem sayfasında "PRODUCT_CORE (101)".
- Açıklama: Bu numaralar Home (Core) ailesidir; `kontrol.ps1` ve `rdp_tailscale_kilit.ps1` sürümü böyle tanır.

---

## RustDesk

**[K19] Self-host sayfası, https://rustdesk.com/docs/en/self-host/** (belge)
- "hbbs - RustDesk ID (rendezvous / signaling) server, listen on TCP (21114 - for http in Pro only, 21115, 21116, 21118 for web socket) and UDP (21116)" ; "hbbr - RustDesk relay server, listen on TCP (21117, 21119 for web socket)".
- "When you start a connection from computer A to computer B, computer A contacts the ID server and requests to communicate with computer B. The ID server then attempts to connect A and B directly to each other using hole punching. If hole punching fails, A will communicate with B via the relay server (hbbr). In the majority of cases, hole punching is successful, and the relay server is never used."
- "Ports 21115 - 21117 are the minimum required ports for RustDesk to work." ; "RustDesk also supports a deployment mode where only TCP 443 is exposed" (cümlenin devamı sayfada).
- Açıklama: RustDesk'in kendi sunucusu da tanıştırıcı + röle iki parçadan oluşur. Bu rehberin ana yolu RustDesk'in sunucusunu kullanmaz (Tailscale adresiyle bağlanılır); bu port listesi yalnız "kendi RustDesk sunucum olsun" diyenler için bilgidir.

**[K20] Gelişmiş ayarlar, https://rustdesk.com/docs/en/self-host/client-configuration/advanced-settings/** (belge)
- `direct-server`: "Enable direct IP access." Konum: "Desktop ... Settings → Security → Security → Enable direct IP access"; mobil: "Settings → Share screen → Direct IP access". Varsayılan: N (kapalı). Örnek: `direct-server=Y`.
- `direct-access-port`: "Direct IP access port." Varsayılan ve örnek: `21118` (`direct-access-port=21118`).
- `whitelist`: "Use IP Whitelisting." Konum: "Settings → Security → Security → Use IP Whitelisting". Boş değer "means no filter"; "CIDR notation is supported, e.g. whitelist=192.168.1.0/24,10.0.0.5."
- `enable-file-transfer`: "Enable file copy and paste or file transfer (session) for incoming connections." Konum: "Desktop Settings → Security → Permissions → Enable file transfer". Varsayılan: "Y" (2026-11-11 okundu).
- `id-whitelist`: "Note: The ID is reported by the connecting client, so it is not an authentication mechanism. This whitelist reduces exposure, it does not replace the password or 2FA."
- `approve-mode`: "Accept incoming connections via password or manually click." Konum: "Desktop Settings → Security → Password"; değerler password, click, password-click (varsayılan password-click). `verification-method`: "What type of password can be used, temporary password refers to the one-time random password.", değerler use-temporary-password, use-permanent-password, use-both-passwords (varsayılan use-both-passwords).
- Sayfa kapsamı: ayarlar "RustDesk custom clients, user settings, and server-side policy" için.
- Açıklama: Doğrudan IP ayarının adı, portu ve beyaz listenin CIDR kabul ettiği belgeli. **Bu ayarın Tailscale adresiyle birlikte kullanımını anlatan resmî bir sayfa bulunamadı**; gerçek iki-ağ testi bu yüzden `TEST_PLANI.md`'de "kritik kontrol".

**[K21] RustDesk istemci sayfası, https://rustdesk.com/docs/en/client/** (belge)
- Windows kurulumu: "Download the exe from GitHub and install. To install silently call the install exe with --silent-install."
- Komut satırı: "--password can be used to set a permanent password. --get-id can be used to retrieve the ID. --set-id can be used to set an ID, please note IDs should start with a letter. --silent-install can be used to install RustDesk silently on Windows."
- Ayar aktarma: "--config to import settings. To do this: Open command line on whichever OS you use, to the folder where RustDesk is installed i.e. C:\Program Files\RustDesk on Windows" ; "rustdesk.exe --config your-encrypted-string" (Pro şifreli yapılandırma dizisi) ; "--import-config" (yalnız ağ/sunucu ayarları bağlamında, kullanıcı klasöründeki RustDesk2.toml için).
- Açıklama: Kurulum klasörü `C:\Program Files\RustDesk`.

**[K22] Taşınabilir sürüm ve yönetici onay ekranı (UAC), https://rustdesk.com/docs/en/client/windows/windows-portable-elevation/** (belge)
- "The screen cannot be transmitted when the UAC (User Account Control) window pops up. When an elevated window, such as the Task Manager, pops up, the mouse becomes unresponsive." ; "No elevation required Install the program" ; "Installing the full program is still the better option when you do not specifically need the portable workflow" ; "Control-end requested elevation still requires someone on the controlled side to accept the UAC prompt".
- Açıklama: Taşınabilir exe değil, kurulu sürüm; yönetici onay (UAC) penceresi taşınabilir sürümde aktarılmıyor.

---

## Standartlar

**[K23] RFC 4787 (NAT UDP davranışı), https://datatracker.ietf.org/doc/html/rfc4787** (belge)
- "REQ-5: A NAT UDP mapping timer MUST NOT expire in less than two minutes, unless REQ-5a applies."
- Açıklama: Standart alt sınır 2 dakika; pratikte cihazlar kısa tutabilir ([K1]: "a common value for UDP is 30 seconds"). Hazır araç canlı tutmayı kendi yapar; rehber ayar önermez.

**[K24] RFC 6888 (CGN gereksinimleri), https://datatracker.ietf.org/doc/html/rfc6888** (belge)
- "REQ-4: A CGN MUST support limiting the number of external ports (or, equivalently, "identifiers" for ICMP) that are assigned per subscriber."
- "REQ-9: A CGN MUST implement a protocol giving subscribers explicit control over NAT mappings. That protocol SHOULD be the Port Control Protocol".
- Açıklama: Operatörün ortak adresinde abone başına port sınırı konabilir; abonenin kendi modeminde açtığı port operatörün ortak NAT'ını yönetmez.

**[K25] RFC 6598 (ortak adres alanı), https://datatracker.ietf.org/doc/html/rfc6598** (belge)
- "The Shared Address Space address range is 100.64.0.0/10." ; "...to be used as Shared Address Space to accommodate the needs of Carrier-Grade NAT (CGN) devices."
- Açıklama: 100.64.0.0/10, operatör ortak NAT'ının (CGNAT) iç adres aralığıdır; Tailscale da cihaz adreslerini aynı aralıktan verir ([K10]).

---

## Güvenilirlik ve olgunluk

**[K26] cbdesk (örnek bir açık kaynak uzak masaüstü projesi), https://github.com/cumabozkurt/cbdesk (README)** (belge)
- "CBDesk is an unsigned alpha of a consented remote desktop".
- "Windows SmartScreen can warn or block them (unknown publisher)." ; "`SHA256SUMS` is a list of digests, not a signature."
- "There has been no external cryptography review and no external audit."
- "A live symmetric NAT was not measured. A loopback path is not a hole punch."
- "That is the expected result for this unsigned alpha ... Do not disable those protections because a stranger asked you to."
- Lisans: AGPL-3.0-or-later; sürüm: etiket `v0.1.0-alpha.1` (kod ağacındaki paket sürümü 0.0.0).
- Açıklama: Ana tarife girmez; dürüst bir alfa, README'sine göre ölçülmemiş.

---

## Türkiye (operatör ve mevzuat)

**[K27] "Türk Telekom CGNAT'tan Statik IP Olmadan Nasıl Çıkılır?", https://natchecker.com/tr/blog/turk-telekom-cgnat-cikarma-statik-ip-olmadan** (ikincil: ticari blog; sayfada tarih "30 Eki 2026")
- "Türk Telekom CGNAT kullanıyorsa ev routerinizde açtığınız port, operatörün üst ağındaki paylaşım katmanını geçemez."
- "Türk Telekom hattında statik IP almadan ilk seçenek müşteri hizmetlerinden dinamik genel IPv4 istemektir."
- Hangi hatlarda CGNAT olduğunu belirtmiyor; statik IP fiyatını vermiyor ("güncel tutarı hesabınızdan ... doğrulayın").
- Açıklama: Yön gösterir, kanıt değil. Operatör ve pakete göre değişir.

**[K28] Türk Telekom toptan "PTS ek protokol", https://toptan.turktelekom.com.tr/media/adpewsb2/pts-ek-protokol-010422.pdf** (özet: ham PDF iki denemede açılmadı, HTTP 404; alıntı arama aracının özetinden)
- "IP atamalarında var olan gerçek IP kaynağının durumuna göre CGNAT yöntemiyle sanal IP ataması yapılabilecektir." ve "Sanal IP ataması yapılmış abonelikler için Gerçek IP - Sanal IP ve port eşleştirme bilgilerini de içeren CDR kayıtları Türk Telekom tarafından paylaşılacaktır."
- Açıklama: Operatörler arası toptan sözleşme eki; CGNAT'ın kullanılan ve kayda geçen bir uygulama olduğunu gösterir (yorum). Ham metin doğrulanana kadar rehberde dayanak olarak gösterilmez.

**[K29] TurkNet "CGN IP havuzu" forum konusu (Mayıs-Ekim 2017), https://forum.donanimhaber.com/turknet-gercek-ip-alamama-sorunu-cgn-ip-havuzu--126047390** (ikincil: forum, 9 yıllık)
- Konu sahibi: "CGN NAT ip havuzundan çıkmanın bir yolu var mı arkadaşlar ? (Statik ip satın almak haricinde)"; başka kullanıcı: "Güvenlik nedeniyle acmazlar".
- Açıklama: Anekdot, resmî açıklama değil, güncel durum bilinmiyor.

**[K30] IPv6 yaygınlığı** (özet: arama aracının özeti; ham sayfalar açılamadı ya da sayı vermedi)
- Internet Society (Haziran 2018) özeti: Türkiye "G20'de IPv6'sı %5'ten az görülen ülkeler" arasında. ipv6-test.com (Kasım 2023 verisi) özeti: TurkNet'in benzersiz IPv6 adresi sayısı en fazla, ardından Turkcell ve Superonline. Güncel Türkiye yüzdesi **bulunamadı** (Google IPv6 istatistik sayfası grafik olduğu için sayı vermedi).
- Açıklama: IPv6 bazı hatlarda CGNAT'ı atlatabilir ama hatta, operatöre ve modeme bağlı; rehber IPv6'ya güvenmez.

**[K31] "Türkiye'de sabit IP'siz port açmak yasak" sözü için kaynak** (bulunamadı)
- Arananlar: BTK mevzuatı ve kararları, 5651 sayılı Kanun ve erişim sağlayıcı yönetmelikleri, operatör sayfaları ve sözleşme ekleri (web arama özetleri; ham mevzuat metinlerinin tamamı açılmadı). Hiçbirinde bu yönde bir hüküm çıkmadı.
- Rehberde kullanılan cümle: "Yasak olduğuna dair kaynak bulamadık; port açamamanın asıl nedeni CGNAT." Bu hukuki danışmanlık değildir ve "yasak değil" demek de değildir.

---

## Doğrulanmayanlar ve kritik kontroller

Belgede bulunamayan ya da denenmemiş, rehberde "kesin" diye geçmeyen şeyler (hepsi `TEST_PLANI.md`'de kritik kontrol olarak yer alır):
1. Tailscale'in Windows hizmet adının `Tailscale` ve RustDesk'in `RustDesk` olduğu (`kontrol.ps1` bunları adla arar; yanlışsa "YOK" der, tehlikeli değil).
2. `tailscale status` satırında `;` sonrası bağlantı türünün yazılış düzeni (belge tür sözcüklerini veriyor, satır düzenini vermiyor).
3. `tailscale netcheck` çıktısındaki "Alan: değer" düzeni (belge alan adlarını anlatıyor, örnek çıktı göstermiyor).
4. `powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE` takma adları (Windows 10 Home Türkçe'de çalıştı; başka sürümlerde denenmedi).
5. Windows `EditionID` değerlerinin (Core*, Professional...) Home/Pro eşlemesi (belge değil, gözlem).
6. (Kısmen kapandı: doğrudan IP portu 21118'in TCP dinlediği Windows 10'da RustDesk 1.5.3'te `netstat` ile görüldü, tek makine, belge değil; Windows 11 ve başka sürümlerde denenmedi. RustDesk ayrıca UDP 21119 dinliyor, işlevi belgede yok.) Hâlâ açık: kontrol eden tarafta IP'nin hangi biçimde yazılacağı; RustDesk'in Tailscale adresiyle kullanımını anlatan resmî tarif; kurulu RustDesk'in Windows hizmeti olarak çalışıp kilit ekranını yönettiği; `direct-server`'ı komut satırından değiştiren belgeli yöntem.

---

## İlke maddeleri

Şunlar belge değil, çalışma ilkesidir ve rehberde "ilke" diye geçer: sırları sohbete yazmama; adım adım onay; `DURUM.md`; iki kapı kuralı (yeni yol ikinci cihazdan kanıtlanmadan eskisi kapanmaz); geri alma zamanlayıcısı; "çalıştı demek için kanıt komutu"; "yöntemi gizlemek güvenlik değildir". Veri klasörünü kilitleme (ACL) için S-1-5-18 (SYSTEM) ve S-1-5-32-544 (Administrators) SID'leri Windows'un genel bilgisidir; yalnız `icacls` belgesinin "If you use a numerical form, affix the wildcard character * to the beginning of the SID." cümlesi ve `F` (tam yetki) kullanımı doğrulandı.

---

## Ek kaynaklar (uyku, Türkiye, Uzak Masaüstü, ajanlar, RustDesk sorunları, Tailscale anahtar süresi)

**[K32] Windows "Sleep idle timeout" güç ayarı: 0 = hiç uyumaz** (belge, ham sayfa, 2026-11-11): https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/sleep-settings-sleep-idle-timeout
- Ham metin: "0 (Never idle to sleep)".
- Açıklama: `powercfg /change` sayfası değeri yalnız "dakika" diye tanımlıyor, 0'ı tanımlamıyor; 0'ın anlamı bu ayar sayfasından. "15 dk bekleme" sınaması TEST_PLANI'nda.

**[K33] İFÖD EngelliWeb 2025 raporu, "VPN engellemeleri", https://ifade.org.tr/en/reports/engelliweb-2025/11-vpn-blockings/** (belge, ham sayfa, 2026-11-11; yazar bir hak kuruluşu, resmî kurum değil)
- "there is no statutory provision prohibiting the use of VPN services from Türkiye"
- "BTK's blocking list has not been confined to those 16 VPN services. EngelliWeb project, as of 2023, identified 26 different VPN services"; dayanak: "BTK, circular letter no E-34817124-421.99-72342, 23.11.2023."
- "a selective slowing and connection-instability mechanism triggered through TLS SNI/Host information was detected" (Proton VPN sunucularına bağlantılarda yapılan testler).
- "A draft amendment that emerged in April 2026 envisages adding to Article 3 of Law No. 5809 the definitions of "virtual network service" and "virtual network service provider"." (taslak)
- Açıklama: Rapor Tailscale, ZeroTier, RustDesk, AnyDesk ve WireGuard'ı anmıyor (arama: 0 eşleşme); bu "engelli değil" demek değildir. Hak kuruluşunun görüşünü içerir, hukuki danışmanlık değildir.

### Uzak Masaüstü: güvensiz çözümler ve dolandırıcılık

**[K34] CredSSP güncellemesi, https://support.microsoft.com/en-us/help/4093492** (özet: alıntı arama aracı özetinden, ham sayfa açılmadı)
- "Vulnerable: Client applications that use CredSSP will expose remote servers to attacks by supporting fallback to insecure versions" / "Services that use CredSSP will accept unpatched clients." / "Both the client and server need to be updated."
- Açıklama: Rehberde "belge" diye değil "özet" etiketiyle kullanılır (C2 CredSSP satırı).

**[K35] Birleştirildi:** aynı kaynak K13 numarasındadır (Microsoft "Allow access to your PC from outside", ham alıntılar K13'te).

**[K36] RDP NLA önerisi** (aynı alıntı K13'teki sayfada; adres K13)
- "Enabling NLA is recommended for most environments ... For best security, keep NLA enabled whenever possible."

**[K37] Windows istemcisi tek oturum, https://learn.microsoft.com/en-us/answers/questions/1665158/how-can-i-keep-both-ends-operating-at-the-same-tim** (topluluk, resmî Microsoft ifadesi değil)
- "which by design, permits only one user login at a time."

**[K38] Disable-NetFirewallRule** (aynı alıntı K17'de; adres K17)
- "IMPORTANT NOTE: Running this cmdlet without parameters disables all Windows Firewall rules on the target computer."

**[K39] AnyDesk kötüye kullanım sayfası, https://support.anydesk.com/docs/abuse-management.md** (belge; C1 gerekçesi, ajan mesajına alıntı konmaz)
- "Never share access codes to your devices with anyone." / "Only grant remote access to trusted parties." / "Scammers pose as Microsoft technicians, claiming they need to clean your device of malicious software."

### Ajanlar: kural dosyaları ve onay

**[K40] Onay yorgunluğu, https://anthropic.com/engineering/claude-code-auto-mode** (belge)
- "Over time that leads to approval fatigue, where people stop paying close attention to what they're approving." / "in practice users accept 93% of them anyway." İzinleri kapatmak "is unsafe in most situations."
- Açıklama: %93 yalnız Claude Code kullanıcıları için; rehberin kullanıcıları için değil.

**[K41] Claude Code kural dosyaları, https://code.claude.com/docs/en/memory** (belge; eski docs.anthropic.com adresi buraya yönleniyor)
- "Each Claude Code session begins with a fresh context window." / "Claude treats them as context, not enforced configuration." / "target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence."
- "Claude Code can read `AGENTS.md` as your project instructions, so a repository already set up for other coding agents works without adding a `CLAUDE.md`, an import, or a setting."
- Tablo: `AGENTS.md` ve `CLAUDE.md` birlikteyse "Your `CLAUDE.md` files only"; "A `CLAUDE.md` that already imports `AGENTS.md` → Your `CLAUDE.md`, with `AGENTS.md` included through the import". "CLAUDE.md files can import additional files using `@path/to/import` syntax."

**[K42] Codex AGENTS.md, https://learn.chatgpt.com/docs/agent-configuration/agents-md** (belge; eski developers.openai.com adresi yönleniyor)
- "Codex reads `AGENTS.md` files before doing any work." / "Starting at the project root (typically the Git root), Codex walks down to your current working directory." Boyut tavanı 32 KiB. `@` içe alma ve Git deposu olmayan klasör davranışı sayfada **bulunamadı** (TEST_PLANI T13).

**[K43] Cursor AGENTS.md, https://cursor.com/docs/context/rules** (belge; eski docs.cursor.com adresi yönleniyor)
- "Cursor supports AGENTS.md in the project root and subdirectories." / "Unlike Project Rules, `AGENTS.md` is a plain markdown file without metadata or complex configurations." `AGENTS.md` içinde `@` kullanımı **bulunamadı**.

**[K44] Uydurma komut/bayrak şikâyeti** (ikincil, blog/satıcı yazıları; birincil kaynak bulunamadı). Rehberde sayı ya da iddia olarak kullanılmaz; yalnız F metnindeki "önce `--help`" adımının gerekçesi.

**[K45] Yönetici (elevated) oturum karışıklığı: anthropics/claude-code issue #106843** (yalnız başlık okundu, gövde okunmadı; rehbere girmez). Başlık: "claude agents --json omits sessions that run elevated when the command runs from a non-elevated terminal".

### RustDesk: beklenen ekranlar ve bilinen sorunlar
Okuma tarihi 2026-11-11. RustDesk istemci ve UAC sayfaları K21 ve K22'dedir.

**[K46] Tailscale blog, "Tailscale and RustDesk: Secure remote access to all your desktops", 10 Temmuz 2025, https://tailscale.com/blog/tailscale-rustdesk-remote-desktop-access** (belge, ham sayfa)
- "you need to enable one thing to let Tailscale work its magic: "Enable direct IP access," under the "Security" sub-section."
- "Paste the Tailnet IP of the device you want to control into the "Control Remote Desktop" section of the RustDesk window. If you've enabled the setting for direct IP access, RustDesk should connect, then prompt you for the access password you set up."
- "You might notice a little red shield with an "X" near the top of your RustDesk viewing client, reporting a "direct and unencrypted connection." RustDesk doesn't know that all the traffic going between two Tailscale devices is encrypted, but it is."
- "... for connecting directly to our own devices, we can use the IP address that Tailscale provides." ; "Normally ... you can use RustDesk's nine-digit ID number to connect. This uses RustDesk's public, slower relays."

**[K47] RustDesk geliştirici yanıtı, issue #3714, 12 Kasım 2025, https://github.com/rustdesk/rustdesk/issues/3714#issuecomment-3519568715** (belge: geliştirici)
- "We don't plan to implement this directly, as it is designed for test initially, we do not recommend using RustDesk with a public IP alone, that's also why direct ip access is turned off by default."
- "For security and privacy, we strongly advise using it in combination with a VPN—the VPN tunnel already provides end-to-end encryption, so additional encryption within RustDesk is unnecessary in that setup."

**[K48] RustDesk wiki SSS, https://github.com/rustdesk/rustdesk/wiki/FAQ (ham: raw.githubusercontent.com/wiki/rustdesk/rustdesk/FAQ.md)** (belge; tarihsiz; bazı cevaplar Reddit kaynaklı = ikincil)
- Doğrudan IP: "Enable direct ip access on controlled side ... On the client you are connecting from you can now input the Local IP address or host name the address box and click connect.; the connection is unecrypted, please do not send us issue about this.; You can not use hostname, because we do not it is id or a name, but there is a workaround ..." (yazım hataları kaynakta)
- Windows UAC: "When you run RustDesk on Windows without installation (installed version does not have this issue), you will find the window is freeze when you open system settings, task manager etc. This is classic Windows UAC limitation. ... or install it on controlled side."
- "Windows service won't start on reboot": "I fix it by setting the service to delayed start." komut `sc config rustdesk start= delayed-auto` (ikincil, denenmedi; hizmet adı `rustdesk` yalnız bu satırdan).
- "RustDesk Service does not start automatically": "Yes, I stopped the service via the tray icon in Windows. My mistake!"
- Sabit parola: "Please also make sure the following options are configured: `Accept sessions via both` or `Accept sessions via password`; `Use both passwords` or `Use permanent password`".
- "Failed to connect via rendezvous server": "Ensure the controlled side can connect to `hbbs` with tcp `21116` port".
- K21'e (istemci sayfası) ek alıntılar: "You will see a message at the bottom saying (1) "Ready, For faster connection, please set up your own server"." ; Ayarlar: "General - Service Control ... Security - Permissions for someone taking control, Password options ...".

**[K49] Issue #5609 "waiting for image" issues, https://github.com/rustdesk/rustdesk/issues/5609** (açık; 2023-09-05, son güncelleme 2026-09-04; kullanıcı raporu + geliştirici yorumu)
- Gövde "# Unresolved" listesi (#5608, #2175, #6419).
- Aktarılmış Reddit çözümü, geliştirici yorumu 2023-12-18 (**ikincil**): "The issue is evidently the Windows Lock Screen on login. The fix was to install the program on both ends. Using the standalone at either end would not suffice. Once installed, change the security settings to allow for keyboard and mouse. This enables the ability to send a CTRL-ALT-DELETE ..." (#issuecomment-1859712970)

**[K50] Issue #2175, https://github.com/rustdesk/rustdesk/issues/2175** (kapalı, 2022-11-17; v1.1.9). Geliştirici: "install"; sonra "can not connect if service not open."; "traced by .../5609".

**[K51] Issue #14827, https://github.com/rustdesk/rustdesk/issues/14827** (kapalı, 2026-04-16; Linux, Nobara/Fedora 43; RustDesk sürümü yazılmamış; kullanıcı raporu)
- "two of them are inaccessible, and present the connection error 'Failed to connect to [Tailscale IP]:21118: Please try later'. If I swap back to their regular device IDs and connect via the public servers the connection works fine." Geliştirici: "You should ask tailscale, not us." Kök neden bilinmiyor.

**[K52] Issue #15443, https://github.com/rustdesk/rustdesk/issues/15443** (kapalı, 2026-06-26; RustDesk 1.4.8, Windows 10; tek rapor)
- "Every time I reboot a remote Windows 10 machine (in my local net), I have to log in using a different remote control program, enable direct IP access, and reset the password in RustDesk's settings." Kullanıcının tahmini: AppData\Roaming\RustDesk'in başka sürücüye bağlantı olması. Yorum yok.

**[K53] Issue #4862, https://github.com/rustdesk/rustdesk/issues/4862** (kapalı, 2023-07-04; RustDesk 1.2.0)
- "When i use the IP address as ID, everything work as expected. When i use the hostname, then i get the error message "ID not found"."

**[K54] Issue #16493, https://github.com/rustdesk/rustdesk/issues/16493** (kapalı, 2026-10-07; RustDesk 1.5.0, Windows 11; tek rapor)
- "RustDesk 1.5.0: clicking Start Service triggers Bitdefender Antivirus "Disinfection"; service fails to register/start." ; "Downgrading to RustDesk 1.4.9 completely eliminates the problem". Geliştirici (2026-10-08): "Close this old topic, sorry, I do not want to explain again and again."

Bulunamayan: 21118'in TCP/UDP olduğu; hizmet adının resmî belgede yazılı olduğu; "Service Control"ün Türkçe adı; #5074/#11206/#7334/#13782 (yalnız başlık, gövde okunmadı, tabloya alınmadı).

### Tailscale: anahtar süresi, kurulum hizmetleri, röle nedeni
Bağlantı türleri K2, röle K5, cihaz bağlanabilirliği K9'dadır. Yeni olanlar:

**[K55] Tailscale, "Key expiry", https://tailscale.com/kb/1028/key-expiry** (belge)
- "By default, new domains are set with an expiry period of 180 days." / "If reauthentication does not occur, keys expire and connections to/from the given endpoint will stop working."
- Disable Key Expiry sonrası: "Done. The keys for that device will no longer expire." ; "You may want to disable key expiry on some devices, such as trusted servers, subnet routers," ... "or remote IoT devices that are hard to reach."
- "Be aware that `tailscale up --force-reauth` might bring down the tailnet connection and thus should not be done remotely" ... "without an alternate means to log in if the connection is lost." (iki parça; aradaki ifade sayfada.)

**[K56] Tailscale, Windows install error, https://tailscale.com/docs/reference/troubleshooting/windows/windows-install-error** (belge)
- "The Tailscale client installer requires the following Windows system services to be running:" `Dnscache`, `iphlpsvc`, `netprofm`, `WinHttpAutoProxySvc`; "If the installer does not detect that these services are running, it will automatically fail." Sayfada çözüm adımı yok.

K9 notu (özet): alan adları sayfadan; sayfa netcheck örnek çıktısı göstermiyor; betik `Ad: değer` düzenini varsayar, TEST_PLANI'nda teyit edilmeli. K2 ek alıntı: "Here, the first few packets go through the nearest DERP server while Tailscale negotiates a direct connection." K5 ek alıntı: "A DERP server blindly forwards already-encrypted traffic from one device to another."

### Karşılaştırma ("Neden bu yol?", README)

**[K57] TeamViewer, "Commercial use suspected", https://www.teamviewer.com/en/global/support/knowledge-base/teamviewer-classic/licensing/personal-use/commercial-use-suspected** (belge; 2026-11-11 okundu)
- "We define commercial use as being any use of TeamViewer for purposes that are either directly or indirectly paid for."
- "Our specialist team investigates every case and will unblock your device (TeamViewer ID) if it has been limited by mistake."
- Bulunamadı: AnyDesk'in ticari kullanım sayfası (https://anydesk.com/en/commercial-use) bu çalışmada HTTP 403 verdi; AnyDesk için ticari kullanım ya da veri yolu cümlesi alıntılanmadı.

**[K58] Tailscale, Connection types, https://tailscale.com/kb/1257/connection-types** (belge; "Last validated: Jun 1, 2026")
- "Tailscale connects devices within a Tailscale network (known as a tailnet) using three connection types:" ... "Direct connections: Devices send packets directly to each other using UDP."
- "The primary difference between them is performance, not security."

**[K59] Tailscale, Security, https://tailscale.com/security** ve **What is Tailscale, https://tailscale.com/kb/1151/what-is-tailscale** (belge)
- "Tailscale cannot read your traffic." ; "Tailscale does not (and cannot) inspect your traffic."
- "It enables encrypted point-to-point connections using the open source WireGuard protocol, which means only devices on your private network can communicate with each other."

**[K60] RustDesk lisansı, https://raw.githubusercontent.com/rustdesk/rustdesk/master/LICENCE** (belge; ham dosya başlığı)
- "GNU AFFERO GENERAL PUBLIC LICENSE Version 3, 19 November 2007"

**[K61] Tailscale kaynak deposu, https://github.com/tailscale/tailscale** (belge; README ve LICENSE ham)
- README: "This repository contains the majority of Tailscale's open source code." ; LICENSE: "BSD 3-Clause License".

**[K62] Tailscale, Taildrop, https://tailscale.com/kb/1106/taildrop** (belge; 2026-11-11 okundu)
- "Taildrop lets you send files between your personal devices on a Tailscale network (known as a tailnet)."
- "Taildrop is currently in alpha." ; "Taildrop is available for all plans." ; sayfaya göre ağın katılması (opt-in) gerekir: yönetim sayfası, General ayarları, "Send Files".
- Windows: sağ tık "Send with Tailscale"; gelen dosya kullanıcının İndirilenler (Downloads) klasörüne. iOS: Paylaş menüsünden gönderilir; gelen dosya bildirim açar.
- "transfers files over encrypted peer-to-peer connections, using the fastest available path." ; "Taildrop is currently limited to sending files between your own personal devices."

**[K62 ek] Tailscale, Taildrop, https://tailscale.com/kb/1106/taildrop** (belge; KOPRU.md için ek alıntılar)
- "You cannot send files to devices owned by other users" ; "You cannot use Taildrop to send files to and from nodes you have tagged."
- "Because it's an alpha feature, you must opt in" ... "turn on the 'Send Files' feature."

**[K63] OWASP, LLM01 Prompt Injection, https://genai.owasp.org/llmrisk/llm01-prompt-injection/** (belge; KOPRU.md "Güvenlik")
- "Indirect prompt injections occur when an LLM accepts input from external sources, such as websites or files."

**[K64] OWASP, LLM06 Excessive Agency, https://genai.owasp.org/llmrisk/llm062025-excessive-agency/** (belge; KOPRU.md "Güvenlik")
- "Implement authorization in downstream systems rather than relying on an LLM to decide if an action is allowed or not."

**[K65] Claude Code, İzinler, https://code.claude.com/docs/en/permissions** (belge; KOPRU.md "Güvenlik" ve REHBER Adım 6b)
- "Bash permission patterns that try to constrain command arguments are fragile."
- "`permissions.allow` rules and `permissions.additionalDirectories` entries in a project's `.claude/settings.json` grant capability, so Claude Code applies them only after you accept the workspace trust dialog for that folder. The dialog lists the rules and directories the folder would grant so you can review them first."
- "Every subcommand must be allowed for a compound command to run without a prompt"
- "Rules are evaluated in order: deny, then ask, then allow."

**[K66] Claude Code, Tools reference: https://code.claude.com/docs/en/tools-reference** (belge; okundu 2026-11-11)
- "Windows: the tool is available only when Git Bash is installed" (Monitor aracı için).
- "Windows without Git Bash: the tool is enabled automatically." (PowerShell aracı)
- "When the tool is enabled, Claude treats PowerShell as the primary shell."
- "A command that the main conversation ... started keeps running after a final response, until it exits, is stopped, or reaches its time limit." (arka plan komutu)

**[K60] Tailscale, Security bulletins, https://tailscale.com/security-bulletins** (belge, 2026-11-13 okundu; özet araçla, birebir alıntı kısa)
- TS-2026-014..017 (26 Ekim 2026, "Tailworm" bulguları): Tailscale SSH ve Tailscale Serve özelliklerinde; düzeltme 1.104.4. Saldırganın tailnet içinde yetkili bir cihazı olması gerekir.
- Açıklama: Bu rehber Tailscale SSH ve Serve kullanmaz; Adım 4 madde 9-10 sürümü ve bu özelliklerin kapalı olduğunu denetletir. Tailscale SSH sunucusu Windows'ta çalışmaz (Tailscale SSH belgesi).
