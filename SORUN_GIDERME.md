# Sorun giderme: 15 sık hata, 7 doğru bilinen yanlış

Bu dosya iki şey için: (1) bir şey ters gidince "bu hangisi?" diye bakmak, (2) kurmaya başlamadan önce tuzakları bilmek.
Her maddede **Belirti** (ne görürsün), **Neden**, **Çare** (ajanına tek cümle ya da `araclar\` altındaki betik), **Kaynak** ([K#] numaraları `KAYNAKLAR.md` içinde). Kaynağı "ilke" olan madde belgeye değil çalışma ilkesine dayanır.
Teknik kelimeler ilk geçtiği yerde parantezle açıklandı. Betikler değiştirdiği her şeyi önce "ne yapacağını yazar" (`-DryRun`, varsayılan), sen onaylayınca `-Uygula` ile yapar. Tek istisna: `geri_al_zamanlayici.ps1 -Iptal` `-Uygula` olmadan da gerçek iş yapar (bekleyen geri alma görevini kaldırır); yalnız ne yapacağını yazmasını istersen `-Iptal -DryRun`. Betikler şu biçimde çalıştırılır: `powershell -NoProfile -ExecutionPolicy Bypass -File araclar\<betik>.ps1 ...` (duvarı değiştirenler için "Yönetici PowerShell" açılır).

---

## A. 15 sık yapılan hata

### 1. "Sunucusuz" sanıp tanıştırıcıyı ve yedek yolu (röle) unutmak
- **Belirti:** İki bilgisayar birbirini bulamaz; ya da aynı evde çalışır, dışarıdan hiç bağlanmaz.
- **Neden:** İki taraf birbirinin adresini bir yerden öğrenmek zorunda (tanıştırıcı). Doğrudan yol kurulamazsa şifreli paketleri taşıyan aracı (röle) devreye girer. Bu eksikliktir değil, normal tasarımdır.
- **Çare:** Hazır araç kullan (bu rehber Tailscale kullanır, tanıştırıcı ve röle hazır gelir). Ajanına: "Tanıştırıcı ve röle yedeği olmayan hiçbir çözüm önerme; Tailscale'in hazır sunucularını kullan."
- **Kaynak:** [K1], [K2], [K19].

### 2. Aynı ağda ya da sanal makinede test edip "internetten çalışıyor" demek
- **Belirti:** Evde "mükemmel, 5 ms"; dışarı çıkınca bağlanmıyor. Bazı uygulamalar "doğrudan · yerel ağ · 5 ms" gibi bir rozet gösterir; bu, yerel ağ ölçümüdür, internet üzerinden ölçüm değildir.
- **Neden:** Aynı ağdaki iki cihaz modemi hiç delmeden konuşur; bu internet üzerinden çalıştığını göstermez.
- **Çare:** Gerçek testi ikinci cihazı telefonun hotspot'una (telefonun interneti paylaşması) bağlayarak yap; adımlar `TEST_PLANI.md` içinde. Ajanına: "Aynı ağdaki ya da 127.0.0.1'deki denemeyi internet kanıtı olarak sunma."
- **Kaynak:** ilke (yerel ağ testi internet kanıtı sayılmaz); "direct" yalnız bağlantı türünü söyler: [K2]. Gerçek test `TEST_PLANI.md`.

### 3. Ajanın bağlandığı yolu kendi kesmesi (duvar, VPN ya da ağ ayarı)
- **Belirti:** Ajan bir ağ/güvenlik duvarı/Tailscale ayarı değiştirir, oturum donar, bilgisayara bir daha girilemez. Bu işin en pahalı hatasıdır.
- **Neden:** Ajan "ayarı düzelttiğini" sanır ama bağlandığı yolu da kapatmıştır.
- **Çare:** İki kapı kuralı: yeni yol ikinci cihazdan çalıştığı kanıtlanmadan eski yol kapanmaz. Pro'da duvarı değiştiren betik (`rdp_tailscale_kilit.ps1`) 10 dakikalık geri alma zamanlayıcısını kendisi kurar. Duvar ya da ağ ayarına ELLE dokunacaksan önce (Yönetici PowerShell, önce `-Uygula`sız çalıştırıp planı oku): `powershell -NoProfile -ExecutionPolicy Bypass -File araclar\geri_al_zamanlayici.ps1 -Dakika 10 -Uygula`; 10 dakika sonra eski ayar kendiliğinden geri gelir. Program kurulumu (Tailscale, RustDesk) zamanlayıcı gerektirmez. Yeni yol çalışınca "kalsın" de; zamanlayıcıyı kaldırmak için `powershell -NoProfile -ExecutionPolicy Bypass -File araclar\geri_al_zamanlayici.ps1 -Iptal` (bu `-Uygula` istemez, doğrudan çalışır). Ajanına: "Bağlı olduğum yolu kesme ihtimali olan adımı yapma, önce bana söyle."
- **Kaynak:** ilke (çalışma kuralı); davranışı `AGENTS.md` kural 7-9 tanımlar. Duvar yedeği ve geri yükleme komutları: [K15], [K16], [K17].

### 4. CGNAT'ı fark etmeyip modemde port açmaya uğraşmak
- **Belirti:** Modemde port açıldı, dışarıdan yine bağlanılmıyor.
- **Neden:** Birçok operatör aboneleri ortak bir adres arkasına koyar (CGNAT, operatörün ortak NAT'ı). Evdeki modemde açtığın port, operatörün üst katmanını geçmez.
- **Çare:** Port açma yolunu bırak (zaten rehber hiç port açmaz). Teşhis: modemin yönetim sayfasındaki "WAN IP" adresini bul, `powershell -NoProfile -ExecutionPolicy Bypass -File araclar\kontrol.ps1 -ModemWanIp <o adres>` çalıştır. Adres 100.64 ile 100.127 arasındaysa betik "CGNAT var" der; farklıysa "CGNAT olabilir" der (bu bir ipucudur, kesin hüküm değil). Ek ipucu (ikincil kaynak): operatörden "dinamik genel IPv4" talebi bazı hatlarda mümkün olabilir; bu rehberin yolu için gerekmez.
- **Not (Türkiye):** "Türkiye'de sabit IP'siz port açmak yasak" sözünün kaynağını bulamadık; port açamamanın asıl nedeni CGNAT. (Hukuki danışmanlık değildir.)
- **Kaynak:** [K1] (CGNAT bölümü), [K24], [K25], [K10], [K27] (ikincil), [K31].

### 5. Uzak masaüstü portunu (3389) ya da VNC (5900) internete açmak
- **Belirti:** Günler içinde güvenlik kayıtlarında yabancı adreslerden sürekli giriş denemesi (bu belirti için resmî kaynak yok: tahmin).
- **Neden:** Açık port taranır ve denenir. Microsoft da internete doğrudan açmayı önermiyor, VPN öneriyor.
- **Çare:** Modemde hiçbir port açma. Windows Pro'da (Yönetici PowerShell; önce `-Uygula`sız çalıştırıp planı oku) `powershell -NoProfile -ExecutionPolicy Bypass -File araclar\rdp_tailscale_kilit.ps1 -Uygula` uzak masaüstünü yalnız Tailscale ağından gelene açar ve geri alma zamanlayıcısını kendisi kurar. NLA (bağlantıdan önce kimlik sorma) için betik bir şey yapmaz ve bakmaz: Ayarlar > Sistem > Uzak Masaüstü'nde açık olduğunu kendin kontrol et.
- **Kaynak:** [K12], [K13], [K17] (parametresiz Disable-NetFirewallRule uyarısı).

### 6. Windows Home'u uzak masaüstü sunucusu sanmak
- **Belirti:** Ayarlarda "Uzak Masaüstü" seçeneği yok ya da çalışmıyor.
- **Neden:** Home sürümü bağlanan taraf olabilir, bağlanılan taraf olamaz.
- **Çare:** `powershell -NoProfile -ExecutionPolicy Bypass -File araclar\kontrol.ps1` Windows sürümünü söyler. Home ise rehberin 3b yolu (RustDesk), Pro ise 3a yolu. Ajanına: "Önce Windows sürümünü oku, sonra yol seç."
- **Kaynak:** [K12], [K14] (Windows 11), [K18] (sürümü makineyle okuma).

### 7. "Doğrudan mı, röle mi" bakmadan "çalışıyor" demek
- **Belirti:** Bağlanıyor ama takılıyor, gecikme yüksek; yine de "çalışıyor" deniyor.
- **Neden:** Bağlantı doğrudan kurulamayıp röleden (aracıdan) akıyor olabilir; bu normaldir ama yavaştır.
- **Çare:** `powershell -NoProfile -ExecutionPolicy Bypass -File araclar\baglanti_kanit.ps1 -Es <öbür bilgisayarın Tailscale adı>` ya da `tailscale status` çıktısında "direct" mi "relay" mı yazdığını göster. "relay" çıktıysa hata değil, nedeni bul (madde 9, madde 4'teki zor NAT).
- **Kaynak:** [K2], [K3] (`tailscale ping --until-direct`).

### 8. Ping'i uzak masaüstünün gecikmesi sanmak
- **Belirti:** Ping 10 ms ama fare ekranda 200 ms sonra hareket ediyor; görüntü kasıyor.
- **Neden:** Ping yalnız ağın gidiş-dönüş süresi. Ekranı yakalama, sıkıştırma, açma ve çizme ayrıca eklenir; yavaş ya da kötü sıkıştırılmış bir ekran paylaşımı saniyede birkaç kareye düşebilir (tahmin).
- **Çare:** Üç ayrı sayı yaz: ağ gecikmesi (ping), saniyedeki kare sayısı, fareyi oynatıp ekranda görünene kadar geçen süre. Ajanına: "Ölçümü bu üç parçaya ayırarak raporla; tek rakam verme."
- **Kaynak:** [K2] (doğrudan yol "lowest latency" ama bu yalnız ağ kısmı); ekran kısmı için ilke.

### 9. UDP'nin engelli olduğu ağı (okul, ofis, otel) unutmak
- **Belirti:** Evde çalışır; kafede, ofiste ya da okulda hep röle ya da hiç bağlanmaz.
- **Neden:** Bazı ağlar dışarı giden UDP'yi keser; hiçbir NAT numarası bunu aşmaz. Röle HTTP üzerinden çalıştığı için ([K1]) UDP kapalı ağlarda da bir yol bulabilir; garanti değil.
- **Çare:** Bunu hata sayma: `powershell -NoProfile -ExecutionPolicy Bypass -File araclar\kontrol.ps1` (netcheck UDP satırı) ağın UDP'yi engelleyip engellemediğini söyler; `powershell -NoProfile -ExecutionPolicy Bypass -File araclar\baglanti_kanit.ps1 -Es <eş>` "RÖLE" derse bağlantı aracıdan akıyordur, yavaş ama çalışır. Ajanına: "Güvenlik duvarını kapatmayı önerme; röleyle devam et."
- **Kaynak:** [K1] (UC Berkeley örneği, DERP HTTP), [K19] (yalnız TCP 443 kipi), [K9] (`netcheck` UDP alanı).

### 10. Hizmet olarak kurmamak: kilit ekranı, UAC, yeniden başlatma, uyku
- **Belirti:** Gece bağlanılamıyor; yeniden başlatınca bağlantı yok; yönetici onay (UAC) penceresi uzakta görünmüyor, fare donuyor.
- **Neden:** Taşınabilir (kurulmamış) RustDesk'te yönetici onay ekranı aktarılmıyor; uyuyan bilgisayara girilmiyor.
- **Çare:** RustDesk'i kurulu sürümle kullan (Home yolu); `powershell -NoProfile -ExecutionPolicy Bypass -File araclar\kontrol.ps1` uyku ve hizmet durumunu okur; uykuyu "hiçbir zaman" yap; yeniden başlatıp bağlanabildiğini doğrula. Ajanına: "Taşınabilir exe değil, kurulu sürümü kur."
- **Kaynak:** [K22] (taşınabilir sürüm ve UAC), [K7] (Tailscale'in oturum kapansa da çalışması); uyku ve yeniden başlatma için ilke (denenmedi).

### 11. Zayıf kimlik doğrulama: sabit kısa şifre, onay yok, 2. adım yok
- **Belirti:** Kimse fark etmeden bağlanılabilir; ID'yi bilen deneyebilir.
- **Neden:** Uzak masaüstü bilgisayarın anahtarı. RustDesk belgesi de kimliğe (ID) güvenilmemesini, parola ya da 2. adım gerektiğini söylüyor.
- **Çare:** Uzun benzersiz parola; Windows'ta NLA açık (betik bakmaz, kendin kontrol et); RustDesk'te bağlantıyı el ile onaylama (`approve-mode`); Tailscale hesabında iki adımlı doğrulama; kullanılmayan cihazı hesaptan sil. Ajanına: "Parolayı bana ekranda göster ve sohbete yazma."
- **Kaynak:** [K12], [K20] (`approve-mode`, `id-whitelist` notu); Tailscale 2. adım için ilke (bu rehberde ham alıntısı yok).

### 12. Sırları ajana, sohbete ya da git'e yapıştırmak
- **Belirti:** Parola ya da anahtar konuşma geçmişinde, kayıt dosyasında ya da herkese açık repoda durur.
- **Neden:** Sohbet ve repo kalıcıdır; ajan sırrı farkında olmadan bir dosyaya yazar.
- **Çare:** Ajanına: "Parola, anahtar, token yazma ve benden isteme; beni ilgili ekrana yönlendir, ben girerim." `DURUM.md`'ye de sır yazılmaz.
- **Kaynak:** ilke.

### 13. İmzasız ya da alfa yazılıma güvenmek, antivirüs uyarısını geçmek
- **Belirti:** Windows "bilinmeyen yayıncı" der, antivirüs engeller; "yanlış alarm, kapat" diye geçilir.
- **Neden:** İmzasız dosyada yayıncı kimliği yok; sağlama toplamı (SHA256) yalnız dosyanın bozulmadığını gösterir. Örnek: cbdesk kendi README'sinde "unsigned alpha" ve "bağımsız denetim yok" diyor.
- **Çare:** Yalnız resmî sitelerden (tailscale.com, rustdesk.com, Microsoft) indir; uyarıyı "yanlış alarm" sayıp geçme, bana sor. Ajanına bunu aynen söyle.
- **Kaynak:** [K26].

### 14. Ajana ekran yakalama, sıkıştırma ya da şifrelemeyi sıfırdan yazdırmak
- **Belirti:** "Kendi AnyDesk'imizi yazdık" der; saniyede 1 kare, kopan paketler, güvenlik açığı.
- **Neden:** NAT'ı geçmek işin küçük kısmı; görüntü, giriş aktarımı, kimlik doğrulama ve şifreleme ayrı büyük işler. Denetimsiz şifreleme tehlikelidir.
- **Çare:** Ajanına: "Ekran yakalama, görüntü sıkıştırma ya da şifreleme kodu yazma; hazır araç kullan." Öğrenmek isteyenler için `REHBER.md` sonundaki ek bölüm üretim için değil, öğrenme içindir.
- **Kaynak:** [K26] (örnek proje alfada: "no external cryptography review").

### 15. Her şeyi tek seferde yaptırmak, `DURUM.md` tutmamak, "ajan çalıştı dedi"ye güvenmek
- **Belirti:** Ajan bağlamı kaybeder, yarım kurulum kalır, "neredeydik?" diye baştan başlar.
- **Neden:** Ajanın hafızası oturumla gider; adım adım kayıt ve kanıt yoksa hiçbir şey doğrulanamaz.
- **Çare:** `DURUM.md` (her adımdan sonra tek satır: saat | adım | bitti-yarım | kanıt | geri alma | sıradaki); tek adım, onay, sonra sonraki. Ajanına: "Her oturumun başında DURUM.md'yi oku; kanıt çıktısını göstermeden 'çalıştı' deme."
- **Kaynak:** ilke (çalışma kuralı).

---

## B. 7 doğru bilinen yanlış

### Y1. "P2P (doğrudan bağlantı) = hiç sunucu yok"
- **Belirti (nasıl ortaya çıkar):** "Sunucusuz çözüm" arayıp tanıştırıcıyı koymamak.
- **Neden yanlış:** Veri doğrudan akabilir; tanışma (adres öğrenme) için sunucu şart; olmazsa röle. Tailscale de koordinasyon sunucusunu ve röleyi (DERP) sistemin parçası olarak anlatır.
- **Çare:** Doğru söz: "veri doğrudan, tanıştırıcı küçük".
- **Kaynak:** [K1], [K2], [K19].

### Y2. "Port açamıyorsam sabit IP'siz yasak olduğu içindir" / "port açarsam her yerden bağlanırım"
- **Neden yanlış:** Yasak olduğuna dair kaynak bulamadık; port açamamanın asıl nedeni CGNAT. Ayrıca CGNAT arkasında port açmak işe yaramaz; açılabilse bile internete açık port risktir.
- **Çare:** `powershell -NoProfile -ExecutionPolicy Bypass -File araclar\kontrol.ps1 -ModemWanIp <adres>` ve madde 4'teki WAN adresi karşılaştırması. Rehberin yolu hiç port açmaz.
- **Kaynak:** [K1], [K13], [K31].

### Y3. "İnternette doğrudan bağlantı her zaman 5 ms" / "ping = masaüstü gecikmesi"
- **Neden yanlış:** "Doğrudan · yerel ağ · 5 ms" gibi bir rozet yerel ağ ölçümüdür. Gerçek gecikme mesafe, operatör yolu, ekran sıkıştırması ve kare hızına bağlı.
- **Çare:** Üç ayrı ölçü (madde 8); gerçek test başka ağdan (madde 2).
- **Kaynak:** [K2]; ekran kısmı için ilke.

### Y4. "Doğrudan bağlantı her zaman kurulur" ya da tersi "iki CGNAT'ta kesin olmaz"
- **Neden yanlış:** NAT'ın türüne bağlı. Tailscale yazarının tahmini: yalnız temel yöntemlerle "over 90%" doğrudan, kalanı röle (ölçüm değil, tahmin). İki taraf da zor NAT ise ve yalnız 20 saniye kaba deneme yapılırsa başarı "0.01%"; %99,9 için 170.000 deneme, ~28 dk gerekir. Bu "genel başarı oranı" değil, o senaryonun hesabı.
- **Çare:** Röleyi normal yedek say; `powershell -NoProfile -ExecutionPolicy Bypass -File araclar\baglanti_kanit.ps1 -Es <eş>` hangisi olduğunu söyler.
- **Kaynak:** [K1] ("over 90%", "0.01%", "170,000 probes"), [K2].

### Y5. "Röle ya da VPN güvensiz ve yavaştır"
- **Neden yanlış:** Doğrudan ile röle arasındaki fark güvenlik değil performans. Yavaşlık görürsen önce bağlantının röleye düşüp düşmediğine bak; Tailscale belgesi, doğrudan yol mümkünken röleli bağlantıda kalmayı performans sorunlarının sık nedenlerinden biri sayar.
- **Çare:** `tailscale status` ya da `powershell -NoProfile -ExecutionPolicy Bypass -File araclar\baglanti_kanit.ps1 -Es <eş>`.
- **Kaynak:** [K2] (fark "performance, not security"), [K5] (röle şifreli trafiği iletir).

### Y6. "Her Windows'ta uzak masaüstü var"
- **Neden yanlış:** Home sürümü uzak masaüstü sunucusu olamaz.
- **Çare:** Madde 6: sürümü ölç, yolu seç.
- **Kaynak:** [K12], [K14].

### Y7. "Bu bir sır; yöntemi gizlemek güvenliktir; kendin yazan daha iyisini yapar"
- **Neden yanlış:** Teknik (NAT delme) yıllardır belgeli ve açık kaynak araçlarda var. Güvenlik yöntemin gizliliğinden değil, kimlik doğrulamadan ve şifrelemeden gelir. Kendin yazmak aynı tuzakların hepsini sana bırakır (madde 14).
- **Çare:** Hazır, yaygın, denetlenmiş araç; sır yok.
- **Kaynak:** [K1], [K19], [K26]; "gizlilik güvenlik değildir" kısmı ilke.

---

## C. RustDesk bilinen sorunlar
Tablodaki "durum" sütunu: **belgeli** = resmî belge/wiki/geliştirici yanıtı; **rapor** = kullanıcı raporu (yön gösterir, kesin değildir); **kök neden bilinmiyor** = kaynakta çözüm ya da neden yok. "Kontrol sırası" sütunu kaynak değil, rehberin kendi teşhis sırasıdır (yalnız okuyan komutlar yeşil; ayar değiştiren kırmızı). Her satır kullanılan sürümle tarihlidir: kaynak kurulu sürümden eskiyse "eski olabilir" de.

| # | Belirti (ekranda gördüğün cümle) | Durum ve ne biliniyor | Kontrol sırası (ajan) | Kaynak, sürüm/tarih |
|---|---|---|---|---|
| 1 | Kırmızı kalkan: "direct and unencrypted connection" | **Belgeli, hata değil.** Doğrudan IP şifresiz tasarım; VPN ile (Tailscale) kullanılması öneriliyor. Tailscale adresinde trafik Tailscale tünelinde şifrelidir | Adres `100.` ile mi? Evet: sorun yok. Hayır: dur | Tailscale blog 2025-07-10; RustDesk geliştirici yanıtı #3714, 2025-11-12; RustDesk wiki SSS (tarihsiz) |
| 2 | "Connected, waiting for image" (özellikle hedef kilit ekranındayken, Windows) | **Kök neden resmen çözülmemiş**: konu hâlâ açık ("Unresolved" listesi). Bilinenler: hedefte **kurulu sürüm** gerekir ve hizmet açık değilse bağlanılamaz (geliştirici); bir kullanıcı çözümü (**ikincil**): iki uçta da kurulu sürüm + güvenlik ayarlarında klavye/fare izni | (1) hedefte kurulu mu (`Test-Path "C:\Program Files\RustDesk\rustdesk.exe"`); (2) RustDesk > Settings > General'da "Service Control" ile hizmetin durumuna bak (kendin tıkla); (3) hedefte klavye/fare iznine bak (Settings > Security > Permissions); (4) hâlâ olmuyorsa rehber çözüm vaat etmez, DURUM'a yaz | #5609 (açık, açılış 2023-09-05, son güncelleme 2026-09-04); #2175 (kapalı, 2022-11-17, v1.1.9); RustDesk Client belgesi (Service Control) |
| 3 | Hedefte Görev Yöneticisi / sistem ayarları açılınca ekran donuyor, fare yanıt vermiyor | **Belgeli:** taşınabilir (kurulumsuz) sürümde Windows UAC sınırı. Çare: hedefe **kurulu** sürüm; ya da yükseltmeyi kabul et / yönetici olarak çalıştır | H1'de kurulu sürüm kullanıldı mı | RustDesk wiki SSS "Windows UAC"; RustDesk Portable Elevation belgesi (okuma 2026-11-11) |
| 4 | Hedefi yeniden başlattıktan sonra bağlanılamıyor | İki ayrı şey: (a) **Hizmet kullanıcı tarafından durdurulmuş olabilir** (SSS'te bir kullanıcı tepsiden kendisi durdurmuş); (b) "küçük sayıda Windows bilgisayarda açılışta başlamıyor": SSS'teki kullanıcı çözümü hizmeti gecikmeli başlatmak (**ikincil, denenmedi**) | (1) hizmet açık mı (Service Control, tıkla ve bak); (2) yalnız (1) sonuç vermezse ve kullanıcı isterse: yönetici PowerShell'de `sc config rustdesk start= delayed-auto` (**kırmızı**: ayar değiştirir; geri alma: önceki başlangıç türünü yazıp `sc config rustdesk start= <önceki>`; hizmet adı `rustdesk` bu SSS'ten, ham teyit yok) | RustDesk wiki SSS "RustDesk Service does not start automatically", "Windows service won't start on reboot" (tarihsiz; Reddit'e bağlı) |
| 5 | `Failed to connect to <Tailscale IP>:21118: Please try later` | **Kök neden bilinmiyor.** Bir kullanıcıda 5 makineden 2'sinde (Linux) oldu, öbürlerinde aynı ayarla çalıştı; geliştirici yanıtı: "You should ask tailscale, not us." 21118 doğrudan IP portu: Windows 10'da RustDesk 1.5.3'te `netstat` ile **TCP dinlediği** görüldü (kayıtta görüldü, deneme 1, tek makine); RustDesk ayrıca UDP 21119 dinliyor (işlevi belgede yok) | (1) hedefte RustDesk açık mı ve "Enable direct IP access" işaretli mi; (2) hedefte `netstat -ano \| findstr 21118`; (3) `tailscale ping --until-direct <hedef>` (iki cihaz birbirini görüyor mu); (4) beyaz liste aralığı (`100.64.0.0/10`) doğru mu; (5) hâlâ olmuyorsa RustDesk'i hedefte yeniden başlat; olmazsa rehber çare vaat etmez, DURUM'a yaz ve hata metnini harfiyen kaydet | #14827 (kapalı, 2026-04-16, **Linux**: Nobara 43 / Fedora 43; RustDesk sürümü raporda yazmıyor) |
| 6 | Hedefte yeniden başlatınca doğrudan IP erişimi ve kalıcı parola kaybolmuş | **Kök neden bilinmiyor** (tek rapor; kullanıcı kendisi "belki AppData klasörü başka sürücüye bağlantı" diye tahmin etmiş; yorum yok, konu kapalı) | Yeniden başlatma sonrası H2-H4'ün beklenen son hâlini (ayar kartı) gözle karşılaştır; kayıpsa kendin yeniden işaretle; DURUM'a "yeniden başlatmada kayboldu" yaz | #15443 (kapalı, 2026-06-26, RustDesk 1.4.8, Windows 10 -> Windows 10) |
| 7 | Hostname (bilgisayar adı) yazınca "ID not found" | **Belgeli:** hostname doğrudan IP'de çalışmaz; yalnız IP (SSS'te geçici çözüm başka bir tartışmaya bağlı) | Kutuya adı değil `100.x.y.z` yaz | RustDesk wiki SSS; #4862 (kapalı, 2023-07-04, RustDesk 1.2.0) |
| 8 | "Start Service" sırasında antivirüs (örnek: Bitdefender) "Disinfection" yapıyor, hizmet kurulmuyor | **Rapor (tek kullanıcı), geliştirici yanıtı yok** (konu "close this old topic" ile kapatılmış). Aynı kullanıcı sürüm 1.4.9'da sorun yaşamamış. Antivirüs istisnası da çözmemiş | **Antivirüsü kapatma ya da "yanlış alarm" deme:** kullanıcıya haber ver; seçenekler: (a) istersen sorunu kendin bildir ve bekle, (b) başka güvenli yol (Pro'daysa Adım 3a), (c) kullanıcı bilerek eski sürümü resmî sürüm sayfasından indirir (sürüm kilitleme bedeli: güvenlik güncellemesi alamaz) | #16493 (kapalı, 2026-10-07, RustDesk 1.5.0 / Windows 11) |
| 9 | Bağlanırken hep parola soruyor, ama kalıcı parola kabul edilmiyor / yalnız tek kullanımlık parola çalışıyor | **Belgeli ayar:** gözetimsiz erişim için "Accept sessions via both" ya da "Accept sessions via password" **ve** "Use both passwords" ya da "Use permanent password" birlikte seçili olmalı | Hedefte Settings > Security > Password: iki seçim (Türkçe arayüzde adları farklı olabilir; ajan ekranına bakıp karşılığını söylesin) | RustDesk wiki SSS "fixed password for unattended access" |
| 9b | Telefonda (iPhone) kalıcı parola kabul edilmiyor, PC'de aynı parola doğru | **Neden doğrulanmadı (tahmin):** telefon klavyesi işaret ya da Türkçe harfi farklı yazıyor olabilir. Kayıtta görüldü (deneme 1): parola yalnız İngilizce harf ve rakamla yeniden oluşturulunca telefon kabul etti | Parolayı hedefte yalnız İngilizce harf + rakamla, en az 16 karakter olacak şekilde yeniden oluştur (arayüz 8 karakteri kabul eder, rehber 16+ der); telefonda yazarken "göster" ile gözle doğrula | kayıtta görüldü (deneme 1, RustDesk 1.5.3, iOS); resmî kaynak yok |
| 9c | Bağlanırken PC'nin sağ üstünde "cihazınıza erişim talep edin" penceresi (Kabul Et / Iptal) çıkıyor | Onay kipi "Her ikisi" (parola ya da tıklama) olduğunda, parola girilmeden gelen istek PC'deki pencerede kabul beklenir. Kayıtta görüldü (deneme 1): PC'de **Iptal** basılınca telefondaki parola isteği de kapandı (istek kapanır). Bağlanırken kendi isteğinde PC penceresine dokunma | Tanımadığın cihaz adı ya da adres görürsen Iptal; kendi isteğinse dokunma, parolayı telefonda gir | kayıtta görüldü (deneme 1, RustDesk 1.5.3); resmî kaynak yok |
| 10 | ID ile bağlanırken `Failed to connect via rendezvous server: Please try later` | Bu rehberin yolu değil: **ID numarasıyla bağlanıyorsun, IP ile değil.** SSS'e göre bu hata kendi sunucuya (hbbs) bağlanamamayla ilgili | ID kullanma; kutuya `100.x.y.z` yaz (REHBER H5) | RustDesk wiki SSS "Failed to connect via rendezvous server" (tarihsiz) |

**Tablo dışı bir hata gelirse:** ajan "doğru kaynağa bakma" kuralını (AGENTS.md) uygular; hata cümlesini harfiyen yazar, sürümü yazar, bulamazsa "bulamadım" der ve seçenek sunar.

## D. Güvensiz popüler çözümler ve güvenli karşılıkları
Yasak listesi değil: kullanıcı bilerek seçebilir; ajan önce çalışan güvenli yolu sunar, güvensiz olanı ancak yazılı onayla uygular.

| # | Popüler "hızlı çözüm" | Ham alıntı (adres) | Çalışan güvenli karşılık |
|---|---|---|---|
| 1 | CredSSP hatasında "Encryption Oracle Remediation"ı `Vulnerable` yapmak | "Vulnerable: Client applications that use CredSSP will expose remote servers to attacks by supporting fallback to insecure versions" / "Services that use CredSSP will accept unpatched clients." (https://support.microsoft.com/en-us/help/4093492) | İki bilgisayarı da güncelle: "Both the client and server need to be updated." Güncelleme imkânsızsa kullanıcıya sor, geçici yaz. |
| 2 | Modemde 3389'u (Uzak Masaüstü kapısını) internete açmak | "You're opening your PC up to the internet, which isn't recommended." / "If you connect to your local area network by using a virtual private network (VPN), you don't have to open your PC to the public internet." (https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/remotepc/remote-desktop-allow-outside-access) | Tailscale: modemde hiçbir kapı açılmaz; rehberin Adım 1 ve 3a'sı. |
| 3 | "Bağlanamıyorum" diye NLA'yı (ağ düzeyi kimlik doğrulama) kapatmak | "Enabling NLA is recommended for most environments ... For best security, keep NLA enabled whenever possible." (KAYNAKLAR: Windows, Uzak Masaüstü sayfası) | NLA açık kalsın. Hatanın nedenini oku (SORUN_GIDERME); olmuyorsa Home/uyumsuz cihaz için Adım 3b RustDesk. |
| 4 | Aynı bilgisayarda iki kişi aynı anda oturum için sistem dosyası yaması ya da üçüncü taraf sarmalayıcı | Resmî Microsoft yanıtı bulunamadı. Topluluk yanıtı (resmî değil): "Windows 10 or 11 client, which by design, permits only one user login at a time." (https://learn.microsoft.com/en-us/answers/questions/1665158/how-can-i-keep-both-ends-operating-at-the-same-tim) | Uzaktan kullandığın bilgisayarı tek kullanıcıya ayır; ikinci oturum gerekiyorsa RustDesk ile yalnız ekran paylaşımı. |
| 5 | Güvenlik duvarı kuralını kapatırken kural adı vermemek (komutu parametresiz çalıştırmak) | "IMPORTANT NOTE: Running this cmdlet without parameters disables all Windows Firewall rules on the target computer." (KAYNAKLAR: güvenlik duvarı cmdlet'leri, Disable-NetFirewallRule) | Her zaman `-Name` ile tek kural; rehberin araçları bunu zorlar, geri alma için `rdp_tailscale_kilit.ps1 -Geri -Uygula`. |
| 6 | **İlke** | (alıntı gerekmez; kural) | Listede olmayan ama güvenliği düşüren bir şeyi önermeden önce dur, sor. |

## E. Türkiye'de bilmen gerekenler
> **Bu bir hukuki danışmanlık değildir.** Aşağıdakiler kaynağı gösterilebilen bilgilerdir; bulamadığımız yerde "bulamadık" yazdık.

**1. VPN kullanmak kanunla yasak mı?** Bulabildiğimiz kaynağa göre hayır. Bir hak kuruluşunun (İFÖD, İfade Özgürlüğü Derneği) 2025 EngelliWeb raporu şöyle diyor: "there is no statutory provision prohibiting the use of VPN services from Türkiye" [K33]. Bu rapor resmî bir kurum değil, bir hak kuruluşunun raporudur; kendi görüşünü içerir.

**2. Bazı VPN hizmetleri engelli.** Aynı rapora göre BTK'nın 23.11.2023 tarihli yazısı erişim sağlayıcılardan 16 VPN hizmetinin engellenmesini istemiş; 26 hizmetin engelli olduğu tespit edilmiş [K33]. Raporda ayrıca bazı VPN'lerde TLS SNI bilgisine bağlı seçici yavaşlatma görüldüğü yazıyor. Nisan 2026'da "sanal ağ hizmeti" tanımlayan bir taslak anılıyor; **taslaktır, durumu değişebilir** [K33].

**3. Bu rehberin araçları engelli mi?** **Bilmiyoruz, kaynak bulamadık.** Rapor Tailscale, RustDesk, ZeroTier, AnyDesk ya da WireGuard'ı anmıyor; bu "engelli değil" demek değildir, yalnız "raporda geçmiyor" demektir. Kendi bağlantında dene: Tailscale açılmıyor ya da hep yavaş çıkıyorsa "Bağlanamıyorum" bölümüne bak.

**4. "Sabit IP'siz port açmak yasak" diye duyduysan:** Bu söze dair kaynak bulamadık [K31]. Yasak **olduğuna** dair kaynak yok; "yasak değil" diye de kesin söylemiyoruz. Port açamamanın bilinen asıl nedeni başka: operatörler CGNAT (hatları ortak adresle paylaştırma) kullanabiliyor [K27, K28, K29].

**5. CGNAT "olabilir".** Tailscale'in `100.64.0.0/10` adres aralığı CGNAT için ayrılmış aralıkla aynıdır [K10]; bu yüzden betik modemin dış adresi bu aralıktaysa "CGNAT var", değilse "CGNAT olabilir" der. Operatörlerin güncel politikasını doğrulayamadık (operatör sayfası açılamadı ya da ikincil kaynak) [K27, K28, K29]. Güncel IPv6 yüzdesi de bulunamadı [K30]; rehber IPv6'ya güvenmez.

**6. CGNAT ya da zor NAT varsa ne olur?** Tailscale ve RustDesk için port açman gerekmez; iki taraf da dışarıya bağlanır. Doğrudan yol kurulamazsa trafik röle sunucusundan geçer: bağlantı yine çalışır, yalnız daha yavaş olabilir [K1, K9]. Röle bir hata değil, normal bir durumdur.

**7. Neden röle (ya da yavaş) olduğunu nasıl anlarsın? Hotspot karşılaştırması.**
- Aynı iki bilgisayarla `baglanti_kanit.ps1` çalıştır ve sonucu not et (DOĞRUDAN mı, RÖLE mi).
- Bu bilgisayarı (B) telefonunun mobil internet paylaşımına (hotspot) bağla ve betiği tekrar çalıştır. Telefonun kendisini B olarak kullanmak (Tailscale uygulaması, Wi-Fi kapalı, mobil veri) aynı karşılaştırmayı verir: kayıtta görüldü (deneme 1): mobil veride DOĞRUDAN çıktı; tek deneme, tek operatör.
- Hotspot'ta DOĞRUDAN, evde RÖLE çıkıyorsa sorun ev hattında ya da modemde (zor NAT/CGNAT/duvar) olabilir. İkisinde de RÖLE çıkıyorsa karşı taraf (A) ya da operatör olabilir. İkisinde de DOĞRUDAN ise sorun başka yerdedir (parola, hizmet).
- Bu bir **teşhis ipucudur**, kesin hüküm değil; sonucu kendi gözünle yorumla.
- Modemde port açma önerme: rehber bunu istemez.

## F. Hotspot, dosya aktarımı ve köprü notları

**Ağ ve RustDesk (ölçümlerden):**
- **iPhone hotspot'u ekran kapanınca yayını kesebilir.** Belirti: bağlantı bir süre sonra düşer. Çare: telefonda Kişisel Erişim Noktası ayarlar ekranı açık kalsın. (Gözlem; neden ayrıca araştırılmadı.)
- **RustDesk dosya aktarımı ayrı bir onay ister.** Oturum açıldıktan sonra dosya aktarımı başlayınca hedef bilgisayarda ikinci bir "Kabul Et" penceresi çıkar. Çare: hedefte kabul et; aktarım o zaman başlar. (Ölçüldü: onay sonrası 100 MB ~11-18 sn, sha256 eşleşti.)
- **Windows yeni bir ağa bağlanınca kısa süre "internet yok" gösterebilir.** Tahminim: ağ profili oturana kadar; kısa sürdü, nedeni doğrulanmadı. Çare: birkaç saniye bekle, sonra `tailscale status` ile bak.

**Köprü (`KOPRU.md`):**
| Belirti | Ne yapılır |
|---|---|
| `kopru_kesif.ps1` çıkış 2 | Aday yok. Bekçiyi yine de kur: eş yokken bekçi 30 sn arayla keşfi kendisi dener (`ES YOK` / `ES BULUNDU` satırları). Satırdaki nedeni oku: öbür bilgisayarda Tailscale açık ve aynı hesapta mı; "dosya gönderimi kapalı" yazıyorsa hesapta Send Files'ı aç (REHBER Adım 6a). |
| Çıkış 3 | Eş bulundu ama kapalı ya da uykuda. `es.json` yazıldı; bekçiyi kur, eş açılınca mesaj gelir. Öbür bilgisayarda ajanı açtırmak için REHBER Adım 6'daki sabit cümleyi kullanıcıya ver. |
| Çıkış 5 | Hesapta birden çok aday. Hepsine `kopru_gonder.ps1 -Merhaba -Hedef <ad>` gönder, cevap vereni `kopru_kesif.ps1 -Sec <ad>` ile seç. Tanımadığın bir cihaz varsa `ayar.json` profil `paylasilan`. |
| Bekçi "ZATEN CALISIYOR" (çıkış 6) | Başka bir bekçi açık; ikincisi gerekmez. Durumu `kopru_durum.ps1` gösterir. |
| Ek için "henüz gelmedi" | Dosya henüz inmedi. Biraz sonra `kopru_bekle.ps1 -EkMesaj <mesajın yolu>` ile al (ek alındıysa çıkış 0, gelmediyse 3). |
| Gönderim çıkış 7 (hata freni) | Saatlik tavan doldu. Bir döngü olmadığına bak; kullanıcı isterse `ayar.json`'da `saatlik_tavan` değiştirilir (0 = sınırsız). Ayarlar: `KOPRU.md`. |
| Gönderim çıkış 8 | Tailscale gönderemedi; eş kapalı olabilir. `kopru_kesif.ps1` çalıştır. Eş çevrimdışıyken davranış ölçülmedi (TEST_PLANI T15-4). |
| Bekçi `ATLANDI (tarayıcıyla inmiş...)` diyor ve bu eşten beklenen bir mesaj | Dosya tarayıcıyla inmiş sayılıyor (Zone.Identifier). Kullanıcıya sor; onaylarsa elle `Unblock-File` ile açılır. |
| Köprü hiç işlemiyor, `DUR` yazıyor | `DUR` dosyası var (biri durdurdu). Ajan silmez; kullanıcı "köprüyü yeniden başlat" derse silinir. |
| Bağlam sıkıştı ya da oturum yenilendi, ajan ne olduğunu bilmiyor | Tek kaynak köprü defteridir (`defter.jsonl`); `kopru_durum.ps1` özetler. Hafızaya değil ona güven. |
| Eş mesaj yolladı ama ajanım uyanmadı | Kendiliğinden uyanma yalnız Claude Code'da ve pencere açıkken, bekçi çalışırken olur. Codex/Cursor'da ajana "posta var mı bak" de; bekçi her mesajda çıkar, ajan her uyanışta önce onu yeniden kurar; oturum yenilendiyse de kur. |

---

*Bu dosyanın kaynak numaraları `KAYNAKLAR.md` içindedir. Ücret, limit ve ayar adları zamanla değişir; yayın gününde yeniden kontrol edilmelidir. Bu rehber gerçek iki ağ arasında henüz test edilmemiştir; ne yapılacağı `TEST_PLANI.md` içindedir.*
