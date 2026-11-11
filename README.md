# ozel-uzak-masaustu

**Tailscale + RustDesk ile port açmadan, kendi cihazların arasında özel uzak masaüstü. Yapay zekâ ajanınla adım adım kurulum rehberi (Türkçe).**

İki Windows bilgisayarı **modemde port açmadan**, sabit IP olmadan, güvenle uzaktan kullanmak için adım adım rehber ve küçük yardımcı betikler.
Yazılımcı olmayanlar için yazıldı: rehberi kendi yapay zekâ ajanına (Claude Code, Cursor, Codex vb.) verirsin, ajan adım adım, senin onayınla uygular.

**Yöntem:** Tailscale (iki cihazı özel ağda buluşturur, mümkünse doğrudan yol açar, olmazsa şifreli röleden geçer) + üstüne uzak masaüstü:
Windows **Pro**'da yerleşik Uzak Masaüstü (yalnız Tailscale'den erişilebilir), Windows **Home**'da RustDesk (Tailscale adresine doğrudan bağlanarak).
Yeni ya da gizli bir yöntem değil: yıllardır belgeli "NAT delme" (*UDP hole punching*: modemlerin arkasındaki iki cihaz arasında doğrudan yol açma) tekniğinin, yaygın ve bakımlı hazır araçlarla güvenli kullanımı.

## Neden bu yol?

Ücretsiz uzak masaüstü araçları (ör. AnyDesk, TeamViewer) işini görür; burada farklı bir yol seçmemizin nedenlerini, yalnız kaynağı olan ya da bizzat ölçtüğümüz satırlarla yazdık. Karşı tarafın sayfasından alıntı alamadığımız yerde karşılaştırma yapmadık, "alıntı alınamadı" yazdık. Kimseyi kötülemek amaç değil; ürün adları sahiplerinindir.

| Konu | Bu yol (Tailscale + RustDesk/Uzak Masaüstü) | Ücretsiz sürümlü araçlar |
|---|---|---|
| Ticari kullanım | Tailscale kişisel planı da ticari olmayan kullanım içindir: "only suitable for non-commercial use of Tailscale" (KAYNAKLAR K4). Yani kısıt burada da var, kurmadan önce plan koşulunu oku. | TeamViewer: "We define commercial use as being any use of TeamViewer for purposes that are either directly or indirectly paid for." ve yanlışlıkla kısıtlanan cihaz için "will unblock your device ... if it has been limited by mistake" (K57). AnyDesk: resmî sayfası açılamadı, alıntı alınamadı. |
| Bağlantı nereden geçer | Önce doğrudan UDP; olmazsa şifreli röle: "Devices send packets directly to each other using UDP." ve "The primary difference between them is performance, not security." (K58). Ölçtük (deneme 1): iPhone (LTE) ile bilgisayar arası **doğrudan** yol. | Alıntı alınamadı, karşılaştırma yapılmadı. |
| Trafiği kim okuyabilir | Tailscale: "Tailscale cannot read your traffic." (K59). RustDesk'in doğrudan IP bağlantısı kendi başına şifresiz işaretlenir (kırmızı kalkan, deneme 1); bu rehber o bağlantıyı Tailscale tüneli içinden yaptığı için trafik tünelle şifrelenir. | Alıntı alınamadı. |
| Kim ulaşabilir | Tailscale: "only devices on your private network can communicate with each other" (K59). RustDesk'te ek olarak IP beyaz listesi ve parola var. **Dikkat:** RustDesk'in 9 haneli ID yolunun beyaz listeden geçip geçmediği denenmedi; orada koruma paroladır. | Erişim kodu/parola ile bağlanılır; AnyDesk'in kendi uyarısı: "Never share access codes to your devices with anyone." (K39). |
| Kötüye kullanım | Her uzak erişim aracı, kodu bilen kişiye bilgisayarı açar; bu yol da dahil. AnyDesk'in sayfası sahte "teknik destek" dolandırıcılığını anlatıyor: "Scammers pose as Microsoft technicians, claiming they need to clean your device of malicious software." (K39). Bu yüzden rehber, ajan adım atmadan önce "bunu kendin mi istiyorsun, biri mi yönlendirdi?" diye sorar (REHBER Adım 0) ve ajan senden parola/kod istemez. | Aynı risk geçerli; araca özgü bir rakam vermiyoruz. |
| Kod açıklığı | RustDesk: GNU Affero GPL v3 (K60). Tailscale istemcisi: "the majority of Tailscale's open source code", lisans BSD 3-Clause (K61); WireGuard "open source" (K59). Açık kod, kendiliğinden "güvenli" demek değildir; yalnız denetlenebilir demektir. | Alıntı alınamadı, bir şey iddia etmiyoruz. |
| Hız | Yavaş değil: ölçtük (deneme 1), iPhone (LTE) ile bilgisayar arası doğrudan yolda çoğunlukla 34-75 ms, mobil ağda ara sıra tek sıçrama (ör. 288 ms). Röle yoluna düşersen biraz yavaşlayabilir (K58). **AnyDesk ve TeamViewer ile karşılaştırılmadı.** | Karşılaştırılmadı. |

