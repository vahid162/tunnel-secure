# tunnel-secure

اسکریپت‌های این ریپو برای سخت‌سازی امن سرورهای Ubuntu/Debian طراحی شده‌اند تا هم SSH امن‌تر شود، هم ریسک قطع دسترسی (lockout) کاهش پیدا کند.

## ریپوهای مرتبط
- `gre-4`: https://github.com/vahid162/gre-4
- `ssh-tunnel`: https://github.com/vahid162/ssh-tunnel

## اسکریپت‌ها
- `scripts/tunnel-security-wizard.sh` → Wizard اصلی برای apply/update یا rollback
- `scripts/tunnel-security-audit.sh` → فقط گزارش وضعیت (بدون تغییر)
- `scripts/tunnel-security-emergency-ssh-recover.sh` → بازیابی اضطراری SSH از کنسول (VNC/KVM)
- `scripts/tunnel-security-selftest.sh` → تست داخلی منطق اسکریپت‌ها

## قابلیت‌های کلیدی
- تنظیم SSH با Drop-in استاندارد و اعتبارسنجی قبل از ری‌استارت
- rollback خودکار در صورت خطای کانفیگ SSH
- فعال‌سازی Fail2ban برای کاهش brute-force
- تنظیم UFW با تمرکز روی جلوگیری از lockout
- تشخیص خودکار موارد مهم:
  - IP مدیریت فعلی
  - SSH Port
  - Tunnel mode (`ssh` / `gre` / `both`)
  - IPهای محتمل peer تونل
  - پورت‌های سرویس تونل (از UFW/listening ports)
- ساخت Restore Point قبل از اعمال تغییرات

## اجرای Wizard
```bash
sudo bash scripts/tunnel-security-wizard.sh
```

حالت‌ها:
- `1) apply/update security`
- `2) rollback to previous restore point`

## اجرای سریع (بدون clone)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vahid162/tunnel-secure/main/scripts/tunnel-security-wizard.sh)
```

## Audit (بدون اعمال تغییر)
```bash
curl -fsSL https://raw.githubusercontent.com/vahid162/tunnel-secure/main/scripts/tunnel-security-audit.sh -o /tmp/tunnel-security-audit.sh
sudo bash /tmp/tunnel-security-audit.sh
```

## ریکاوری اضطراری SSH (وقتی lockout شده‌اید)
> فقط از کنسول پنل/VNC/KVM اجرا کنید.

```bash
cd /root
rm -rf tunnel-secure
git clone https://github.com/vahid162/tunnel-secure.git
cd tunnel-secure
sudo bash scripts/tunnel-security-emergency-ssh-recover.sh --port 22
```

اگر SSH روی پورت دیگری است:
```bash
sudo bash scripts/tunnel-security-emergency-ssh-recover.sh --port 2222
```

## توصیه امن برای کاربران با IP متغیر
- در حالت `SSH firewall mode = 2 (open + Fail2ban)`، لیست Management IP فقط برای مرجع/ایمنی نگه‌داری می‌شود و محدودکننده SSH نیست.
- در Wizard معمولاً `SSH firewall mode = 2 (open + Fail2ban)` انتخاب امن‌تری برای جلوگیری از lockout است.
- پورت‌های واقعی تونل را در `SSH tunnel service port(s)` تأیید کنید.
- تشخیص خودکار پورت‌ها به‌صورت محافظه‌کارانه انجام می‌شود؛ قبل از تایید نهایی فقط پورت‌های واقعی تونل را نگه دارید.
- IPهای peer تونل را در `Trusted SSH tunnel peer IP(s)` تأیید کنید.
- قبل از بستن سشن فعلی، یک سشن SSH جدید باز و تست کنید.

## بکاپ‌ها
- مسیر بکاپ‌ها: `/root/tunnel-secure-backups`
