# Bağlantı kartı

Kurulum bitince ajan bu kartı doldurur (`<...>` yerlerini). Kontrol eden bilgisayarda (B) bağlanırken buna bakarsın.
**Bu karta parola, anahtar, giriş kodu ya da hesap bilgisi YAZILMAZ.** Kartta yalnız adres ve adımlar var; yine de başkasıyla paylaşma.

| | |
|---|---|
| Hedef bilgisayar (A) adı | `<tailscale status'taki ad>` |
| A'nın Tailscale adresi | `<100.x.y.z>` (`tailscale ip -4` ile) |
| Yol | `<Pro: Uzak Masaüstü / Home: RustDesk>` |
| Son kanıt | `<baglanti_kanit sonucu: DOGRUDAN / ROLE>`, `<tarih>` |
| Anahtar süresi | `<kapatıldı / hatırlatma tarihi: GG.AA.YYYY>` |

## B'de bağlanmak (5 adım)
1. B'de Tailscale açık mı bak: saatin yanındaki simge. Kapalıysa aç, aynı hesapla girili olsun.
2. `<Pro: Başlat'a "mstsc" yaz, Uzak Masaüstü Bağlantısı'nı aç / Home: RustDesk'i aç>`.
3. Bağlanma kutusuna `<100.x.y.z>` yaz (RustDesk'te kimlik numarası değil, bu adres).
4. Parolayı sen gir (`<Pro: A'daki Windows hesabının parolası / Home: RustDesk kalıcı parolası>`).
5. Olmazsa: A açık ve uyanık mı? İki bilgisayar da `tailscale status` listesinde mi? Sonra `SORUN_GIDERME.md`.

## Doldurulma kaydı
- Dolduran: ajan, `<tarih saat>` (komutla ölçüldü). Kaynak: `DURUM.md` son satırları.