Özet: bu yolun üstünlüğü "daha hızlı" ya da "daha güvenli" iddiası değil; modemde port açmaman, parçaların açık lisanslı olması ve her adımın kanıtlı ve geri alınabilir olması. Tailscale'in ticari olmayan kullanım koşulu ve RustDesk'in ID yolu gibi sınırlar yukarıda açıkça yazılıdır.

## Gerekenler
İki Windows 10/11 bilgisayar (ya da biri telefon), ücretsiz bir Tailscale hesabı (ticari olmayan kullanım), bir yapay zekâ ajanı (Claude Code, Codex ya da Cursor; yoksa birini kendi resmî sitesinden kur, bu rehber ajan kurulumunu anlatmaz). Kurulum ajanla, senin onayınla adım adım yapılır; sonunda başka bir ağdan A'nın masaüstünü görürsün.

**Adlar:** **A** = uzaktan bağlanılacak bilgisayar (ajanı burada açarsın, genelde evdeki). **B** = bağlanan bilgisayar ya da telefon. Windows Home mu Pro mu, yalnız A için önemli; Adım 0 bunu sana kendisi söyler.

## Nasıl başlarım
1. Bu depoyu indir (Code > Download ZIP) ve kısa bir klasöre aç (ör. `C:\uzak`). Klasörün içinde `AGENTS.md` ve `REHBER.md` görmelisin; görmüyorsan bir alt klasöre gir (ZIP çoğu zaman iç içe klasör çıkarır).
2. Ajanını **A'da**, o klasörde aç. Claude Code kuralları (`AGENTS.md`) kendiliğinden yükledi (denendi); Codex ve Cursor da `AGENTS.md`'yi okur (belgelerine göre, burada denenmedi). Ajan kurallara uymuyor gibiyse ona şunu yaz: "AGENTS.md dosyasını oku, kurallarını kabul et, REHBER.md Adım 0'dan başla."
3. Ajan Adım 0'dan başlar; her adımda ne yaptığını `DURUM.md`'ye yazar, kanıt gösterir. Yalnız okuyan işleri sormadan yapar; değiştiren her işte senin onayını bekler.

