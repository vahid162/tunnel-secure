# tunnel-secure

این ریپو یک اسکریپت Wizard برای سخت‌سازی امنیت سرورهایی دارد که از `ssh-tunnel` یا `gre-4` (یا هر دو همزمان) استفاده می‌کنند، با تمرکز روی این‌که تونل شما قطع نشود.

## اسکریپت

- مسیر: `scripts/tunnel-security-wizard.sh`
- نوع اجرا: تعاملی (سوال‌محور)
- مناسب برای: Ubuntu/Debian (به‌خاطر `apt` و `ufw`)
- رفتار هوشمند: قبل از سؤال‌ها، اسکریپت خودش مقادیر اولیه را از سرور تشخیص می‌دهد و بعد شما فقط تایید/اصلاح می‌کنید.

## قابلیت‌ها

- تنظیم امن SSH با Drop-in استاندارد (`/etc/ssh/sshd_config.d/00-tunnel-secure.conf`) و اعتبارسنجی قبل از ری‌استارت
- در صورت خطای کانفیگ SSH، rollback خودکار فایل Drop-in
- فعال‌سازی `fail2ban` برای جلوگیری از Brute-force
- تنظیم `sysctl` سازگار با GRE (برای جلوگیری از اختلال rp_filter)
- پشتیبانی از حالت اجرای همزمان دو تونل (`ssh-tunnel` + `gre-4`)
- انتخاب حالت دسترسی SSH در UFW:
  - حالت محدود (فقط IP مدیریتی)
  - حالت باز (پورت SSH باز + اتکا به Fail2ban)
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
- اعتبارسنجی ورودی‌های حساس (IP مدیریت، IP سمت GRE، پورت SSH)
- تشخیص خودکار اولیه برای: IP مدیریت، پورت SSH، نوع تونل (ssh/gre/both)، اینترفیس GRE، Peer احتمالی GRE و اینترفیس WAN

## اجرا

```bash
sudo bash scripts/tunnel-security-wizard.sh
```

## رفع خطای رایج

اگر خطای زیر را دیدید:

```bash
bash: scripts/tunnel-security-wizard.sh: No such file or directory
```

یعنی در مسیر اشتباه هستید و از داخل پوشه‌ی ریپو دستور را اجرا نکرده‌اید. اول به مسیر پروژه بروید و بعد اجرا کنید:

```bash
cd /workspace/tunnel-secure
sudo bash scripts/tunnel-security-wizard.sh
```

اگر پروژه را جای دیگری clone کرده‌اید، به‌جای `/workspace/tunnel-secure` مسیر واقعی همان پوشه را بگذارید.

## نکته مهم

قبل از فعال‌سازی فایروال، حتماً یک دسترسی اضطراری (کنسول پنل/VNC/KVM) داشته باشید.

## بکاپ‌ها

همه بکاپ‌ها در مسیر زیر ذخیره می‌شود:

```bash
/root/tunnel-secure-backups
```
