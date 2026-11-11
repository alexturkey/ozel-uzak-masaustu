# REHBER: İki Windows bilgisayarı port açmadan, güvenle uzaktan kullan

Bu rehber, yazılımcı olmayan birinin **kendi yapay zekâ ajanına** (Claude Code, Cursor, Codex vb.) verip adım adım uygulatması için yazıldı.
Sonuç: evdeki bilgisayarına başka bir yerden (iş, okul, telefon hotspot'u) bağlanırsın; modemde port açmazsın, sabit IP gerekmez.

**Nasıl çalışıyor, tek paragraf.** İki bilgisayar internette birbirini doğrudan bulamaz; aralarında modemler vardır (NAT: evin tek adresini evdeki cihazlara paylaştıran düzen).
Tailscale iki cihazı önce küçük bir **tanıştırıcı sunucu** üzerinden buluşturur, sonra modemlerin arasından **doğrudan bir yol** açmayı dener (teknik adı "NAT delme", İngilizcesi *UDP hole punching*).
Yol açılırsa görüntü doğrudan akar; açılamazsa şifreli trafik **röle** (aracı sunucu) üzerinden geçer, yine çalışır ama biraz yavaştır.
Tanışma için bir sunucu her zaman vardır; yalnız veri onun üstünden geçmek zorunda değildir. Yöntem yeni ya da gizli değil, yıllardır belgeli.

## Yol haritası

| Adım | Ne | Araç |
|---|---|---|
| Başlamadan | Ajan nerede çalışacak; ajan kuralları kendiliğinden okur | bu sayfa, `AGENTS.md` |
| 0 | Ön kontrol: Home mu Pro mu, uyku, kurulu programlar | `araclar\kontrol.ps1` (yalnız okur) |
| 1 | Tailscale'i iki bilgisayara kur | resmî yükleyici |
| 2 | Bağlantı doğrudan mı röle mi | `araclar\baglanti_kanit.ps1` (yalnız okur) |
| 3a | **Windows Pro:** yerleşik Uzak Masaüstü, yalnız Tailscale'den | `araclar\rdp_tailscale_kilit.ps1` |
| 3b | **Windows Home:** RustDesk, Tailscale adresine doğrudan | ekrandan (betik yok, bilerek) |
| 4 | Güvenlik son kontrolü | ajan sorar, sen cevaplarsın |
| 5 | Gerçek iki-ağ testi | `TEST_PLANI.md` |
| Sonra | Günlük kullanım | bu sayfanın sonu |

Yanında: `DURUM.md` (ajanın defteri), `SORUN_GIDERME.md` (15 sık hata, 7 doğru bilinen yanlış, RustDesk sorunları, güvensiz çözümler, Türkiye notları), `BAGLANTI_KARTI.md` (bitince doldurulan kısa kart), `KAYNAKLAR.md` (resmî belgelerden ham alıntılar).
Rehberdeki sayı, port ve ayar adlarının kaynağı `KAYNAKLAR.md`'dedir. Belgede bulunamayan ya da henüz gerçek iki ağda sınanmamış her ayrıntı tek kalıpla işaretlidir: **"Sınanmadı → TEST_PLANI Tx"**.

**Gerekenler:** iki Windows 10/11 bilgisayar, bir Tailscale hesabı (ücretsiz kişisel plan, ticari olmayan kullanım), bir yapay zekâ ajanı, gerçek test için telefon hotspot'u.

---

## Başlamadan

**Adlar.** Bu rehberde iki bilgisayar hep aynı adla geçer:
- **Hedef (A):** uzaktan bağlanılacak bilgisayar (genelde evdeki).
- **Kontrol eden (B):** bağlanan bilgisayar (işteki, okuldaki ya da yanındaki dizüstü).

**Ajan nerede çalışır.**
1. Ajanı **hedef (A)** bilgisayarda, bu deponun klasöründe aç (kısa bir yol iyi olur, ör. `C:\uzak`). Bütün komutlar bu klasörden çalıştırılır.
2. B'de ajan gerekmez: B'de yalnız Tailscale (ve Home dalında RustDesk) kurulur, onu Adım 1 ve 3b'de sen yaparsın. İstersen B'de de ayrı bir ajan açabilirsin; o zaman B'nin kendi `DURUM.md`'si olur.
3. **Yönetici gereken adımlar:** Pro dalında 3a-3 (kilidi uygulama) ve 3a-4 içindeki `-Iptal` ile geri alma; Home dalında RustDesk kurulumu (H1, Windows onay penceresi), RustDesk'te "Güvenlik Ayarlarını Aç" (H2) ve umumi Wi-Fi önlemi (H3b, `rustdesk_tailscale_kilit.ps1 -Uygula`). Ajan bu adımlara gelmeden haber verir. İki yol var: ajanı baştan "Yönetici olarak çalıştır" ile açılmış bir terminalde başlatırsın, ya da ajan komutu sana verir ve sen yönetici PowerShell penceresine yapıştırırsın. Betikler kendilerini yönetici yapmaz.
   - Yönetici PowerShell açmak: Başlat düğmesine sağ tıkla, "Windows PowerShell (Yönetici)" (Windows 11'de "Terminal (Yönetici)") seç, çıkan onaya "Evet" de. Sonra bu klasöre geç: `cd C:\uzak` (klasörün başka yerdeyse onun yolu).

**Güncellemeler.** Uzun süre kapalı kalmış bir bilgisayar açılışta güncelleme yapar; onları önce ev ağında bitir, telefon erişim noktasına yalnız test anında geç (mobil veri harcar).

**Komut biçimi.** Bütün betikler şöyle çalıştırılır:
```
powershell -NoProfile -ExecutionPolicy Bypass -File araclar\<betik>.ps1 <seçenekler>
```
`-ExecutionPolicy Bypass` yalnız o tek çalıştırma için Windows'un betik imza kısıtını atlar; sistem ayarını değiştirmez. Aşağıda kısalık için bu baş kısım **P** diye yazılır: `P araclar\kontrol.ps1` = yukarıdaki satır.

**DURUM satırı.** Ajan her adım bitince `DURUM.md`'ye aynı biçimde bir satır ekler:
```
| <saat> | <adım> | <bitti/yarım> | <kanıt> | <geri alma> | <sıradaki> |
```
Betikler bu satırı kendileri basar (ASCII, Türkçe harfsiz); ajan onu olduğu gibi ekler.

**Günlükler nerede.** Yalnız okuyan betikler (`kontrol`, `baglanti_kanit`): `%LOCALAPPDATA%\dogrudan-uzak-masaustu\`. Duvarı değiştiren betikler (`geri_al_zamanlayici`, `rdp_tailscale_kilit`, `rustdesk_tailscale_kilit`): `%ProgramData%\dogrudan-uzak-masaustu\` (yalnız yöneticiler yazabilir; nedeni "iki kapı kuralı" bölümünde).

### Ajan kuralları (`AGENTS.md`)
Ajanın kuralları ayrı bir dosyada: `AGENTS.md`. Claude Code (`CLAUDE.md` üzerinden), Codex ve Cursor bu klasörde açılınca onu kendiliğinden okur (KAYNAKLAR: "Ajanlar: kural dosyaları ve onay").
- Ajan ilk cevabında "Kuralları (AGENTS.md) okudum ve kabul ettim" der. **Demezse** ona şunu yaz: "Bu klasördeki AGENTS.md dosyasını oku, kurallarını kabul et, sonra DURUM.md'yi açıp REHBER.md Adım 0'dan başla."
- Kurallar kısaca: her adım `DURUM.md`'ye yazılır; yalnız okuyan işleri ajan sormadan yapar (yeşil), değiştiren ve geri dönüşü zor her iş için ayrı onay ister (kırmızı), gerisinde tek "tamam" yeter (sarı); emin olmadığı yerde hafızaya değil resmî sayfaya bakar ve adres + ham cümle gösterir; bağlı olduğun yolu kesmez; parola istemez.
- Sınıf listeleri kapalıdır: listede adı geçmeyen iş bir üst sınıftan sayılır. Bütün onayları her adımda istemek yerine bu düzeni seçtik: okumak seni yormasın, değiştirmek hep senin elinde kalsın.

**Neden bu kurallar (sana, ajana yapıştırılmaz).** Ajan oturum ya da bağlantı kopunca nerede kaldığını unutur; `DURUM.md` onun hafızasıdır (1-2). Tek seferde yapılan kurulumda hata çıkınca neyin bozduğu anlaşılmaz; ajanın hafızadan uydurduğu bayrak ya da ayar adı en sinsi hatadır (3-6). Ajanın kendi bağlı olduğu yolu kesmesi bu işin en sık ve en pahalı hatasıdır; iki kapı ve zamanlı geri alma bunun içindir (7-11). "Çalıştı" sözü ajanda bedavadır, kanıt komutu onu pahalıya çevirir; "doğrudan · yerel ağ · 5 ms" gibi bir rozet yerel ağ ölçümüdür, internet kanıtı değildir (12-14). Uzak masaüstü bilgisayarın anahtarıdır; sır, açık port ve imzasız yazılım başlıca tehlikelerdir; "biri seni arayıp kurdurdu" ise en eski dolandırıcılık biçimidir (15-20).

---

## Adım 0. Ön kontrol (yalnız okur)

Hiçbir şey kurmaz, değiştirmez. Önce hedefte (A); B'de de istersen.

### 0a. Üç kısa soru (ilk oturumda bir kez)
Ajan şu mesajı bir kez yazar:
> **Başlamadan önce üç kısa soru (bir kez soruyorum).**
> Uzak erişim, bilgisayarına başka birinin oturmasıyla aynı şeydir. Bu yüzden önce şunu netleştirelim:
> 1. Bu kurulumu kendi kararınla mı başlattın? (evet/hayır)
> 2. Biri seni aradı ya da yazdı mı ve "şu programı kur, sana gelen kodu bana ver" dedi mi? (evet/hayır)
> 3. Bağlanacağımız iki bilgisayar da senin mi? (evet/hayır)
>
> Doğru cevap sırası: **evet, hayır, evet**. Başka bir cevapta **burada duruyorum**: hiçbir şey kurmuyorum, hiçbir kod ya da parola yazmıyorsun. Kurdurmak isteyen kişiyle konuşmayı kes; bir banka, kurum ya da teknik destek seni habersiz arayıp bilgisayarına girmek istemez.
> Üçü de uygunsa bana (bu sohbete) şu cümleyi aynen yaz: **kendim istiyorum, cihaz benim**. Cevabını `DURUM.md`'ye yazarım; cevap gelmeden Adım 1'e geçmem.

- **DURUM satırı:** `| <saat> | Adim 0 kapisi | bitti | kullanici: "kendim istiyorum, cihaz benim" | - | 0b on kontrol |`

### 0b. Ön kontrol betiği

- **Yap (ajanına):** "`P araclar\kontrol.ps1` çalıştır, çıktıyı olduğu gibi göster, sonra tek paragrafla özetle. Modemin internete bakan adresini (WAN IP) biliyorsam söylerim; o zaman `-ModemWanIp <adres>` ile tekrar çalıştır. Hiçbir şey kurma, değiştirme."
  > WAN IP: modemin yönetim sayfasında "WAN", "İnternet" ya da "Bağlantı durumu" altında yazar. Bilmiyorsan atla; modem parolasını ajana yazma.
- **Kanıt:** Betik satırları `[TAMAM]`, `[UYARI]`, `[YOK]`, `[BILGI]` ile başlar; sonda DURUM satırı basar. Örnek:
  ```
  | 12:38 | 0 on kontrol | bitti | Windows=Home, uyku=kapali, tailscale=yok, hizmetler4=tamam, rustdesk=yok | yok (yalniz okur) | 1 (Tailscale kurulumu) |
  ```
  - `Windows=Home` → **3b (RustDesk)**; `Windows=Pro` → **3a**. Ajan dalı bu satıra göre seçer ve sana söyler. (Microsoft: Home sürümü uzak masaüstü *sunucusu* olamaz.)
  - `uyku=kapali` görünmeli. Değilse hedefte Ayarlar'da "Güç" (Windows 10'da "Güç ve uyku") bölümünden prizdeyken uykuyu "Hiçbir zaman" yap: uyuyan bilgisayara bağlanılamaz.
  - `tailscale=yok`, `rustdesk=yok` normal; sonraki adımlarda kurulur.
  - `hizmetler4=tamam` görünmeli: Tailscale yükleyicisi 4 Windows hizmetinin (`Dnscache`, `iphlpsvc`, `netprofm`, `WinHttpAutoProxySvc`) çalışmasını ister, yoksa kurulum kendiliğinden başarısız olur (KAYNAKLAR: "Tailscale: anahtar süresi, kurulum hizmetleri"). `hizmetler4=eksik` ise betik hangisinin durduğunu yazar; betik hizmet başlatmaz. Ajan sana gösterir, başlatmadan önce sorar.
  - Tailscale kuruluysa betik `tailscale netcheck` (ağ durum raporu) da çalıştırır ve `netcheck=UDP:true;zorNAT:false` gibi özet yazar: `UDP:false` ya da `zorNAT:true` ise bağlantı büyük olasılıkla röleden gider (hata değil). Bu yüzden Adım 1'den sonra betiği bir kez daha çalıştır.
  - `-ModemWanIp` verdiysen `cgnat=var|olasi|yok` yazar. **CGNAT** (operatörün tek adresi birçok eve paylaştırması) varsa modemde port açmak işe yaramaz; bu rehber zaten hiç port açmaz. Not: `100.64.0.0/10` aralığı iki yerde geçer ve karışmaz: modemin **WAN** adresi bu aralıktaysa CGNAT işaretidir; Tailscale de **kendi cihaz adreslerini** bu aralıktan verir (100.x.y.z).
- **Geri al:** gerek yok.
- **DURUM satırı:** betiğin bastığı satır.

---

## Adım 1. Tailscale'i iki bilgisayara kur

Tailscale iki bilgisayarı internet üzerinden **özel bir ağa** bağlar (sanki aynı evdeymişler gibi); modemde port açtırmaz. Bir hesap açarsın; her bilgisayar o hesaba "cihaz" olarak girer. Ücretsiz kişisel plan: 6 kullanıcıya kadar, sınırsız cihaz, **yalnız ticari olmayan kullanım**. Planlar değişebilir; kurmadan önce tailscale.com/pricing'e bak.

- **Yap (A'da ajanına; B'de kendin aynı adımları):**
  1. "tailscale.com'dan Windows `.exe` yükleyicisini indir ve çalıştır. Başka siteden indirme. Yönetici onay penceresi çıkarsa bana haber ver, ben onaylarım." (Windows 10 ya da üstü gerekir.)
  2. "Tailscale simgesi sistem tepsisinde (saatin yanı; görünmüyorsa yukarı ok) çıkar. Simgeden giriş yap; tarayıcı açılır. **İki bilgisayarda da aynı hesapla** gireceğim; parolayı sohbete yazma." Giriş simge menüsünden yapılır; `tailscale up` komutuna gerek yok. Yine de çalıştırırsan `--shields-up` ekleme: diğer cihazlardan gelen bağlantıları engeller.
  3. "Hedefte (A) 'unattended' kipini aç (başında kimse yokken, Windows oturumu kapalıyken de açık kalır): tepsi simgesi > Preferences > Run unattended, ya da `tailscale set --unattended=true`." Oturum kapalıyken gerçekten çalıştığı: Sınanmadı → TEST_PLANI T6.
  4. "Tailscale'e girdiğim hesabın (Google, Microsoft vb.) iki adımlı doğrulamasının açık olduğunu bana hatırlat: hesap ele geçerse bütün cihazlar açılır."
- **Kanıt (iki bilgisayarda):** `tailscale status` listesinde **iki bilgisayarın adı** görünür; `tailscale ip -4` bir `100.x.y.z` adresi basar. Biri listede yoksa aynı hesapla girilmemiş olabilir. `tailscale` komutu bulunamazsa betikler `C:\Program Files\Tailscale\tailscale.exe` yolunu da dener (Sınanmadı → TEST_PLANI T12).
- **Geri al:** Ayarlar > Uygulamalar'dan Tailscale'i kaldır; cihazı hesaptan düşürmek için önce `tailscale logout` (yalnız o bilgisayarın başındayken; uzaktan çalıştırma, bağlantı kopar).
- **DURUM satırı:** `| <saat> | 1 Tailscale kurulumu | bitti | status: <A adı>, <B adı>; A ip: 100.x.y.z | Uygulamalar'dan kaldir + tailscale logout | 1b anahtar suresi, sonra 0b tekrar (netcheck) |`

### 1b. Anahtar süresi (bir kez sorulur)
**Neden soruluyor:** Tailscale her cihaza bir anahtar verir ve varsayılan olarak 180 gün sonra bitirir. Süre dolunca o cihazın bağlantıları durur. Uzaktaki bilgisayarda bu olursa yeniden girişi o bilgisayarın başında yapmak gerekir. Kapatmak bir güvenlik ödünüdür (çalınan cihaz anahtarı süresiz geçerli kalır), bu yüzden karar sende.

**Ajan şunu sorar (tek mesaj, bir kez):**
> Uzaktan bağlanacağım bilgisayarın Tailscale anahtarı 180 gün sonra sona erer ve o zaman bağlantı kopar. Ne yapalım?
> 1. **Süreyi kapat** (önerilen, uzak bilgisayar için): Tailscale yönetim sayfasında (login.tailscale.com, Machines) o bilgisayarın menüsünden "Disable Key Expiry" seçilir; sayfa "Done. The keys for that device will no longer expire." der. Bunu sen tarayıcıda yaparsın, ajan yapmaz.
> 2. **Kapatma, takvime hatırlatma yaz:** 180 gün sonrası için "Tailscale anahtarı bitiyor, uzak bilgisayarın başında yeniden giriş yap" hatırlatması koyalım. Süre dolmadan o bilgisayarın başına geçip girişi yenilemen gerekir.
> Hangisi?

**Ajanın yapacakları:**
- Cevabı `DURUM.md`'ye yaz: `| <saat> | 1 anahtar suresi | bitti | secim=kapat ya da secim=180gun | yok | 0b tekrar (netcheck), sonra 2 |`.
- Cevap yoksa ya da "bilmiyorum" ise **seçenek 2** uygulanır (varsayılan güvenli kol): tarih hesaplanır (bugün + 180 gün, komutla ölçülür), kullanıcıya yazılı hatırlatma metni verilir.
- Ajan Tailscale yönetim sayfasında değişiklik **yapmaz**; yalnız adım adım tarif eder.

**Ajan ASLA yapmaz (kırmızı):** uzaktaki bilgisayarda `tailscale up --force-reauth` çalıştırmak. Belge: bu komut tailnet bağlantısını düşürebilir ve bağlantı kesilirse giriş için başka bir yol yoksa uzaktan yapılmamalıdır. Anahtar süresi dolmuşsa çare o bilgisayarın başında yeniden giriştir. (KAYNAKLAR: "Tailscale: anahtar süresi, kurulum hizmetleri".)

---

## Adım 2. Bağlantı doğrudan mı, röle mi?

Tailscale ilk paketleri en yakın röle sunucusundan (DERP) geçirir, bu sırada doğrudan yol arar. Yol bulunursa trafik doğrudan akar; bulunamazsa şifreli trafik röleden geçer, röle onu okuyamaz. Bağlantıyı kurmak kolay, **hangisi olduğunu görmek** ayrı iştir.

Önce B açık ve Tailscale'e girmiş olmalı (telefonsa Tailscale uygulaması açık, "Connected"). İki cihaz aynı evdeyse sonuç "yerel ağ" çıkar: bu, internet üzerinden çalıştığının kanıtı değildir; asıl sınama Adım 5'te B mobil verideyken yapılır.
- **Yap (A'da ajanına):** "Önce `P araclar\baglanti_kanit.ps1` seçeneksiz çalıştır, çıkan cihaz listesinden B'nin adını bana sor (bilmiyorsam listeyi birlikte okuyalım); cihaz adlarını listeler ve (Tailscale kuruluyken) çıkış kodu 2 verir, bu beklenir, hata değil. Sonra `P araclar\baglanti_kanit.ps1 -Es <B'nin adı>` çalıştır ve çıktıyı olduğu gibi göster. Betik 'DOĞRUDAN' demeden 'doğrudan bağlandı' deme."
- **Kanıt:** Betik `tailscale status` ve `tailscale ping --until-direct --c=10 --timeout=10s <eş>` çalıştırır (`--until-direct`: doğrudan yol kurulunca durur). Hüküm satırları ve DURUM satırının kanıt alanı. İlk ölçüm yol kurulurken alınır ve yüksek çıkabilir (denemede 309 ms, sonraki pingler 34-45 ms); kararlı gecikme için birkaç ping daha bak:

| Çıkış | Hüküm satırı (betikteki gibi) | DURUM kanıt alanı |
|---|---|---|
| 0 | `[TAMAM] HÜKÜM: DOĞRUDAN (internet üzerinden, aracı yok): <adres:port>, <n> ms.` | `DOGRUDAN <n>ms <adres:port>` |
| 0 | `[TAMAM] HÜKÜM: DOĞRUDAN, yerel ağ adresi üzerinden (...)` + `[UYARI] ... kanıtı DEĞİLDİR ...` | `DOGRUDAN-yerel-ag <n>ms (internet kaniti degil)` |
| 10 | `[UYARI] HÜKÜM: RÖLE (DERP aracı sunucusu): ...` | `ROLE <n>ms` |
| 11 | `[UYARI] HÜKÜM: EŞ RÖLE: ...` (aynı hesaptaki başka bir cihaz aracılık ediyor) | `ESROLE <n>ms` |
| 20 | `[UYARI] HÜKÜM: EŞ YANIT VERMEDİ ya da çıktı okunamadı. ...` | `YANIT-YOK (...)` |
| 30 | `[YOK] Tailscale kurulu değil. Önce Adım 1.` | `Tailscale yok` |
| 2 | (seçeneksiz çalıştırma: cihaz listesi) | DURUM satırı basılmaz |

  Belgedeki örnek çıktıda doğrudan yol `via 140.82.13.138:41641` gibi görünür; oradaki port Tailscale'in kendi kullandığı porttur, **senin açman gereken bir port değildir**.
- **Ne zaman devam edilir:** `DOGRUDAN`, `ROLE` ya da `DOGRUDAN-yerel-ag` ile Adım 3'e geçilebilir. Ama iki bilgisayar aynı evdeyse sonuç `DOGRUDAN-yerel-ag` çıkar ve **internet kanıtı değildir**; asıl kanıt Adım 5'te B telefon hotspot'undayken alınır (TEST_PLANI T3). `ROLE` hata değildir; bağlantı çalışır, hız biraz düşer. Sonuç `ROLE` ya da `ESROLE` ise betik altına bir **ROL NEDEN KARTI** basar: bu bilgisayarın ağında UDP engeli ya da zor NAT görünüyor mu (yalnız `tailscale netcheck` gerçekten gösteriyorsa yazar, tahmin etmez) ve üç seçenek: rölede devam, birkaç dakika sonra yeniden dene, B'yi telefon hotspot'una alıp karşılaştır. Ajan kartı olduğu gibi gösterir, seçimi sana bırakır; modemde port ya da UPnP açtırmaz. `YANIT-YOK` ise ajan durur ve sana sorar (B kapalı, uykuda ya da aynı hesapta değil olabilir).
- İki taraf da "zor NAT" (`zorNAT:true`) arkasındaysa doğrudan yol çok zor kurulur ve röle çalışır; ayrıntı ve sayılar `KAYNAKLAR.md`'de (Tailscale, K1 "How NAT traversal works").
- **Geri al:** gerek yok.
- **DURUM satırı:** betiğin bastığı satır.

---

## İki kapı kuralı (bağlantını kaybetmemek için)

Uzaktan bağlıyken güvenlik duvarını yanlış değiştirirsen bağlantı kopar ve bilgisayara bir daha giremezsin. Bunun için iki önlem var:
1. **Güvenlik ağı:** `rdp_tailscale_kilit.ps1` ve `rustdesk_tailscale_kilit.ps1` duvarı değiştirmeden önce duvarın yedeğini alır ve "N dakika sonra bu yedeği geri yükle" diyen gizli bir görev (`DogrudanUzakMasaustu-GeriAl`) kurar. Her şey yolundaysa sen "kalsın" dersin, ajan görevi kaldırır (`P araclar\geri_al_zamanlayici.ps1 -Iptal`). Yolunda gitmezse ya da bağlantı koparsa bilgisayar süre dolunca **kendiliğinden** eski haline döner.
2. **İkinci kapı:** yeni yol ikinci cihazdan çalıştığı görülmeden eski yol kapatılmaz. Kilit sırasında senin ikinci kapın: geri alma görevi + gerekirse bilgisayarın başına gidebilmek.

Bilmen gerekenler:
- Geri yükleme **bütün** duvar ayarını yedek anına döndürür: bu süre içinde yaptığın başka duvar değişikliği de geri gider.
- Zaten bekleyen bir geri alma görevi varsa yenisi kurulmaz (iyi yedeği ezmemek için): `HATA: Zaten bekleyen bir geri alma gorevi var ...` (çıkış 3). Önce `-Iptal` ya da süre dolsun.
- `-Iptal` `-Uygula` istemez; yazınca gerçekten kaldırır. Yalnız ne yapacağını görmek için `-Iptal -DryRun`.
- `geri_al_zamanlayici.ps1`'i tek başına yalnız REHBER dışında elle duvar/ağ değişikliği yapacaksan kullan.
- Teknik not: görev SYSTEM (Windows'un en yetkili hesabı) olarak, pencere açmadan çalışır. Bu yüzden dosyaları `%ProgramData%\dogrudan-uzak-masaustu\` altındadır ve klasör yalnız SYSTEM ile yöneticilere yazılabilir yapılır: sıradan kullanıcının değiştirebildiği bir betiği SYSTEM'e çalıştırtmak güvenlik açığı olurdu.

---

## Adım 3a. Windows Pro: Uzak Masaüstü yalnız Tailscale üzerinden

Yalnız hedef (A) Windows Pro/Enterprise/Education ise. Home'da betik `DUR: Bu bilgisayar Windows Home ...` der (çıkış 5): 3b'ye geç.

### 3a-1 Uzak Masaüstü'nü aç ve Tailscale'den dene (kilitsiz)
- **Yap:** "Hedefte Ayarlar > Sistem > Uzak Masaüstü'nde 'Uzak Masaüstünü etkinleştir' kapalıysa bana söyle, ben açarım. Ağ Düzeyinde Kimlik Doğrulama (NLA) açık kalsın." Sonra B'de Uzak Masaüstü Bağlantısı'nı (`mstsc`) aç, A'nın Tailscale adresini (`tailscale ip -4`, 100.x.y.z) yaz, Windows kullanıcı adı ve parolanla bağlan.
- **Kanıt:** B'den A'nın masaüstü açıldı. Bu, kilitten **önce** Tailscale yolunun çalıştığını gösterir; kilit bu yolu açık bırakır.
- **Geri al:** Uzak Masaüstü'nü aynı yerden kapat.
- **DURUM satırı:** `| <saat> | 3a-1 RDP acik, Tailscale'den denendi | bitti | B'den 100.x.y.z ile baglandi | Ayarlar'dan RDP'yi kapat | 3a-2 |`

### 3a-2 Kilidin önizlemesi (hiçbir şey değişmez)
- **Yap:** "`P araclar\rdp_tailscale_kilit.ps1` seçeneksiz çalıştır, çıktıyı göster; hangi kuralı ekleyip hangilerini kapatacağını açıkla."
- **Kanıt:** Satırlar `[DRYRUN]` ile başlar: `[DRYRUN] Eklenecek kural: 'RDP yalniz Tailscale'  TCP 3389 giris, arayuz 'Tailscale', yalniz 100.64.0.0/10, profil Any.` ve `[DRYRUN] Kapatilacak (N) kural (3389 icin acik giris izinleri): ...` (ya da `Kapatilacak baska 3389 izin kurali bulunamadi.`). Çıkış 0.
- **Geri al:** gerek yok.
- **DURUM satırı:** betiğin bastığı satır.

### 3a-3 Kilidi uygula (yönetici)
- **Yap:** "Yönetici PowerShell'de `P araclar\rdp_tailscale_kilit.ps1 -Dakika 15 -Uygula` çalıştır. Betik önce güvenlik ağını kurar, sonra Tailscale'e özel kuralı ekler, sonra 3389'a açık öteki giriş izinlerini kapatır. Çıktıyı göster. 15 dakika içinde 3a-4'ü bitireceğiz." (Süreyi rahat seç; süre dolarsa her şey güvenle eski haline döner, adımı tekrarlarsın.)
- **Kanıt:** Çıkış 0; çıktıda `Tamam: guvenlik agi kuruldu. ...` ve `Tamam: kilit kuruldu. SIMDI KANIT ...` satırları.
- **Geri al:** (a) hiçbir şey yapma: süre dolunca duvar yedeğe döner; (b) hemen: `P araclar\rdp_tailscale_kilit.ps1 -Geri -Uygula` (kuralı siler, kapatılanları açar, bekleyen geri alma görevini de kaldırır).
- **DURUM satırı:** betiğin bastığı satır (`yarim`: doğrulama bekliyor).

### 3a-4 Doğrula ve "kalsın" de
- **Yap:** (1) B'den A'nın Tailscale adresiyle Uzak Masaüstü'ne bağlan: **bağlanmalı**. (2) Evde, aynı ağda **başka bir cihaz** varsa ondan A'nın yerel adresine (A'da `ipconfig` ile görülen 192.168.x.x gibi adres) bağlanmayı dene: **bağlanmamalı**. Böyle bir cihaz yoksa (2)'yi atla ve DURUM'a "yerel ağ reddi denenmedi" yaz.
- **Kanıt:** sonuçları sen söylersin, ajan yazar. İkisi de beklendiği gibiyse "**kalsın**" de; ajan `P araclar\geri_al_zamanlayici.ps1 -Iptal` çalıştırır ve `Tamam: geri alma gorevi kaldirildi. Yeni duvar ayari kalici.` çıktısını gösterir.
- **Geri al:** sonuç farklıysa hiçbir şey yapma (süre dolunca eski hale döner) ya da `-Geri -Uygula`.
- **DURUM satırı:** `| <saat> | 3a-4 kilit dogrulandi | bitti | Tailscale: baglandi; yerel ag: reddedildi/denenmedi; gorev kaldirildi | P araclar\rdp_tailscale_kilit.ps1 -Geri -Uygula | 4 guvenlik |`

### 3a: çıkış kodları ve takılmalar
| Çıkış / belirti | Anlamı | Ne yapılır |
|---|---|---|
| 2 `HATA: Yonetici olarak calistirilmali...` | yönetici değil | PowerShell'i "Yönetici olarak çalıştır" ile aç |
| 5 `DUR: Bu bilgisayar Windows Home...` | Home sunucu olamaz | Adım 3b |
| 6 `DUR: '<ad>' adli ag arayuzu yok...` | Tailscale kurulu/bağlı değil ya da arayüz adı farklı | Adım 1; `Get-NetAdapter` ile adı bul, `-ArayuzAdi "<ad>"` ver |
| 7 `DUR: Guvenlik agi (geri_al_zamanlayici) kurulamadi...` | güvenlik ağı kurulamadı (ör. bekleyen görev, yedek alınamadı) | üstteki hata satırını oku; duvara dokunulmadı |
| 8 `UYARI: Kilit geri alindi ama bekleyen geri alma gorevi kaldirilamadi...` | `-Geri`'de görev kalmış | `P araclar\geri_al_zamanlayici.ps1 -Iptal` |
| 1 `HATA: ...` | beklenmeyen hata | görev kurulduysa süre dolunca eski hale döner; `-Iptal` ETME |
| Tailscale'den de bağlanılamıyor | Uzak Masaüstü kapalı olabilir | `-Geri -Uygula`; 3a-1'e dön |
| Yerel ağdan hâlâ bağlanılıyor | başka bir 3389 kuralı açık kalmış | ajan `Get-NetFirewallPortFilter` ile 3389 kurallarını listeler, kalanı yalnız adıyla (`-Name`) kapatır; adsız `Disable-NetFirewallRule` **bütün** kuralları kapatır, asla çalıştırılmaz |

Sınanmadı → TEST_PLANI T9, T11: görevin gerçekten gizli ve zamanında çalışması, kuralın Tailscale'e izin verip yerel ağı engellemesi, arayüz adının "Tailscale" olması. İlk güvenli deneme T9: `P araclar\geri_al_zamanlayici.ps1 -Dakika 2 -Uygula` (kilitsiz).

---

## Adım 3b. Windows Home: RustDesk doğrudan IP (Tailscale üzerinden)

Yalnız hedef (A) Windows Home ise. RustDesk ayarlarını sen tıklarsın; ajan yalnız her adımın kanıtını çalıştırır. Bu bölümde "kendin tıkla" sana, "Kanıt" ajana yöneliktir.

> **Betik yok, bilerek.** RustDesk belgelerinde bu ayarları komut satırından değiştirmenin bir yolu yok (belgedeki komutlar: `--config`, `--import-config`, `--password`, `--get-id`, `--set-id`, `--silent-install`). Belgesiz bir yolu betikleyip "çalışıyor" demek yerine adımlar ekrandan yapılır. Betik yalnız duvar önlemi için vardır (H3b).

Arayüz adları önce İngilizce, yanında Türkçe karşılığıyla verilir. Türkçe adlar RustDesk 1.5.3'te (Türkçe arayüz, Windows 10 Home) ekranda görülerek yazıldı; başka sürümde adlar değişebilir, bulamazsan ajanına ekran görüntüsü göster.

> **Ajan notu:** RustDesk'in arayüzü Windows'un erişilebilirlik katmanında görünmez; ajan ayarları ekran görüntüsüyle okur ve fareyle tıklar. Bir şey yazdıktan sonra ekran görüntüsüyle yazılanı doğrula (denemede Türkçe klavyede `/` karakteri yazılamadı, `100.64.0.010` çıktı).

### H1. RustDesk'i kur (kurulu sürüm, taşınabilir değil) — A ve B
- **Yap:** rustdesk.com ya da RustDesk'in resmî GitHub sürümler sayfasından Windows **kurulum** `.exe`'sini indir ve kur. Dosya adından emin değilsen ajan adı sana gösterip sorsun. Ajan indirilen dosyanın imzasını okuyabilir (`Get-AuthenticodeSignature`: durum `Valid` olmalı) ve yayıncı adını sana gösterir; adı resmî sürüm sayfasındakiyle karşılaştır, tanıdık gelmezse kurma. "Portable" (kurmadan çalışan) sürümü kullanma: yönetici onay penceresi (UAC) çıktığında ekran karşıya gitmez, fare yanıt vermez.
- **Kanıt:** `Test-Path "C:\Program Files\RustDesk\rustdesk.exe"` → `True`.
- **Geri al:** Ayarlar > Uygulamalar > RustDesk > Kaldır.
- **DURUM satırı:** `| <saat> | H1 RustDesk kuruldu | bitti | Test-Path True | Uygulamalar'dan kaldir | H2 |`

### H2. A'da doğrudan IP erişimini aç
- **Yap (A'da, kendin tıkla):** RustDesk > Settings > Security (Ayarlar > Güvenlik); ayarlar soluksa önce **Unlock Security Settings** (**Güvenlik Ayarlarını Aç**) düğmesine bas ve Windows onay penceresine "Evet" de. Sonra **Enable direct IP access** (**Doğrudan IP Erişimini Etkinleştir**) işaretle. Altında **Direct IP access port** kutusu çıkar; 21118 yazıyorsa değiştirme (belgedeki değer; varsayılan olduğu belgede açık değil).
- **Kanıt (A'da):** `netstat -ano | findstr 21118` → bir satır görünmeli (`TCP ... LISTENING` satırı; RustDesk 1.5.3, Windows 10'da `[::]:21118` TCP olarak ölçüldü, ayrıca UDP 21119 da dinlenir. TCP `LISTENING` satırı yoksa dur). Satır yoksa ayar işaretli mi, RustDesk yeniden başlatıldı mı bak; dur ve DURUM'a yaz.
- **Geri al:** kutunun işaretini kaldır.
- **DURUM satırı:** `| <saat> | H2 direct IP acik | bitti | netstat: <satir> | kutuyu kaldir | H3 |`

### H3. Yalnız Tailscale adreslerine izin ver (beyaz liste)
- **Yap (A'da):** Security > **Use IP Whitelisting** (**IP Beyaz Listeyi Kullan**) işaretle, kutuya `100.64.0.0/10` yaz (Tailscale'in cihazlara verdiği aralık). Boş liste "filtre yok" demektir: herkese açık. Yazdıktan sonra kutuda tam `100.64.0.0/10` yazdığını gözünle gör. Yanında sarı bir uyarı simgesi çıkar: hata değil, "liste etkin" işaretidir (RustDesk kaynak kodu: liste doluyken çizilir; imleci üstüne getirince "Bu masaüstüne yalnızca yetkili IP adresleri bağlanabilir" yazar).
- **Kanıt:** `tailscale ip -4` → A'nın adresi `100.64.0.0 - 100.127.255.255` aralığında. Bu aralık dışından gelen bağlantının reddedilmesi beklenir: Sınanmadı → TEST_PLANI T5b.
- **Geri al:** kutuyu boşalt ya da işareti kaldır.
- **DURUM satırı:** `| <saat> | H3 beyaz liste 100.64.0.0/10 | bitti | A ip: 100.x.y.z | kutuyu bosalt | H4 |`

### H3b. Kafe, otel, umumi Wi-Fi: duvar önlemi (isteğe bağlı, kafeye çıkacaksan yap)
**Bilmen gereken:** RustDesk'i kurmak, Windows güvenlik duvarına `RustDesk Service` adlı bir "izin ver" kuralı ekler (gelen ve giden; hangi ağdan ve adresten gelirse gelsin; kaynak: RustDesk yükleyici kodu, 1.5.3). Yani duvar bu program için kapıyı açık tutar; seni yalnız H3'teki beyaz liste ve H4'teki parola korur. Bilgisayarı kafede umumi Wi-Fi'ye bağlarsan 21118 portu o ağdaki herkese görünür. Beyaz liste onları reddeder ama kapı yine de görünür.
- **Yap (ajanına):** "`P araclar\rustdesk_tailscale_kilit.ps1` önizlemesini çalıştır (varsayılan: hiçbir şeyi değiştirmez), çıktıyı göster. Onaylarsam `P araclar\rustdesk_tailscale_kilit.ps1 -Uygula` (yönetici); güvenlik ağını (geri alma zamanlayıcısı) betik kendisi kurar, ayrıca kurma." Betik, TCP 21118 ve UDP 21119 için Tailscale dışı adreslerden gelen bağlantıyı **engeller**; RustDesk'in kendi kuralına dokunmaz. Kural yalnız gelen yöndedir: RustDesk'in dışarı bağlantıları ve Tailscale etkilenmez.
- **Kanıt:** `-Uygula` bitince B'den (Tailscale açık) yine bağlanabiliyor musun? Bağlanıyorsan zamanlayıcı görevini iptal edip kuralı kalıcı bırak (iki kapı kuralı). Denendi: kural varken telefondan (LTE) bağlanıldı.
- **Geri al:** `P araclar\rustdesk_tailscale_kilit.ps1 -Geri -Uygula` (yönetici; yalnız `-Geri` önizlemedir). Kuralları ve bekleyen geri alma görevini birlikte kaldırır.
- **Yan etki:** aynı evdeki başka bir bilgisayar A'ya yerel adresiyle (192.168...) RustDesk'ten bağlanamaz; hep Tailscale adresini (`100.x.y.z`) kullan.
- **Alışkanlık:** masadan kalkarken Win+L ile ekranı kilitle. Kafe ağı "Ortak" (Public) kalsın; "Özel"e çevirme.
- **DURUM satırı:** `| <saat> | H3b kafe onlemi | bitti | B'den baglandi, kural var | rustdesk_tailscale_kilit -Geri | H4 |`

### H4. Parola ve onay kipi
- **Yap (A'da, kendin):** Security > Password bölümünde:
  - Doğrulama yöntemi: **Use permanent password** (**Kalıcı parola kullan**). Bunu seçince tek kullanımlık seçenekler soluklaşır; iyi. Önce **Set permanent password** (**Kalıcı parola oluştur**) ile parolayı sen belirle. Parola **en az 16 karakter** olsun (arayüz 8'den itibaren kabul eder, sen daha uzun yaz), bu iş için tek olsun; ajana, sohbete, dosyaya yazma. Ajan parolayı sormaz; pencereyi sen doldurursun.
  - **Telefondan bağlanacaksan** parolayı yalnız **İngilizce harf ve rakamla** yaz (Türkçe harf ve noktalama yok). Denemede ilk parola telefonda kabul edilmedi, yalnız İngilizce harf+rakamla yeniden yapılınca kabul edildi; nedeni doğrulanmadı (tahminim: telefon klavyesi bazı işaretleri değiştiriyor). Uzunluk güvenliği korur, işaret gerekmez.
  - **Neden kalıcı parola:** varsayılandaki tek kullanımlık parola her başarılı bağlantıdan sonra değişir ve yalnız A'nın ekranında, RustDesk'in **Ana Sayfa** sekmesinde (**Tek Kullanımlık Parola** kutusu) görünür; Ayarlar sekmesindeyken görünmez. B uzaktaysa o parolaya ulaşamazsın. Tek kullanımlık parola yalnız A'nın başındayken yapılan ilk deneme içindir.
  - Onay kipi (approve-mode): varsayılan `password-click`, ekranda **Accept sessions via both** (**Her ikisi aracılığıyla oturumları kabul edin**). Anlamı **parola VEYA tıklama**: B doğru kalıcı parolayı girerse karşıda kimse olmadan girer; parola yoksa ya da yanlışsa A'da "Kabul Et / İptal" penceresi çıkar ve biri tıklamazsa bağlantı kurulmaz (RustDesk belgesi: "via password or manually click"). "Tıklama yoluyla oturumları kabul edin" (`click`) seçersen başında kimse yokken giremezsin; seçme, `password`'a da gerek yok. Denendi: kalıcı parola kurulduktan sonra telefon parolayla bağlandı (iPhone, LTE). Kalıcı parolayla bağlanırken A'da kısa bir RustDesk penceresi görünüp birkaç saniyede kendini gizledi; kimsenin tıklaması gerekmedi (kullanıcı gözlemi, deneme 1). Kimse tıklamayınca parolasız isteğin düşmesi: Sınanmadı → TEST_PLANI.
  - **A'daki istek penceresine dokunma.** B bağlanırken A'nın sağ üstünde "... cihazınıza erişim talep ediyor, Kabul Et / İptal" penceresi çıkarsa ve bağlanan sensen: dokunma. Pencerede **İptal** telefondaki isteği de kapatır. Tanımadığın bir cihaz adı ya da adres görürsen o zaman İptal'e bas.
  - **İzinler** (Security > Permissions, "İzinler"): kullanmayacağın yetkileri kapat. Terminali etkinleştir, TCP Tüneline izin ver, Kamerayı etkinleştir, Uzak yazıcıyı etkinleştir, Kayıt Oturumunu Aktif Et. Klavye ve Fare, pano, dosya aktarımı ve ses senin tercihin (denemede açık bırakıldı). Yerel Ağ Keşfi için "Yerel Ağ Keşfine İzin Verme" seçilebilir; bu rehberin yolu keşfe ihtiyaç duymaz. Bu yetkilerin varsayılanı "açık"tır (RustDesk belgesi); "kapat" önerisi belgede yok, en az yetki ilkesidir.
  - RustDesk'in "ID beyaz listesi" kimlik doğrulama değildir (belge: kimliği bağlanan taraf bildirir); parolanın yerini tutmaz.
  - Parolayı komut satırından (`--password`) verme: komut geçmişinde görünebilir (ilke).
- **Kanıt:** H5'te bağlanırken parola **sorulur**; sorulmuyorsa dur. (Telefonda "Parolayı hatırla" işaretlediysen sonraki bağlanmalarda sorulmaz; bu normal, Ek A'ya bak.)
- **Geri al:** parolayı değiştir; kipi eski haline getir.
- **DURUM satırı:** `| <saat> | H4 kalici parola, onay kipi: <password-click/password> | bitti | parola YAZILMAZ | parolayi degistir | H5 |`

### Beklenen ekranlar (H5'ten önce oku)
> **Bağlanırken görebileceğin ve hata OLMAYAN dört şey**
>
> 1. **Kırmızı kalkan ve "direct and unencrypted connection" (Türkçe arayüzde: "Doğrudan ve şifrelenmemiş bağlantı (TCP)").** RustDesk doğrudan IP bağlantısını kendisi şifrelemez ve bunu böyle işaretler. Tailscale adresine (`100.x.y.z`) bağlanıyorsan trafik Tailscale tüneliyle şifrelenir; Tailscale'in kendi yazısı bunu söylüyor ve RustDesk geliştiricisi doğrudan IP'yi bir VPN ile birlikte kullanmayı öneriyor. **Koşul: bağlandığın adres `100.` ile başlıyorsa.** Başka bir adrese (örneğin evinin `192.168...` adresine ya da bir internet adresine) doğrudan bağlanıyorsan bu uyarı gerçektir: dur, o adrese bağlanma. Bu yüzden H3'teki beyaz liste gerekli: Tailscale dışı adresler zaten bağlanamasın.
> 2. **Kurulumdan sonra altta "Ready, For faster connection, please set up your own server".** Bu yalnız RustDesk'in kendi (kamu) sunucusunu kullananlara öneridir. Bu rehberin yolu o sunucuyu kullanmaz; yok say, ayar yapma, sunucu kurma.
> 3. **Bağlanınca parola sorulması.** Beklenen; H4'te belirlediğin kalıcı parolayı sen yazarsın (ajana verme). Sorulmuyorsa (ve telefonda "Parolayı hatırla" işaretli değilse) dur ve DURUM.md'ye yaz.
> 4. **A'da sağ üstte "Kabul Et / İptal" penceresi.** Parola yoksa ya da yanlışsa çıkar (H4). Bağlanan sensen dokunma; İptal telefondaki isteği de kapatır. Cihaz adını tanımıyorsan İptal'e bas.
>
> **Sana yazılacak ID numarası (9 haneli)** ile bağlanma: bu yolu kullanma; o RustDesk'in herkese açık, daha yavaş rölelerinden geçer. Biz yalnız Tailscale IP'siyle bağlanırız.
> **Bunlardan biri değilse** (örneğin "Connected, waiting for image", "Failed to connect ...:21118", siyah ekran): panik yok, `SORUN_GIDERME.md` "C. RustDesk bilinen sorunlar" tablosuna bak; ajan hata cümlesini harfiyen kopyalayıp tabloda arasın.

### H5. B'den bağlan
- **Yap (B'de, kendin):** RustDesk'te bağlanma kutusuna A'nın **Tailscale IP'sini** yaz (RustDesk kimlik numarasını değil), bağlan, H4'teki parolayı gir. Yalnız IP yeterli (denendi: iPhone'da `100.x.y.z` yazınca parola ekranı geldi); olmazsa `100.x.y.z:21118` biçimini dene. Hangisinin çalıştığını DURUM'a yaz. Doğrudan IP bağlantısı RustDesk'in kendi şifrelemesini kullanmaz; RustDesk geliştiricisi bu yüzden VPN ile kullanmayı öneriyor. Bu rehberde o VPN Tailscale'dir; RustDesk'in doğrudan IP'sini Tailscale dışına açma.
- **Kanıt:** (1) A'nın masaüstü açıldı, fare ve klavye çalışıyor; (2) A'da ajan `P araclar\baglanti_kanit.ps1 -Es <B'nin adı>` ile doğrudan mı röle mi yazar.
- **Geri al:** bağlantıyı kapat; H2 kutusunu kaldırmak doğrudan erişimi tamamen kapatır.
- **DURUM satırı:** `| <saat> | H5 B'den baglandi | bitti | bicim: <IP / IP:21118>; tailscale: <DOGRUDAN/ROLE> | baglantiyi kapat | H6 |`

### H6. Yeniden başlatma ve uyku
- **Yap:** (a) hedefte uyku kapalı mı: `powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE` (prizdeyken değer 0: Microsoft'a göre bilgisayar boşta kalınca hiç uykuya geçmez; KAYNAKLAR: "Ek kaynaklar", uyku). Ayar doğru görünse de dene: A'ya 15 dakika dokunmadan bekle, sonra B'den bağlan (TEST_PLANI); (b) A'yı yeniden başlat, **oturum açmadan** (kilit ekranındayken) B'den H5'i dene; (c) oturum açtıktan sonra yine dene.
- **Bilinen:** UAC penceresinin karşıya gitmesi için kurulu sürüm şarttır (belge); yönetici onayı istendiğinde yine de A'nın başında birinin onaylaması gerekir (belge). Kurulu RustDesk'in kilit ekranında ve yeniden başlatma sonrası bağlantı kabul etmesi belgede yazmıyor: Sınanmadı → TEST_PLANI T6. Olmazsa rehber bunu vaat etmez; DURUM'a yaz.
- **Geri al:** uyku ayarını eski değerine al.
- **DURUM satırı:** `| <saat> | H6 yeniden baslatma | bitti/yarim | kilit ekraninda: <evet/hayir>, oturumda: <evet/hayir> | uyku ayarini geri al | 4 guvenlik |`

### 3b: ajana yasaklar
- Bu bölümde modem, Tailscale ya da başka ağ ayarını değiştirme. Windows güvenlik duvarı yalnız `rustdesk_tailscale_kilit.ps1` ile (H3b), zamanlayıcı önce, sen onaylayınca değişir.
- RustDesk'te beyaz listeyi boş, parolayı boş bırakma.
- RustDesk'in genel sunucusu üzerinden "kimlik numarasıyla bağlanma"yı bu rehberin yolu gibi sunma; bu rehberin yolu Tailscale IP'siyle doğrudan bağlantıdır.

---

## Adım 4. Güvenlik son kontrolü

- **Yap (ajanına):** "Aşağıdaki soruları tek tek sor, her cevabı DURUM.md'ye yaz. Parola ya da anahtar isteme."
  1. Tailscale'e girdiğin hesabın iki adımlı doğrulaması açık mı?
  2. Modemde uzak masaüstü için açılmış port **yok** mu? (Bu rehber port açmaz; daha önce açtıysan kapat.)
  3. Pro: Uzak Masaüstü yalnız Tailscale'den mi açık (3a-4 kanıtı) ve NLA açık mı?
  4. Home: RustDesk'te beyaz liste `100.64.0.0/10` dolu mu, kalıcı parola uzun mu (H3, H4)?
  5. Hedefte uyku "hiçbir zaman" mı, Tailscale "unattended" kipinde mi?
  6. Kurulan her program resmî kaynaktan mı indirildi?
  7. Bekleyen geri alma görevi var mı? (`P araclar\geri_al_zamanlayici.ps1 -Iptal -DryRun` söyler; iş bittiyse ve "kalsın" dediysen `-Iptal`.)
  8. Anahtar süresi için seçim yapıldı mı (1b: kapatıldı ya da hatırlatma tarihi yazıldı)?
- **Kanıt:** sekiz sorunun cevabı DURUM.md'de; "hayır" çıkan madde düzeltilmeden "bitti" denmez.
- **Geri al:** gerek yok.
- **DURUM satırı:** `| <saat> | 4 guvenlik | bitti | 2FA acik, port yok, kilit/beyaz liste tamam, uyku kapali, resmi kaynak, gorev yok | gerek yok | 5 gercek test |`

---

## Adım 5. Gerçek iki-ağ testi

Aynı evde çalışması internetten çalıştığını kanıtlamaz. `TEST_PLANI.md`'yi uygula; B **telefon hotspot'una** bağlıyken:
- Herkes: T1-T4.
- Pro dalı: T9 (önce, kilitsiz kısa deneme), T5a, T11.
- Home dalı: T5b (6 kritik kontrol).
- Herkes: T6, T7, T8, T12, T13 (ajan kuralları kendiliğinden yüklendi mi), T14 (anahtar süresi seçimi), en son sonuç tablosu T10.

T10 doldurulmadan kurulum "bitti" sayılmaz.

**Başardın mı? (3 satır):** (1) B'nin ekranında A'nın masaüstü açık ve fare/klavye çalışıyor. (2) Ajanın tek satırı: `DOĞRUDAN, ~40 ms` (ya da RÖLE ve ms). (3) Sen "oldu" dersin. Ajan `netstat` gibi kanıtları kendi dilinde, tek cümleyle anlatsın. Beklenmeyen sonuçta `SORUN_GIDERME.md`'deki ilgili maddeye bak.

---

## Günlük kullanım (kurulum bittikten sonra)

- **Bağlanmak:** B'de Tailscale açık olsun (tepside). Pro: Uzak Masaüstü Bağlantısı (`mstsc`) → A'nın `100.x.y.z` adresi. Home: RustDesk → A'nın `100.x.y.z` adresi (H5'te çalışan biçim) + parola.
- **Hızlı mı yavaş mı:** A'da `P araclar\baglanti_kanit.ps1 -Es <B'nin adı>`; `ROLE` çıkıyorsa yavaşlığın nedeni odur.
- **Bağlanamıyorum:** sırayla bak: A açık ve uyanık mı, iki cihaz `tailscale status` listesinde mi, Home'da onay kipi ne (H4). Sonra `SORUN_GIDERME.md`.
- **Bir şeyi değiştireceksen:** ajanı yine bu klasörde aç; önce `DURUM.md`'yi okusun.
- **Bağlantı kartı:** kurulum bitince ajan `BAGLANTI_KARTI.md`'yi doldurur: B'de neye tıklayıp hangi adrese bağlanacağın, 5-6 satır. Kartta parola yoktur; yine de kartı başkasıyla paylaşma.
- **Anahtar süresi:** 1b'de süreyi kapatmadıysan takvimdeki tarihten önce A'nın başında Tailscale'e yeniden gir.

---

## Ekler

### Ek A. Telefondan bağlanmak
Tailscale ve RustDesk'in resmî mobil uygulamaları var. Telefonu aynı Tailscale hesabına ekle; Pro'da bir Uzak Masaüstü istemcisiyle, Home'da RustDesk mobil uygulamasıyla A'nın `100.x.y.z` adresine bağlan. **Denendi (iPhone, mobil veri, Wi-Fi kapalı; RustDesk 1.5.3 Windows 10 Home, Tailscale doğrudan yol, ~40 ms):** doğrudan yol kuruldu ve RustDesk bağlantısı çalıştı. Telefonda sırayla:
1. Tailscale'i kur, aç; "VPN yapılandırması" iznini onayla (iPhone sorar, ajan veremez) ve A ile **aynı** hesaba gir. Bağlanmadan önce telefonda Tailscale açık olsun.
2. RustDesk'i kur; bağlanma kutusuna A'nın `100.x.y.z` adresini yaz; parola ekranında H4'teki kalıcı parolayı yaz (yalnız İngilizce harf+rakam).
3. Telefonu yan çevir; ekran dar kalırsa iki parmakla büyüt; klavye ve tuş çubuğu ekranı kaplarsa klavyeyi kapat.
4. İstersen "Parolayı hatırla"yı işaretle: sonraki bağlanmalarda parola sorulmaz. Bedeli: telefon kilitsiz kaybolursa parolasız giriş. Bu yüzden telefonda ekran kilidi kodu aç ve Tailscale hesabında iki adımlı doğrulama açık olsun; kayıpta Tailscale yönetim sayfasından telefonu sil, RustDesk parolasını değiştir.
5. Üstte kırmızı kalkan "Doğrudan ve şifrelenmemiş bağlantı (TCP)" görürsen beklenendir ("Beklenen ekranlar").

Pro'da bir Uzak Masaüstü istemcisi kullan. İki kapı kuralı burada da geçerli.

### Ek B. "Kendim yazmak istiyorum"
Öğrenmek için güzel bir proje; günlük kullanım için önerilmez. Ekran yakalama, sıkıştırma, şifreleme, kimlik doğrulama ve röle yedeği ayrı ayrı uzmanlık ister; hazır araçlar aynı tekniği (NAT delme + röle) yıllardır, yaygın biçimde kullanıyor.
Yine de denersen: (1) tanıştırıcı sunucu ve röle yedeğini baştan planla, (2) testi farklı iki ağda yap, (3) şifrelemeyi icat etme, yaygın ve bakımlı bir kütüphane kullan, (4) `SORUN_GIDERME.md` madde 1, 2, 9 ve 14'ü oku.
