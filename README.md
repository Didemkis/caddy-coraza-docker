# Caddy + Coraza WAF (OWASP CRS) — Docker Kurulum Rehberi

Bu repo, Caddy web sunucusunun OWASP Coraza WAF (Core Rule Set ile) entegre biçimde 
Docker üzerinde çalıştırılması için hazırlanmıştır. Rehber; kurulum, yapılandırma, rate-limit, 
HTTP/2 upstream, güvenlik loglama ve performans iyileştirmelerini içermektedir.

## Kurulum


### Mimari ve Dizin Yapısı
<details>

.
├─ etc/
│  └─ Caddyfile
├─ Dockerfile
├─ docker-compose.yml
└─ README.md
</details> 

## Gerekli dizinleri oluştur
```
mkdir -p ./etc/caddy ./var/log/caddy ./assets ./certs
```

İsteğe bağlı (test ortamı için self-signed TLS sertifikası üretmek istersen)::

```
openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes \
  -keyout ./certs/key.pem -out ./certs/crt.pem \
  -subj "/CN=localhost"
```

Build / Run
```
docker compose build
docker compose up -d
```

Kullanım Örnekleri
Container Durumu Kontrolü
```
docker compose ps
docker exec -it caddy-coraza caddy version
```
HTTPS Testi
```
curl -kI https://localhost/
curl -kI https://localhost/index.html
```
WAF Testi (SQLi Denemesi)
```
curl -k "https://localhost/?q=' OR 1=1--"
```

Rate-Limit (Örnek)
(Sunucuya kısa sürede aşırı istek gönderme testi)
```
# 20 saniyede 1123 adetten fazla /api/* isteğinde 403 beklenir
ab -n 1500 -c 200 https://localhost/api/ping
```
Logları İzleme
```
tail -f var/log/caddy/access.log
tail -f var/log/caddy/coraza-audit.log
```
## Güvenlik ve Performans Notları

WAF kipleri:

DetectOnly: Sadece raporlar. İlk devreye alımda önerilir.

On: Engelleme başlar. Eşikler/false-positive tuning sonrası açın.

Paranoia Seviyesi: tx.paranoia_level=1 konservatif. 2-3-4 seviyeleri kural hassasiyetini artırır; uygulama uyumluluğu test edilmelidir.

Header/Query Regexleri: Örnek kısıtlar (metakarakter ve uzunluk) false positive riskine göre daraltılmalı/genişletilmelidir.

HTTP/2 Upstream: transport http { versions 2 } çoğu modern reverse target’ta çalışır. Hedef servis HTTP/2 desteklemiyorsa 1.x’e düşürün.

Önbellek (cache-handler): Statik içerikte default_ttl 1h ve Cache-Control ile bant genişliği ve TTFB düşer.

Log Formatı: JSON; SIEM’e (Wazuh/Splunk/ELK) kolay entegrasyon sağlar.

Hata Gizleme: handle_errors ile 500 → 403 sadeleştirildi; ayrıntı sızıntısı önlenir.

Sertifika Yönetimi: Testte dosya sertifikaları; prod’da ACME ya da kurum içi CA ve otomatik yenileme tercih edin.

İzolasyon: Sadece gerekli portları açın; container kullanıcı/icaplarına göre ek kısıtlama (read-only fs, no-new-privileges) düşünebilirsiniz.

## Sorun Giderme

CRS kuralları hiç tetiklenmiyor: order coraza_waf first yoksa en başa alın. DetectOnly’de 403 beklemeyin, audit log’a bakın.

Statik içerik 404: assets/ host klasörünüzde index.html var mı, root * /app/assets doğru mu?

Upstream 502/504: Hedef servis adresi/portu doğru mu? HTTP/2 desteklemiyorsa versions 1.1 deneyin.

Sertifika Hatası: Testte curl -k kullanın; tarayıcı için self-signed sertifikayı güvenilir köke ekleyin ya da geçerli sertifika kullanın.

## SSS

“Engellemeyi ne zaman açayım?”
En az 1-2 hafta DetectOnly loglarını inceleyip false positive’leri (whitelist/kural ayarı) temizledikten sonra.

“Rate-limit IP yerine kullanıcı bazlı olabilir mi?”
key alanında "{remote_host}" yerine "{header.X-User-Id}" gibi kimliğe dayalı anahtarlar kullanılabilir (uygulama mimarisine bağlı).

“WAF logları nereye gidiyor?”
Container içinde /var/log/caddy/coraza-audit.log (hostta ./var/log/caddy/…). SIEM ajanıyla toplayın.

## Resmî Dokümantasyon

Caddy Docs: https://caddyserver.com/docs/
Bu rehber ile Caddy, OWASP Coraza WAF (CRS) ile birlikte Docker üzerinde çalışır duruma gelir; 80/443 üzerinden erişilebilir, WAF audit ve erişim logları hosta yazılır, /api/* istekleri hız sınırlaması ve HTTP/2 upstream ile proxy’lenir, statik varlıklar önbellekten servis edilir.
