# DURUM.md

Bu dosya ajanının hafızasıdır. Ajan her adım bitince bir satır ekler; her oturumun başında önce bunu okur.
Sır (parola, anahtar, kimlik kodu) buraya yazılmaz.

Durum değerleri: `bitti` · `yarım` · `takıldı`.
Satır biçimi örneği (gerçek kayıt değil): `| 2026-01-31 14:05 | 0 Ön kontrol | bitti | kontrol.ps1: <özet> | yok (yalnız okudu) | 1 Tailscale kur |`
"Kanıt" sütununa çalıştırılan komut ve çıktının tek satırlık özeti yazılır; kanıt yoksa durum `bitti` olamaz.

| Saat (komutla ölçülür) | Adım | Durum | Kanıt (komut: sonuç) | Geri alma | Sıradaki |
|---|---|---|---|---|---|

## Açık sorular / bana sorulacaklar
-

## Son güvenli nokta
Bağlantının çalıştığı en son bilinen durum (hangi yol, hangi adres türü, ne zaman):
-
