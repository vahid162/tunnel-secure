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


## قوانین عملکرد و منطق تصمیم‌گیری (برای توسعه‌دهنده‌ها)
این بخش برای کسی است که می‌خواهد روی اسکریپت کار کند و بداند منطق اصلی دقیقاً چیست.

### 1) هدف امنیتی پروژه
- این پروژه باید روی **سرور ایران** فقط دسترسی‌های لازم برای تونل‌های مرتبط (`gre-4` و `ssh-tunnel`) را باز بگذارد.
- در عین حال، سایر سطوح حمله سرور را با SSH hardening + UFW + Fail2ban محدود کند.
- اولویت اصلی: **امنیت بدون lockout** (قطع دسترسی ناخواسته ادمین).

### 2) اصل «کمترین دسترسی لازم»
- هر پورتی که برای تونل لازم نیست، نباید باز بماند.
- SSH می‌تواند در دو حالت اجرا شود:
  - `restricted`: فقط IPهای مدیریتی اجازه SSH دارند.
  - `open + Fail2ban`: SSH باز می‌ماند ولی با Fail2ban محافظت می‌شود (پیشنهاد امن‌تر برای کاربران مبتدی/آی‌پی متغیر).

### 3) تشخیص هوشمند Tunnel Mode
Wizard باید نوع تونل را به‌صورت خودکار تشخیص دهد و مقدار پیش‌فرض منطقی ارائه کند.

تشخیص `gre` با ترکیب این سیگنال‌ها انجام می‌شود:
- وجود اینترفیس‌های GRE در شبکه.
- وجود نشانه‌های رایج ریپوی `gre-4` در مسیرهای متداول.
- وجود سرویس‌های systemd مرتبط با GRE.

تشخیص `ssh` با ترکیب این سیگنال‌ها انجام می‌شود:
- وجود اینترفیس‌های `tun/tap`.
- وجود نشانه‌های رایج ریپوی `ssh-tunnel` در مسیرهای متداول.
- وجود سرویس‌های systemd مرتبط با SSH tunnel.

خروجی نهایی باید یکی از این ۳ حالت باشد:
- `ssh`
- `gre`
- `both`

### 4) منبع داده برای تشخیص خودکار Allowlist
اسکریپت باید قبل از اعمال UFW این ورودی‌ها را هوشمندانه پیشنهاد دهد:
- Management IP فعلی (جلسه SSH فعال)
- SSH Port موثر سیستم
- GRE peer احتمالی
- Tunnel service portها از UFW قبلی
- Listening portهای عمومیِ مشکوک به سرویس تونل
- IPهای peer محتمل از اتصال‌های established

> نکته مهم: Auto-detect محافظه‌کارانه است و کاربر باید قبل از Apply، مقادیر را تایید کند.

### 5) رفتار تعاملی اجباری (Interactive-first)
- Wizard نباید بدون تایید کاربر، تنظیمات حساس را کورکورانه اعمال کند.
- برای هر بخش حساس (SSH / Fail2ban / Sysctl / UFW) باید پرسش تایید وجود داشته باشد.
- در شروع کار باید Restore Point ساخته شود.
- اگر SSH config نامعتبر شد، rollback فوری انجام شود.

### 6) خط قرمز پروژه
- **هیچ محدودیت اشتباه نباید روی خود سرور تونل‌شده اعمال شود.**
- قوانین باید طوری اعمال شوند که سرویس تونل قطع نشود.
- هر تغییر جدید باید lockout-risk را کمتر کند، نه بیشتر.

### 7) قواعد توسعه (Contribution Rules)
- هر تغییر در منطق امنیتی باید همراه با به‌روزرسانی self-test باشد.
- نسخه Wizard باید با هر تغییر SemVer bump شود (حداقل PATCH).
- اگر `CHANGELOG.md` وجود داشت، تغییرات نسخه باید آنجا ثبت شود.
- هر PR باید واضح توضیح دهد:
  - Why
  - What
  - How to test
  - Version: old → new

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
