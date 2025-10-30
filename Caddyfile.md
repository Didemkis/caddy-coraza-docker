Caddyfile

{
    order coraza_waf first   // WAF işlemi tüm diğer işlemlerden önce çalışsın
}

:443 {   # Sunucu 443 (HTTPS) portunu dinler
    tls /app/certs/crt.pem /app/certs/key.pem   # TLS sertifikası ve private key (test ortamı için)

    coraza_waf {  # Coraza WAF aktif ediliyor
        directives `
            SecRuleEngine DetectOnly              # Saldırıları sadece izle, engelleme (test aşamasında)
            Include /app/coreruleset/crs-setup.conf  # CRS ana yapılandırma dosyasını yükler
            Include /app/coreruleset/rules/*.conf    # Tüm CRS kural dosyalarını yükler

            SecRequestBodyLimit 13107200       # HTTP body boyut limiti (12.5MB)
            SecRequestBodyNoFilesLimit 131072  # Dosyasız body için boyut limiti
            SecRequestBodyLimitAction Reject   # Limit aşılırsa istek reddedilir
            SecRequestBodyAccess On            # Request body analizini etkinleştir

            SecResponseBodyAccess On           # Response body analizini etkinleştir
            SecResponseBodyLimit 524288        # Response inceleme limiti (512KB)
            SecResponseBodyLimitAction ProcessPartial # Limit aşılırsa kısmî analiz yap

            SecAuditLog /var/log/caddy/coraza-audit.log   # WAF audit log dosyası
            SecAuditLogParts ABCFHKZ       # Loglanacak bölümler (detay seviyesini belirler)
            SecAuditLogType Serial         # Log kayıtlarını satır satır yaz
            SecAuditLogFormat JSON         # SIEM uyumlu JSON formatında logla

            SecAction "id:900110,phase:1,nolog,pass,t:none,setvar:tx.inbound_anomaly_score_threshold=5,setvar:tx.outbound_anomaly_score_threshold=4"
            # inbound (gelen) ve outbound (giden) anomaly skor eşikleri

            SecAction "id:900000,phase:1,nolog,pass,t:none,setvar:tx.paranoia_level=1"
            # WAF hassasiyet seviyesi (1 temel, 4 agresif güvenlik modu)

            SecRule REQUEST_HEADERS "!@rx ^[a-zA-Z0-9_\\-\"=+;().,*:?/\\s]{1,150}$" \
                   "deny,id:47,log,status:403,msg:'Headers: hatalı değer'"
            # Header içeriğini whitelist mantığıyla filtreler (XSS, Command Inj vb. ham inputları kısıtlar)

            SecRule ARGS_GET "!@rx ^[a-zA-Z0-9\\-_]{1,80}$" \
                   "id:5002,phase:1,deny,status:403,msg:'QueryString: hatalı değer'"
            # URL query parametrelerinde zararlı karakter kullanımını engeller
        `
    }

    @api {              # Değişken tanımı: sadece /api/* GET ve HTTP/2 isteklerde çalışsın
        protocol http/2  # HTTP/2 zorunlu
        method GET       # Yalnızca GET istekleri
        path /api/*      # Bu path için geçerli
    }
    handle @api {       # Şartlar sağlandıysa bu blok çalışır
        rate_limit {    # Rate limit kontrolü (DDoS & Bot Pressure kırmak için)
            zone apply_zone {
                key {remote_host}   # IP bazlı limit
                events 1123         # 1123 istek
                window 20s          # 20 saniyede
            }
        }
        reverse_proxy 192.168.1.2:5353 {  # API backend adresi
            transport http {
                versions 2          # Upstream backend ile de HTTP/2 kullanılacak
            }
        }
    }

    @assets {           # Statik dosya servis işlemi için koşullar
        protocol http/2
        method GET
        path /
        path /index.html
        query ""        # Query string yoksa
    }
    handle @assets {
        rate_limit {    # Statik dosyalara da brute/burst engeli
            zone asset_zone {
                key {remote_host}
                events 15
                window 10s
            }
        }
        root * /app/assets   # Statik dosyaların fiziksel dizini

        route {              # Caching pipeline
            cache {          # Cache handler aktif
                default_ttl 1h                # Varsayılan cache süresi 1 saat
                cache_key "{host}{path}{query}"  # Her endpoint için cache anahtarı
            }
            file_server                          # Dosyaları serve et
            header {
                Cache-Control "public, max-age=31536000"   # Browser cache için 1 yıl
            }
        }
    }

    handle_errors {     # Genel hata yönetimi
        @block expression {http.error.status_code} == 500   # Sunucu hatası tespit edildiğinde
        handle @block {
            respond "" 403   # 500 yerine sade ve bilgi vermeyen 403 dön
        }
    }

    handle {
        respond "" 403  # Yukarıdaki kurallara uymayan tüm istekler otomatik engellenir
    }

    log {   # Erişim logları
        format json                          # JSON log formatı (SIEM uyumlu)
        output file /var/log/caddy/access.log {   # Log dosya yolu
            roll_size 10MiB                  # Log rotasyon sınırı
            roll_keep 5                      # 5 adet eski log sakla
            roll_keep_for 48h                # Logları max 48 saat sakla
        }
    }
}
