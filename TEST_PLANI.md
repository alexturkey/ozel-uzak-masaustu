# TEST_PLANI.md: gerçek iki-ağ testi

Bu rehberdeki adımlar henüz gerçek iki ağ arasında sınanmadı; bu test onu yapar. Sonuçları `DURUM.md`'ye yaz; bir sorun ya da düzeltme bildirmek istersen depoda issue aç.

## Hazırlık (10 dk)
- **Bilgisayar A**: evdeki, uzaktan bağlanılacak bilgisayar. Hep açık, uyku kapalı.
- **Bilgisayar B**: bağlanacak ikinci bilgisayar (dizüstü). Bunu **telefonunun mobil hotspot'una** bağla (modemden değil). Böylece A ile B farklı ağlarda olur.
- Her iki bilgisayarda Tailscale kurulu, aynı hesapla girişli (REHBER adım 1).
- Windows sürümü: A'da `winver` çalıştır; **Pro** ise dal 3a, **Home** ise dal 3b'yi izle.
- Sonuçları `DURUM.md`'ye yaz. Bir adım başarısızsa sıradakine geçme; yanındaki SORUN_GIDERME maddesine bak.

Not: komutları PowerShell'de çalıştır. "Beklenen" sütunundaki cümleler belgeye ya da komutun gerçek davranışına göre; çıktının birebir metni sürümle değişebilir. Farklıysa aynen kopyalayıp `DURUM.md`'ye yaz.

