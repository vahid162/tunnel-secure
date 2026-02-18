# tunnel-secure

این ریپو یک اسکریپت Wizard برای سخت‌سازی امنیت سرورهایی دارد که از `ssh-tunnel` یا `gre-4` (یا هر دو همزمان) استفاده می‌کنند، با تمرکز روی این‌که تونل شما قطع نشود.

## اسکریپت

- مسیر: `scripts/tunnel-security-wizard.sh`
- نوع اجرا: تعاملی (سوال‌محور)
- مناسب برای: Ubuntu/Debian (به‌خاطر `apt` و `ufw`)

## قابلیت‌ها

- تنظیم امن SSH با Drop-in استاندارد (`/etc/ssh/sshd_config.d/00-tunnel-secure.conf`) و اعتبارسنجی قبل از ری‌استارت
- فعال‌سازی `fail2ban` برای جلوگیری از Brute-force
- تنظیم `sysctl` سازگار با GRE (برای جلوگیری از اختلال rp_filter)
- پشتیبانی از حالت اجرای همزمان دو تونل (`ssh-tunnel` + `gre-4`)
- تنظیم `ufw` با درنظر گرفتن:
  - IP مدیریتی شما
  - پورت SSH
  - پورت‌های سرویس تونل SSH
  - پروتکل GRE و IP سمت مقابل
- در صورت نیاز، پشتیبانی از سناریوی Forwarding روی GRE:
  - فعال‌سازی `ip_forward`
  - تنظیم `DEFAULT_FORWARD_POLICY` در UFW
  - اضافه کردن route rule برای عبور ترافیک بین اینترفیس GRE و اینترفیس WAN
- بکاپ از تنظیمات SSH، fail2ban و UFW قبل از تغییر

## اجرا

```bash
sudo bash scripts/tunnel-security-wizard.sh
```

## نکته مهم

قبل از فعال‌سازی فایروال، حتماً یک دسترسی اضطراری (کنسول پنل/VNC/KVM) داشته باشید.

## بکاپ‌ها

همه بکاپ‌ها در مسیر زیر ذخیره می‌شود:

```bash
/root/tunnel-secure-backups
```