## Dosyalar
| Dosya | Ne işe yarar |
|---|---|
| `AGENTS.md` | Ajanın kuralları (onay sınıfları, doğru kaynağa bakma, bağlantıyı koparmama). `CLAUDE.md` yalnız bunu Claude Code'a yükletir |
| `REHBER.md` | Ana rehber: Adım 0-6 + ekler. Her adım: Yap / Kanıt / Geri al / DURUM satırı |
| `KOPRU.md` | İki bilgisayarın ajanı arası mesaj ve dosya köprüsü: nasıl çalışır, komutlar, ayarlar, güvenlik, sınırlar |
| `araclar\kopru_*.ps1` | Köprü betikleri (keşif, gönder, bekçi, durum, servis). Yalnız yerel köprü klasörüne yazar; `kopru_servis.ps1` istenirse Tailscale ve RustDesk'i kapatır/açar |
| `DURUM.md` | Ajanın defteri (şablon). Bağlantı ya da oturum koparsa ajan buradan devam eder |
| `TEST_PLANI.md` | Gerçek iki-ağ testi (ikinci cihaz telefon hotspot'unda) ve sonuç tablosu |
| `SORUN_GIDERME.md` | 15 sık hata, 7 doğru bilinen yanlış, RustDesk bilinen sorunlar, güvensiz "hızlı çözümler" ve güvenli karşılıkları, Türkiye notları |
| `BAGLANTI_KARTI.md` | Kurulum bitince ajanın doldurduğu kısa kart: öbür bilgisayardan nasıl bağlanırsın (parolasız) |
| `KAYNAKLAR.md` | Her iddianın resmî belgeden ham alıntısı ve adresi |
| `araclar\kontrol.ps1` | Ön kontrol: Windows Home/Pro, uyku, Tailscale/RustDesk kurulu mu, Tailscale'in istediği 4 Windows hizmeti, ağ durumu. **Yalnız okur** |
| `araclar\baglanti_kanit.ps1` | Bağlantı doğrudan mı röle mi, Türkçe hüküm; röleyse olası nedeni ve seçenekleri yazar. **Yalnız okur** |
| `araclar\geri_al_zamanlayici.ps1` | Güvenlik ağı: duvarı yedekler, N dakika sonra kendiliğinden geri yükleyen gizli görev kurar |
| `araclar\rustdesk_tailscale_kilit.ps1` | Home (RustDesk) umumi Wi-Fi'ye çıkacaksan: RustDesk portlarını (TCP 21118, UDP 21119) Tailscale dışından gelene kapatan duvar engeli; önce güvenlik ağını kurar, `-Geri` ile kaldırılır |
| `araclar\rdp_tailscale_kilit.ps1` | Pro: Uzak Masaüstü'nü yalnız Tailscale'e açar; önce güvenlik ağını kurar |
| `tests\` | Betiklerin testleri (gerçek ayara dokunmaz) |

Değişiklik yapan betikler varsayılan olarak yalnız **ne yapacağını yazar** (`-DryRun`); gerçekten yapmaları için `-Uygula` gerekir (tek istisna: geri alma görevini kaldıran `-Iptal`). Duvarı değiştiren üç betik (`geri_al_zamanlayici`, `rdp_tailscale_kilit`, `rustdesk_tailscale_kilit`) yönetici PowerShell ister (Başlat'a sağ tıkla, "Windows PowerShell (Yönetici)"); `kontrol` ve `baglanti_kanit` istemez; hiçbiri kendini yönetici yapmaz, pencere açmaz, bir şey indirmez. Hepsi şöyle çalıştırılır: `powershell -NoProfile -ExecutionPolicy Bypass -File araclar\<betik>.ps1`.

## Evde de, dışarıda da

Aynı adres (A'nın Tailscale adresi `100.x.y.z`) her yerde çalışır: evde aynı Wi-Fi'deyken Tailscale yolu ev ağının içinden kurar, dışarıdayken internet üzerinden. Ölçtüklerimiz:
- **Aynı ev Wi-Fi'sinde:** doğrudan yol 4-8 ms (ilk ping bir kez ~120 ms). Taildrop ile 100 MB ~9 sn, 1 GB 79-94 sn (~11-12 MB/s); 18/18 dosyada sha256 eşleşti. RustDesk, `100.x.y.z` adresiyle aynı ev ağında bağlandı; RustDesk dosya aktarımıyla 100 MB ~11-18 sn, sha256 eşleşti. RustDesk'te dosya aktarımı ikinci bir "Kabul Et" onayı ister.
- **Telefon hotspot'uyla (farklı ağ):** doğrudan yol 38-87 ms; 10 MB eve doğru 3,4 MB/s, telefona doğru 1,2 MB/s; 12/12 dosyada sha256 eşleşti.

Dosya aktarımı için RustDesk'in kendi dosya aktarımı ya da Tailscale'in Taildrop özelliği kullanılır. Ayrıntı: `REHBER.md` "Günlük kullanım".

## İki bilgisayarın ajanları konuşur (köprü)
İstersen iki bilgisayardaki ajanlar aynı Tailscale hesabı üzerinden (Taildrop ile) birbirine kısa mesaj ve dosya gönderir: durum sorar, ping yolunu ve dosya aktarımını sha256 ile kanıtlar. Mesaj **veri** sayılır; ajan kendiliğinden yalnız sabit bir ölçüm listesini yapar, gerisini sana sorar. Kendiliğinden uyanma yalnız Claude Code'da ve pencere açıkken çalışır; Codex/Cursor'da ajana "posta var mı bak" dersin. Köprüyü istediğin an "kapat / aç" diyerek kapatıp açabilirsin; Tailscale ve RustDesk'i de bilgisayarın başındayken kapatma seçeneği var (`KOPRU.md` "Aç / kapat"). Kendiliğinden hiçbir şey kapanmaz. Kurulum `REHBER.md` Adım 6; ne yaptığı, ayarlar, güvenlik ve sınırlar `KOPRU.md`.

## Testleri çalıştırmak (isteğe bağlı)
```powershell
Get-ChildItem tests\*.ps1 | ForEach-Object { powershell -NoProfile -ExecutionPolicy Bypass -File $_.FullName; "$($_.Name): $LASTEXITCODE" }
```
Çıkış kodu 0 = geçti. Testler Windows PowerShell 5.1'de yazıldı; gerçek güvenlik duvarına, göreve ya da ağa dokunmaz.

## Sınırlar (dürüst not)
- Rehber Windows 10/11 içindir. Telefondan bağlanma yalnız kısa bir ek.
- "Doğrudan bağlantı" her ağda kurulamaz (ör. iki taraf da zor NAT arkasındaysa); o zaman bağlantı röleden çalışır, biraz yavaştır. Hangisi olduğunu `baglanti_kanit.ps1` söyler.
- Belgede bulunamayan ayrıntılar (ör. RustDesk'te IP'nin hangi biçimde yazılacağı) rehberde "Sınanmadı → TEST_PLANI Tx" diye işaretlidir; ilk gerçek testte doğrulanır.
- Rehber bir gerçek denemede (Windows Home A, telefon B mobil veride, doğrudan yol, kafe önlemi kuruluyken) baştan sona çalıştı. Windows Pro/Uzak Masaüstü kolu, kilit ekranı, yeniden başlatma ve uyku adımları henüz sınanmadı; `TEST_PLANI.md` sonuç tablosunda "denenmedi" görünenler bunlardır.
- Betiklerin bilgisayarda kullandığı veri klasörü (`%ProgramData%\dogrudan-uzak-masaustu`) ve görev adı (`DogrudanUzakMasaustu-GeriAl`) projenin eski adını taşır; bilinçli, işlevi aynı.
- Tailscale ücretsiz kişisel planı ticari olmayan kullanım içindir; plan koşullarını kurmadan önce tailscale.com/pricing'den kontrol et.

## Lisans
MIT (`LICENSE`).