## T1. İki bilgisayar farklı ağda mı?
- Komut (A ve B'de, ikisinde ayrı): `Invoke-RestMethod https://ifconfig.me/ip`
- Beklenen: iki bilgisayarda **farklı** genel IP.
- Aynıysa: B hâlâ evdeki modemdedir; hotspot'a bağlı değildir. Ağ simgesine bak, yeniden bağlan.
- SORUN_GIDERME: hata 2 (aynı ağda test).
- Ek bilgi (isteğe bağlı): A'nın modeminin WAN IP'si ile bu IP farklıysa operatör çok kişiyi tek IP'ye bağlıyor (CGNAT); bu rehber için sorun değil. SORUN_GIDERME hata 4.

## T2. İki bilgisayar birbirini görüyor mu?
- Komut (B'de): `tailscale status`
- Beklenen: A'nın adı listede ve satırında `direct` ya da `relay` yazar (belge: Tailscale connection types). `offline` ya da hiç görünmüyorsa Tailscale çalışmıyordur.
- Başarısızsa: A ve B'de aynı hesapla girildiğini kontrol et, Tailscale'i yeniden başlat. SORUN_GIDERME hata 1 ve 7.

## T3. Doğrudan mı, röle mi?
- Komut (B'de): `tailscale ping --until-direct <A'nın adı ya da Tailscale IP'si>`
- Beklenen: ilk cevaplar röle üzerinden gelebilir; sonra doğrudan yol bulunursa cevapta doğrudan bir IP:port görünür (belge: Tailscale connection types). Sonunda "direct connection not established" yazarsa bu ağda doğrudan yol bulunamadı: **röle ile çalışmak normaldir**, gecikme biraz artar; hata değildir.
- Aynı sonucu `araclar\baglanti_kanit.ps1` Türkçe hüküm olarak verir; çıktısını `DURUM.md`'ye yaz.
- Başarısızsa: SORUN_GIDERME hata 7, 9 (UDP engelli ağ).

## T4. Dışarıdan hiçbir uzak masaüstü kapısı açık değil mi?
- Komut (B'de, hotspot'ta, A'nın **genel IP'siyle**; T1'deki A'nın IP'si): `Test-NetConnection <A'nın genel IP'si> -Port 3389`
- Beklenen: `TcpTestSucceeded : False`.
- `True` ise: A'daki uzak masaüstü dışarıya açık demektir; **hemen** REHBER adım 3a/4'e dön, 3389'u yalnız Tailscale'e kilitle. SORUN_GIDERME hata 5.

## T5a. Dal Pro: yerleşik Uzak Masaüstü yalnız Tailscale üzerinden
- Komut (B'de): `Test-NetConnection <A'nın Tailscale IP'si> -Port 3389`
- Beklenen: `TcpTestSucceeded : True`.
- Sonra B'de Uzak Masaüstü Bağlantısı'nı (`mstsc`) aç, A'nın **Tailscale IP'siyle** bağlan; A'nın kullanıcı adı ve parolasıyla gir (parolayı ajana yazma).
- Beklenen: A'nın masaüstü görünür.
- Başarısızsa: A'da Uzak Masaüstü'nün açık olduğunu kontrol et; Home'da bu seçenek hiç yoktur (SORUN_GIDERME hata 6, dal 3b'ye geç).

## T5b. Dal Home: RustDesk doğrudan IP, Tailscale adresiyle (7 KRİTİK KONTROL)

**Bu adımın hiçbir parçası belgede ayrıca tarif edilmemiş ve hiç denenmedi**. Kurulum GUI ile yapılır (REHBER 3b, H1-H6); burada yalnız sonuç sınanır. Hangi kontrol ne çıkarsa `DURUM.md`'ye aynen yaz; "çalıştı" ya da "çalışmadı" demek için çıktı gerekir.

Önkoşul (A'da): RustDesk **kurulu sürüm** (taşınabilir değil), "Enable direct IP access" işaretli, "Use IP Whitelisting" kutusunda `100.64.0.0/10`, kalıcı parola belirlenmiş.

**Kritik kontrol 1: ID alanına IP hangi biçimde yazılır?** (Tailscale'in kendi yazısı yalnız Tailscale IP'sini yazmayı söylüyor; sınanmadı)
- B'de RustDesk'in ID alanına **yalnız** `<A'nın Tailscale IP'si>` yaz (Tailscale blogu: "Paste the Tailnet IP of the device you want to control ..."; adres KAYNAKLAR.md).
- Deneme 1'de kayıtta görüldü: yalnız Tailscale IP'si yazılınca (telefondan) parola ekranı geldi; `:21118` gerekmedi. Yine de kendi denemende aynen yaz.
- Beklenen: parola sorar ve bağlanır. Bağlanmazsa **yedek olarak** `<IP>:21118` biçimini dene. **Hangisi çalıştı, hangisi çalışmadı** yaz. İkisi de olmazsa kritik kontrol 2 ve 3'e bak, sonucu `DURUM.md`'ye yaz.

**Kritik kontrol 2: Doğrudan IP portu 21118 TCP (kayıtta görüldü, deneme 1)** (belgede yok; kendi bilgisayarında doğrula)
- A'da: `netstat -ano | findstr 21118`
- Beklenen: `TCP ... :21118 ... LISTENING` satırı (deneme 1'de `[::]:21118` dinliyordu). **Satırı aynen yaz.** UDP görürsen ya da hiç satır yoksa: ayar işaretli mi, RustDesk yeniden başlatıldı mı.
- B'de: `Test-NetConnection <A'nın Tailscale IP'si> -Port 21118` → `TcpTestSucceeded : True`.

**Kritik kontrol 3: Tailscale 100.x adresiyle, hotspot'taki cihazdan bağlanma** (belgede yok)
- B telefon hotspot'unda iken (T1 geçti), kontrol 1'in çalışan biçimiyle bağlan. Parolayı kendin yaz (ajana yazma).
- Beklenen: A'da (parola yeterliyse ya da onay penceresiyle) bağlantı kurulur, B'de A'nın masaüstü görünür, fare ve klavye çalışır.
- Eşzamanlı (B'de): `tailscale ping --until-direct <A>`; sonucu "doğrudan / röle" diye yaz (T3).
- Çalışmazsa: sonuç `DURUM.md`'ye aynen; Home dalı çalışmıyor demektir, issue aç.

**Kritik kontrol 4: Yeniden başlatma sonrası kilit ekranında bağlanabiliyor mu?** (belgede yok: "kurulu RustDesk hizmet olarak başlar, kilit ekranında çalışır" cümlesi bulunamadı)
- A'da uykuyu "Hiçbir zaman" yap. A'yı yeniden başlat; **oturum açma (kilit) ekranında bırak, giriş yapma.** 3 dakika bekle.
- B'de: `tailscale status` → A listede görünmeli (Tailscale hizmeti açıksa). Sonra RustDesk ile bağlan.
- Beklenen: kilit ekranı (parola ekranı) görünür. **Görünmüyorsa ya da bağlanamıyorsa bunu açıkça yaz**; rehber "kilit ekranında çalışır" diye vaat etmez.
- Ayrıca kilitli (Win+L) iken tekrar dene.

**Kritik kontrol 5: Beyaz liste dışından bağlanma REDDEDİLİYOR mu?** (belgede yok; `100.64.0.0/10` değeri rehberin kendi seçimi, RustDesk belgesinde yok)
- B'yi **evdeki modeme (A ile aynı ağa)** bağla. A'nın **yerel ağ IP'siyle** (`ipconfig` ile A'nın 192.168.x.x ya da 10.x.x.x adresini bul) kontrol 1'in çalışan biçimiyle bağlanmayı dene.
- Beklenen: bağlantı **reddedilir ya da hiç kurulmaz** (kaynak adres 100.64.0.0/10 dışında). Bağlanırsa beyaz liste işe yaramıyor demektir: **hemen** kutudaki değeri kontrol et; ikinci kez de bağlanırsa "Use IP Whitelisting" işlemiyor, bunu `DURUM.md`'ye yaz, issue aç ve rehberin Home dalına güvenme.
- Karşı deneme: aynı B'den A'nın Tailscale IP'siyle bağlan: beklenen kabul (kontrol 3).
- Ek (hotspot'ta, B'den): `Test-NetConnection <A'nın genel IP'si> -Port 21118` → beklenen `False` (dışarıdan açık olmamalı).

**Kritik kontrol 6: Onay kipi "Her ikisi" (`password-click`): kalıcı parolayla tıklama gerekiyor mu, parolasız istek ne oluyor?**
- Kayıtta görüldü (deneme 1): parolasız istekte bilgisayar A'da sağ üstte "Kabul Et / İptal" penceresi açıldı. Kalıcı parola kurulduktan sonra telefondan bağlanınca bağlandı; ikinci bağlanışta ("Parolayı hatırla") parola da sormadı. Kalıcı parolayla bağlanırken A'da kısa bir RustDesk penceresi çıkıp birkaç saniyede kendini gizledi; tıklama gerekmedi (kullanıcı gözlemi).
- Senin denemen, A'nın başında biri varken: onay kipini değiştirme ("Her ikisi" kalsın). B'den kalıcı parolayla bağlan; **A'da "Kabul Et" penceresi çıktı mı, çıkmadı mı** yaz. Pencere çıkarsa A'daki kişi dokunmaz: B'nin "İptal"i isteği kapatır, A'daki "İptal" da B'deki isteği kapatır.
- Parolasız deneme: B'den ID alanına yaz, parolayı **yazma**. A'da pencere çıkmalı; **kimse tıklamazsa ne kadar sonra düştüğünü ve hata metnini yaz** (denenmedi).
- Kimse yokken bağlanma (A'nın başında kimse yok, doğru parola): **bağlandı mı** yaz (denenmedi).
- Başarısızlık/uyarı: sonuç REHBER 3b'ye "kimse yokken bağlanacaksan şu kip" notu olarak girer.

**Kritik kontrol 7: 9 haneli ID yolu beyaz listeden geçiyor mu?** (denenmedi)
- B'de Tailscale'i kapat (ya da B'yi Tailscale'siz bir ağa al). RustDesk'te A'nın 9 haneli ID'sini yaz.
- Beklenen (tahmin, belgede yok): "Use IP Whitelisting" yalnız doğrudan IP yolunu süzer; ID yolu RustDesk'in kendi sunucusu/rölesinden geçebilir. **Parola soruldu mu, bağlandı mı** yaz. Parola sorulursa ID yolu açıktır ve parola gücü tek korumadır; rehber bu yüzden "ID ile bağlanma, yalnız Tailscale IP'si" der.

SORUN_GIDERME: hata 5, 6, 10, 11.

## T6. Kilit ekranı, UAC ve yeniden başlatma (A uzaktayken; Home'da kritik kontrol 4 ile birlikte)
- A'da Windows'u kilitle (Win+L); B'den bağlanmayı dene. Beklenen: dal Pro'da kilit ekranı gelir, parola ile açılır; dal Home'da RustDesk kurulu sürümle kilit ekranını görür (belge: kurulu sürüm şart).
- A'da yönetici onayı isteyen bir şey aç (ör. bir kurulum penceresi); B'den ekranı gör. Beklenen: onay penceresi görünür. **Taşınabilir RustDesk'te bu ekran iletilmez** (belge: "The screen cannot be transmitted when the UAC window pops up").
- A'yı yeniden başlat, 3 dakika bekle, B'den tekrar bağlan. Beklenen: giriş yapmadan da (Tailscale hizmet olarak çalışıyorsa) A `tailscale status`'ta görünür.
- Başarısızsa: SORUN_GIDERME hata 10.

## T7. Uyku (15 dakika bekleme)
- A'da `araclar\kontrol.ps1` çıktısında `uyku=kapali` olmalı (uyku boşta zaman aşımı "Hiçbir zaman"; Microsoft: "0 (Never idle to sleep)", KAYNAKLAR.md). Değilse önce Ayarlar > Güç'ten "Hiçbir zaman" yap ve kontrolü tekrarla.
- A'ya hiç dokunmadan **15 dakika bekle** (ekran kararsa sorun değil), sonra B'den bağlan.
- Beklenen: bağlanır. Uyuyorsa ya da bağlanamazsa: `DURUM.md`'ye "kontrol.ps1 uyku=kapali iken 15 dk sonra uyudu/uyumadı" yaz (kontrolün yanlış okuma ihtimali); SORUN_GIDERME hata 10.
- Not: ekranın kapanması (ayrı ayar) ile bilgisayarın uykuya geçmesi farklıdır; yalnız ikincisi bağlantıyı keser.

## T8. Güvenlik tarafı
- Tailscale hesabında 2 aşamalı doğrulama açık mı, Tailscale yönetim sayfasında yalnız senin cihazların mı görünüyor: kendi gözünle bak (ajan yapamaz).
- RustDesk/Uzak Masaüstü'nde parola uzun ve benzersiz mi.
- SORUN_GIDERME hata 11, 12.

## T9. Zamanlı geri alma (güvenlik ağı): ilk güvenli deneme
Bu deneme kilidi uygulamaz; yalnız geri alma düzeneğinin çalıştığını sınar. **A'nın başında ol** (uzaktan yapma). Yönetici PowerShell gerekir.
1. `araclar\geri_al_zamanlayici.ps1 -DryRun`: ne yapacağını yazar, hiçbir şey yapmaz. Çıktıyı oku.
2. `araclar\geri_al_zamanlayici.ps1 -Dakika 2 -Uygula`: duvar ayarlarını yedekler ve 2 dakika sonra geri yükleyecek gizli bir zamanlanmış görev kurar. Beklenen: yedek ve günlük `%ProgramData%\dogrudan-uzak-masaustu` klasöründe.
3. 3 dakika bekle. Beklenen: `%ProgramData%\dogrudan-uzak-masaustu\geri_al.log` dosyasında geri yükleme satırı var, zamanlanmış görev (`DogrudanUzakMasaustu-GeriAl`) kendini silmiş, duvar eski haline dönmüş.
4. İstersen görevi daha dolmadan `-Iptal` ile kaldır ve görevin gitmesini bekle.
- Başarısızsa: SORUN_GIDERME hata 3 (ağ ayarına dokunmadan önce geri alma); sonucu `DURUM.md`'ye yaz.

## T11. Kritik kontroller: Pro RDP kilidi ve araçlar (denenmedi)
Bunlar gerçek duvarda çalıştırılmadı (yönetici yetkisi ve duvar değişikliği gerekir). Yalnız dal Pro'da, **T9 geçtikten sonra** ve A'nın başındayken. Her birinin çıktısını `DURUM.md`'ye yaz.
1. **3389 kural bulma:** `Get-NetFirewallPortFilter | Where-Object LocalPort -contains '3389' | Get-NetFirewallRule`: A'daki yerleşik Uzak Masaüstü kurallarını listelemeli (Türkçe Windows'ta kural adları farklı olabilir; betik ada değil port filtresine bakar). Boş çıkarsa not et.
2. **Tailscale'e kilit gerçekten çalışıyor mu:** REHBER 3a-3'te kilidi zaten uyguladıysan `-Uygula`'yı **yeniden çalıştırma**; yalnız gözlemi tekrarla: B'den (Tailscale üzerinden) bağlanmak **kabul edilmeli**; B ev ağındayken A'nın yerel IP'siyle bağlanmak **engellenmeli**. İkisini de yaz. Kilidi henüz uygulamadıysan: `araclar\rdp_tailscale_kilit.ps1 -Dakika 10 -DryRun`, sonra `-Uygula`; bağlantı koparsa 10 dakikalık geri alma devreye girer, bekle.
3. **Geri alma görevi gizli ve SYSTEM olarak çalışıyor mu:** T9'un 3. adımındaki sonuç (pencere açılmadan görev çalıştı mı, `geri_al.log` satırı, görev kendini sildi mi).
4. **Tailscale arayüz adı:** A'da `Get-NetAdapter | Where-Object Name -like '*Tailscale*'`. Beklenen ad `Tailscale`. Farklıysa betiği `-ArayuzAdi '<gördüğün ad>'` ile çalıştır ve adı `DURUM.md`'ye yaz.
5. **UDP 3389:** kilit yalnız TCP 3389 kuralını yazıyor. Uzak Masaüstü bağlantısı yine de kuruluyor mu? Belgeden doğrulanmadı (tahmin); kurulamazsa not et.
6. **Geri alma denemesi (isteğe bağlı, **en sonda**, A'nın başındayken):** `araclar\rdp_tailscale_kilit.ps1 -Geri` (önce `-DryRun`, sonra `-Geri -Uygula`) kilidi kaldırır ve eski 3389 kurallarını yeniden açar; eski kuralların döndüğünü kontrol et. **Hemen ardından kilidi yeniden uygula** (REHBER 3a-3: `-Dakika 15 -Uygula`), 3a-4'teki iki gözlemi tekrarla ve "kalsın" de. `DURUM.md`'ye "kilit yeniden uygulandı" yaz. **Kilit kalıcı olarak yerinde değilse T11 bitmiş sayılmaz.** Bu denemeyi atlayabilirsin; atlarsan sonuç tablosuna "denenmedi" yaz.
7. **`quser` (yalnız gözlem; `kim_bagli` betiği ertelendi):** A'da (Pro) `quser` komutunu çalıştır. Beklenen: oturum açık kullanıcıları listeler. Çalışmazsa ya da "yok" derse (Home'da bulunmadığı bildirildi) çıktıyı `DURUM.md`'ye yaz. Uzaktan bağlıyken (B'den RDP açıkken) ayrıca çalıştırıp bağlı oturumun görünüp görünmediğine bak ve not et. Bu bir sınama değil gözlemdir; sonuç ileride bir "kim bağlı" aracına karar vermek içindir.

## T12. Kritik kontroller: kontrol ve kanıt betikleri (denenmedi)
Her iki bilgisayarda; bu betikler değişiklik yapmaz (yalnız okur). Hata çıkarsa çıktıyı `DURUM.md`'ye yaz.
1. **Hizmet adları:** `araclar\kontrol.ps1` Tailscale ve RustDesk'i hizmet adıyla (`Tailscale`, `RustDesk`) arar. Kuruluyken "YOK" derse `Get-Service | Where-Object Name -match 'tailscale|rustdesk'` ile gerçek adı bul ve yaz (yanlışsa tehlikeli değil, yalnız yanlış rapor).
2. **`tailscale status` satır düzeni:** `araclar\baglanti_kanit.ps1` doğrudan/röle ayrımını bu çıktıdan okur. Belge tür sözcüklerini (direct/relay) veriyor, satır düzenini vermiyor. Betiğin hükmünü kendi gözünle `tailscale status` çıktısıyla karşılaştır; uyuşmazsa ikisini de yaz.
3. **`tailscale netcheck` düzeni:** çıktı satırları "Alan: değer" biçiminde bekleniyor; farklıysa çıktıyı yaz.
4. **Uyku ayarı:** `powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE` çıktısı. (Bir Windows 10 Home Türkçe makinede çalıştı; kendi makinende de çalışmalı. Çalışmazsa Denetim Masası > Güç Seçenekleri'nden elle bak.)
5. **Home/Pro eşlemesi:** `kontrol.ps1` Windows sürümünü kayıt defterindeki `EditionID` değerinden okur (belge değil, gözlem). `winver` ile aynı sonucu verdiğini doğrula; farklıysa yaz.
6. **`tailscale` komutunun yolu:** `Get-Command tailscale` komutu bulamazsa `Test-Path 'C:\Program Files\Tailscale\tailscale.exe'` dene; betikler bu yolu da dener (yol belgeden alınmadı, gözleme dayanır). Sonucu `DURUM.md`'ye yaz.
7. **Dört Windows servisi (kontrol.ps1 B3):** her iki bilgisayarda `araclar\kontrol.ps1` çıktısında Tailscale'in ön koşulu olan servislerin durumunu söyleyen satır(lar)ı bul (hangi servisler olduğu KAYNAKLAR.md'de; burada adları tekrar etmiyorum, çünkü kaynak teyidi sürüyor). Beklenen: servisler çalışıyorsa tamam, durmuş biri varsa **uyarı verir ama hiçbir şeyi düzeltmez**. Gerçek makinede bir servisi durdurma; yalnız mevcut durumu `services.msc` ile karşılaştır ve uyuşmazsa çıktıyı `DURUM.md`'ye yaz.


## T13. Kritik kontrol: kural dosyaları (AGENTS.md / CLAUDE.md) gerçekten yükleniyor mu? (denenmedi)
Kök klasördeki `AGENTS.md` ve `CLAUDE.md` (içinde yalnız `@AGENTS.md`) ajanın kuralları kendiliğinden yüklemesi için var. Belge Claude Code için bunu söylüyor; Codex ve Cursor kök `AGENTS.md`'yi okuyor ama `@` içe almayı belgelemiyor. Hiçbiri bu depoda denenmedi.
1. **Claude Code:** depoyu ZIP'ten bir klasöre aç (ör. `C:\uzak`), ajanı o klasörde aç, **hiçbir şey yapıştırmadan** sor: "Bu klasörde hangi kural dosyalarını yükledin? `AGENTS.md`'deki ilk kuralı olduğu gibi söyle." Beklenen: dosya adlarını sayar ve ilk kuralı doğru alıntılar. Sormadan kutuyu yapıştırma; ajan bilmiyorsa sonucu `DURUM.md`'ye "yüklenmedi" diye yaz.
2. **Codex (Git'siz ZIP klasörü):** aynı klasörde (içinde `.git` yok) Codex'i aç ve aynı soruyu sor. Belgede "Starting at the project root (typically the Git root)" yazıyor; Git'siz klasörde yüklenip yüklenmediği belgede **yok**. Yüklenmezse `DURUM.md`'ye yaz; README'deki yedek (kutuyu yapıştır) bu durum içindir.
3. **(İstersen) Cursor ya da başka ajan:** aynı soru; sonucu `DURUM.md`'ye yaz.
4. **İki dosya birlikte:** Claude Code'da `CLAUDE.md` içindeki `@AGENTS.md` yüzünden kuralların **bir kez** (iki kez değil) yüklendiğini ajana "kurallarını say" diyerek gör; iki kez görünüyorsa not et.
5. **Kural gerçekten uygulanıyor mu?** Ajana "tailscale up --force-reauth çalıştır" de. Beklenen: reddeder (uzaktan çalıştırılmaz, kırmızı sınıf) ve neden söyler. Kural bağlam olduğundan (belge: "context, not enforced configuration") uygulanmazsa bunu not et; gerçek güvence betiklerdeki `-DryRun` varsayılanıdır.
- Başarısızsa: SORUN_GIDERME hata 15 (her şeyi tek seferde / kural kaybı).

## T14. Kritik kontrol: Tailscale anahtar süresi seçimi (B1)
Süreyi kapatmak bir güvenlik ödünüdür; kullanıcı seçer.
1. Tailscale yönetim sayfasında (tarayıcı, **sen** aç; ajan hesap sayfasında işlem yapmaz) A cihazının anahtar süresi durumunu bul.
2. İki seçenekten birini seç ve `DURUM.md`'ye yaz: (a) A için anahtar süresini **kapat** (kapattığını ve nedenini yaz); (b) kapatma, belgedeki süre dolmadan **takvim hatırlatması** kur (süre ve tarih KAYNAKLAR.md'deki Tailscale anahtar süresi kaydından; hatırlatma tarihini `DURUM.md`'ye yaz).
3. Beklenen: `DURUM.md`'de "Anahtar süresi: kapatıldı / hatırlatma <tarih>" satırı var. Seçilmediyse Adım 1 "bitti" sayılmaz.
4. Ajanın uzaktan `tailscale up --force-reauth` çalıştırmadığını T13-5 ile doğrula.
- Not: konsol sayfasında seçeneğin adı yayın gününde değişmiş olabilir; farklıysa görünen adı `DURUM.md`'ye yaz.

## T10. Sonuç tablosu (DURUM.md'ye yaz; sorun varsa issue aç)
| Adım | Geçti / kaldı | Not (komut çıktısı, hata metni) |
|---|---|---|
| T1 farklı ağ | geçti (deneme 1) | ev hattı ve telefon mobil verisi (Wi-Fi kapalı) |
| T2 görüyor | geçti (deneme 1) | `tailscale status` iki cihazı listeledi |
| T3 doğrudan / röle | geçti: DOĞRUDAN (deneme 1) | kanıt betiği ilk ölçüm 309 ms (yol kurulurken); sonraki 5 ping: 457, 43, 40, 37, 34 ms (mobil veri) |
| T4 dışarıdan kapalı | denenmedi | genel IP'ye Test-NetConnection yapılmadı |
| T5a Pro RDP | denenmedi | deneme 1'in bilgisayarı Home |
| T5b-1 IP biçimi (önce yalnız IP; olmazsa IP:21118) | geçti (deneme 1) | yalnız IP yeterli, parola ekranı geldi; `:21118` denenmedi |
| T5b-2 port protokolü (TCP/UDP) | geçti: TCP (deneme 1) | `TCP [::]:21118 LISTENING` |
| T5b-3 hotspot'tan Tailscale IP ile | geçti (deneme 1) | telefon mobil veriyle bağlandı, `active; direct`; iki kez (parolayla ve kalıcı parolayla) |
| T5b-4 reboot sonrası kilit ekranı | denenmedi | |
| T5b-5 beyaz liste dışı reddedildi mi | denenmedi | |
| T5b-6 onay kipi "Her ikisi" | kısmen (deneme 1) | parolasız istek: A'da "Kabul Et / İptal" penceresi açıldı; kalıcı parolayla bağlandı; kalıcı parolayla tıklamasız girildi, A'daki pencere birkaç saniyede kendini gizledi (kullanıcı gözlemi); kimse tıklamayınca düşme: denenmedi |
| T5b-7 9 haneli ID yolu beyaz listeden geçiyor mu | denenmedi | |
| T5b-8 telefonda "Parolayı hatırla" ile ikinci bağlanış | geçti (deneme 1) | parola sormadan bağlandı |
| T5b-9 telefon klavyesi ve parola | kayıtta görüldü (deneme 1) | ilk kalıcı parola telefonda kabul edilmedi; yalnız İngilizce harf ve rakamla olunca kabul edildi (neden doğrulanmadı) |
| T5b-10 kafe önlemi (duvar engeli) kuruluyken bağlanma | geçti (deneme 1) | telefon engel kuralları kuruluyken bağlandı |
| T5b-11 `araclar\rustdesk_tailscale_kilit.ps1` gerçek makinede | kısmen (deneme 1) | aynı adres aralıklarıyla (IPv6 `::2-` dahil) deneme sürümü yönetici olarak, hata durdurması açıkken 2 kuralı kurdu; depodaki son sürüm gerçek makinede denenmedi |
| T6 kilit / UAC / reboot | denenmedi | |
| T7 uyku (kontrol.ps1 uyku=kapali, 15 dk bekleme) | denenmedi | ön kontrolde uyku kapalı görüldü; 15 dk bekleme yapılmadı |
| T8 güvenlik | denenmedi | |
| T9 geri alma (-Dakika 2) | denenmedi | deneme 1'de 20 dk'lık geri alma görevi kuruldu ve iş bitince iptal edildi; zamanında kendiliğinden çalışması ölçülmedi |
| T11 Pro kilidi + quser gözlemi (7 kontrol); kilit sonda yerinde mi | denenmedi | quser çıktısı; -Geri denendiyse kilit yeniden uygulandı mı: |
| T12 kontrol/kanıt betikleri (7 kontrol, 4 servis dahil) | kısmen (deneme 1) | kontrol.ps1 bilgisayar A'da çalıştı (Home, uyku kapalı, servisler tamam); kanıt betiği iki ağda "DOĞRUDAN" hükmü verdi; 7 kontrolün tamamı denenmedi |
| T13 AGENTS.md/CLAUDE.md yükleniyor mu (Claude Code / Codex ZIP) | kısmen | Claude Code (geçici kopya klasörde, yalnız okuma kipi): kuralları kendiliğinden uyguladı (önce DURUM.md, sonra Adım 0'ın üç sorusu, hiçbir şey değiştirmedi); ilk cümle "Kuralları okudum" yazılmadı. İlk denemede şablondaki örnek DURUM satırını gerçek sandı; satır kaldırıldı, ikinci deneme temiz. Codex: bu makinedeki model ayarı hata verdi, denenmedi. Cursor: denenmedi |
| T14 anahtar süresi seçimi | denenmedi | kapattı / hatırlatma tarihi: |

Eksik tahmin: T3'te gecikme, "5 ms"yi **yerel ağda** ölçtük diye internetten bekleme; yol uzunluğuna bağlıdır (SORUN_GIDERME yanlış 3). Hissedilen gecikmeyi ayrıca not et: ekranda fareyi oynat, görüntünün ne kadar sonra geldiğini say.
