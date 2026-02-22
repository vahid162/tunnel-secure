# tunnel-secure

این ریپو یک اسکریپت Wizard برای سخت‌سازی امنیت سرورهایی دارد که از `ssh-tunnel` یا `gre-4` (یا هر دو همزمان) استفاده می‌کنند، با تمرکز روی این‌که تونل شما قطع نشود.

## ریپوهای مرتبط

- `gre-4`: https://github.com/vahid162/gre-4
- `ssh-tunnel`: https://github.com/vahid162/ssh-tunnel

## اسکریپت

- مسیر: `scripts/tunnel-security-wizard.sh`
- اسکریپت ریکاوری اضطراری SSH (برای وقتی lockout شده‌اید): `scripts/tunnel-security-emergency-ssh-recover.sh`
- نوع اجرا: تعاملی (سوال‌محور)
- مناسب برای: Ubuntu/Debian (به‌خاطر `apt` و `ufw`)
- رفتار هوشمند: قبل از سؤال‌ها، اسکریپت خودش مقادیر اولیه را از سرور تشخیص می‌دهد و بعد شما فقط تایید/اصلاح می‌کنید.

## قابلیت‌ها

- تنظیم امن SSH با Drop-in استاندارد (`/etc/ssh/sshd_config.d/00-tunnel-secure.conf`) و اعتبارسنجی قبل از ری‌استارت
- هنگام اعمال SSH hardening، مقدار `PermitRootLogin` فعلی سرور به‌صورت خودکار تشخیص داده می‌شود و قبل از اعمال قابل تایید/تغییر است تا ریسک lockout ناخواسته کمتر شود
- در صورت خطای کانفیگ SSH، rollback خودکار فایل Drop-in
- فعال‌سازی `fail2ban` برای جلوگیری از Brute-force
- تنظیم `sysctl` سازگار با GRE (برای جلوگیری از اختلال rp_filter)
- پشتیبانی از حالت اجرای همزمان دو تونل (`ssh-tunnel` + `gre-4`)
- انتخاب حالت دسترسی SSH در UFW:
  - حالت محدود (فقط IP مدیریتی)
  - حالت باز (پورت SSH باز + اتکا به Fail2ban)
  - پیش‌فرض این گزینه روی حالت باز + Fail2ban (گزینه ۲) برای کاهش ریسک lockout کاربران مبتدی
  - پشتیبانی از چند IP مدیریتی (ورودی comma-separated) برای جلوگیری از قفل شدن SSH در تغییر IP/مسیر دسترسی
  - تشخیص خودکار IP سمت مقابل SSH tunnel (به‌همراه چند IP محتمل از اتصال‌های established) و افزودن آن‌ها به allowlist/Fail2ban ignore با امکان تایید/ویرایش
- تشخیص خودکار پورت‌های سرویس تونل از UFW فعلی و پورت‌های listen عمومی برای پیشنهاد خودکار در `SSH tunnel service port(s)`
- در اجرای مجدد Wizard، IP سشن فعلی ادمین و IPهای SSH محدودشدهٔ موجود UFW به‌صورت خودکار به allowlist اضافه می‌شوند تا ریسک lockout کمتر شود
- در شروع هر اجرای اعمال تغییرات، یک Restore Point کامل از SSH/Fail2ban/UFW/Sysctl ساخته می‌شود
- اجرای دوباره Wizard حالا یک حالت Rollback دارد تا با انتخاب Restore Point، تنظیمات به وضعیت قبلی برگردد
- در Rollback، اگر فایلی در زمان snapshot وجود نداشته، اسکریپت آن فایل را حذف می‌کند تا حالت قبلی دقیق‌تر بازگردانی شود
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

در ابتدای اجرا دو حالت دارید:

- `1) apply/update security` برای اعمال/بروزرسانی تنظیمات امنیتی
- `2) rollback to previous restore point` برای بازگردانی تنظیمات از روی بکاپ‌های Restore Point

در حالت rollback، اسکریپت لیست restore point های موجود را نشان می‌دهد، شماره را انتخاب می‌کنید و پس از تایید، تنظیمات SSH/Fail2ban/UFW/Sysctl را برمی‌گرداند.

## اجرای سریع (فقط با کپی/پیست)

مثل ریپوهای `gre-4` و `ssh-tunnel` می‌توانید بدون clone کردن دستی، مستقیم با یک دستور اجرا کنید:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vahid162/tunnel-secure/main/scripts/tunnel-security-wizard.sh)
```

اگر `curl` نصب نبود، از `wget` استفاده کنید:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/vahid162/tunnel-secure/main/scripts/tunnel-security-wizard.sh)
```

## اسکریپت بررسی وضعیت (بدون تغییر)

## تست خودکار سناریوها (بدون اعمال تغییر روی سرور)

برای اینکه مطمئن شوید منطق اسکریپت برای حالت‌های `ssh`، `gre` و `both` و همچنین سناریوی اجرای مجدد سالم است، تست داخلی زیر را اجرا کنید:

```bash
bash scripts/tunnel-security-selftest.sh
```

این تست هیچ تغییری روی فایروال/SSH انجام نمی‌دهد و فقط sanity-check منطق و اعتبارسنجی‌ها را بررسی می‌کند.

برای بررسی اینکه تنظیمات اعمال‌شده سالم هستند (بدون اعمال هیچ تغییری روی سرور):

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/vahid162/tunnel-secure/main/scripts/tunnel-security-audit.sh)
```

این اسکریپت فقط گزارش می‌دهد: وضعیت SSH، UFW، Fail2ban، پورت‌های listen، اینترفیس‌های GRE/TUN/TAP و بکاپ‌ها.

## ریکاوری اضطراری وقتی SSH قطع شده (بدون نیاز به SSH فعلی)

اگر الان دیگر SSH ندارید، باید از **کنسول پنل/VNC/KVM** سرور وارد شوید (نه SSH).

سپس در همان کنسول این دستورات را بزنید:

```bash
cd /root
rm -rf tunnel-secure
git clone https://github.com/vahid162/tunnel-secure.git
cd tunnel-secure
sudo bash scripts/tunnel-security-emergency-ssh-recover.sh --port 22
```

اگر SSH شما روی پورت دیگری است (مثلاً 2222):

```bash
sudo bash scripts/tunnel-security-emergency-ssh-recover.sh --port 2222
```

این اسکریپت در حالت اضطراری:
- یک کانفیگ حداقلی و قابل ورود برای SSH می‌نویسد (به‌همراه `ListenAddress 0.0.0.0`).
- بقیه drop-inهای `sshd_config.d` را موقتاً غیرفعال می‌کند تا تنظیمات متناقض جلوی ورود را نگیرند.
- `sshd -t` را قبل از ری‌استارت بررسی می‌کند.
- پورت SSH را در UFW و `iptables` باز می‌کند تا دوباره وصل شوید.
- Fail2ban را موقتاً متوقف می‌کند تا ban قبلی باعث قفل شدن دوباره نشود.
- از تنظیمات قبلی backup می‌گیرد (`/root/tunnel-secure-backups`).

اگر باز هم SSH از بیرون وصل نشد، در کنسول این چک‌ها را اجرا کنید:

```bash
sudo ss -lntp | grep -E ':22\b|:2222\b'
sudo systemctl status ssh --no-pager || sudo systemctl status sshd --no-pager
sudo ufw status verbose
sudo iptables -S INPUT | sed -n '1,80p'
```

اگر سرویس SSH بالا بود و روی پورت listen می‌کرد اما از بیرون هنوز وصل نشد، مشکل معمولاً از **Firewall پنل/Cloud Provider** است و باید همان پورت SSH را آنجا هم allow کنید.

بعد از اینکه SSH برگشت، سریعاً Wizard اصلی را دوباره اجرا کنید و تنظیم امن‌تر را اعمال کنید.

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

## سناریوی پیشنهادی: الان SSH داری و بعداً می‌خواهی GRE اضافه کنی

اگر الان سرورت روی `ssh-tunnel` پایدار است و بعداً می‌خواهی `gre-4` را هم اضافه کنی، مسیر امن پیشنهادی این است:

1. **اول وضعیت فعلی را فریز و بررسی کن**
   - با اسکریپت audit وضعیت SSH/UFW/Fail2ban را ثبت کن.
   - حتماً کنسول اضطراری (VNC/KVM) در دسترس باشد.
2. **GRE را جداگانه نصب/بالا بیاور (بدون دست‌زدن به فایروال)**
   - طبق ریپوی `gre-4` فقط اینترفیس GRE را بالا بیاور و `ping` دو سر GRE را تست کن.
3. **بعد Wizard را دوباره در حالت `both` اجرا کن**
   - `Tunnel mode = 3 (both)`
   - `GRE peer IP` را دقیق وارد کن.
   - اگر GRE برای روتینگ است، گزینه forwarding را هم `y` بزن.
4. **در مرحله UFW، پورت‌های SSH tunnel را هم نگه‌دار**
   - اگر هنوز سرویس SSH tunnel لازم است، پورت‌هایش را در `SSH tunnel service port(s)` وارد کن.
   - اگر لازم نیست، خالی بگذار.
5. **تست بعد از اعمال**
   - قبل از بستن سشن فعلی، یک SSH سشن جدید باز کن.
   - `ufw status verbose`، `ip a`، `ip route` و `ping` روی IP تونل GRE را بررسی کن.

### دستورهای پیشنهادی سریع برای این سناریو

```bash
# 1) قبل از تغییر: گزارش بدون تغییر
sudo bash <(curl -fsSL https://raw.githubusercontent.com/vahid162/tunnel-secure/main/scripts/tunnel-security-audit.sh)

# 2) بعد از بالا آوردن GRE: اجرای Wizard در حالت both
bash <(curl -fsSL https://raw.githubusercontent.com/vahid162/tunnel-secure/main/scripts/tunnel-security-wizard.sh)
# داخل Wizard: Tunnel mode = 3 (both)

# 3) بعد از اعمال: دوباره audit بگیر
sudo bash <(curl -fsSL https://raw.githubusercontent.com/vahid162/tunnel-secure/main/scripts/tunnel-security-audit.sh)
```

## سناریوی برعکس: الان GRE داری و بعداً می‌خواهی SSH Tunnel اضافه کنی

اگر الان `gre-4` فعال است و بعداً می‌خواهی `ssh-tunnel` را هم اضافه کنی، همین منطق را برعکس اجرا کن:

1. **قبل از هر تغییر audit بگیر**
   - وضعیت فعلی GRE/UFW/SSH را ذخیره کن.
2. **SSH tunnel را جداگانه بالا بیاور (بدون تغییر فوری فایروال)**
   - طبق ریپوی `ssh-tunnel` سرویس را بالا بیاور و listen بودن پورت سرویس را چک کن.
3. **Wizard را در حالت `both` اجرا کن**
   - `Tunnel mode = 3 (both)`
   - `GRE peer IP` و اینترفیس GRE را دقیق وارد کن.
4. **در مرحله `SSH tunnel service port(s)` پورت‌های SSH tunnel را دقیق وارد کن**
   - مثال: `443/tcp` یا `443/tcp,80/tcp`
   - اگر این مرحله خالی بماند، با `deny incoming` ممکن است سرویس SSH tunnel از بیرون قطع شود.
5. **تست نهایی بدون قطع سشن فعلی**
   - یک SSH سشن جدید باز کن.
   - سلامت GRE + SSH tunnel را با `ufw status verbose`، `ss -lntup` و تست اتصال واقعی چک کن.

## قاعده طلایی برای جلوگیری از تداخل سناریوها

- هر بار که یکی از تونل‌ها (SSH/GRE) اضافه یا حذف می‌شود، Wizard را دوباره اجرا کن.
- همیشه در Wizard حالتی را انتخاب کن که واقعاً الان روی سرور فعال است (`ssh` یا `gre` یا `both`).
- قبل/بعد از هر تغییر، یک audit بگیر تا تفاوت‌ها را سریع ببینی.
- تا وقتی اتصال جدید را تست نکرده‌ای، سشن فعلی SSH را نبند.

## ماتریس سناریوها (برای جلوگیری از تداخل)

- **فقط SSH tunnel داری (بدون GRE):**
  - `Tunnel mode = 1 (ssh)`
  - پورت(های) سرویس SSH tunnel را در `SSH tunnel service port(s)` وارد کن.
- **فقط GRE داری (بدون SSH tunnel):**
  - `Tunnel mode = 2 (gre)`
  - `GRE peer IP` را دقیق وارد کن.
- **SSH + GRE هر دو فعال هستند:**
  - `Tunnel mode = 3 (both)`
  - هم `GRE peer IP` را وارد کن، هم پورت‌های SSH tunnel را.
- **در حال مهاجرت (یکی اضافه/حذف می‌شود):**
  - قبل/بعد تغییر audit بگیر و Wizard را دوباره اجرا کن.

### نکته مهم درباره `SSH firewall mode`

- اگر `SSH firewall mode = 1 (restricted)` باشد: فقط IPهای allowlist اجازه SSH دارند.
- اگر `SSH firewall mode = 2 (open + Fail2ban)` باشد: پورت SSH برای همه باز است و allowlist برای خودِ SSH اعمال نمی‌شود.
- در سناریوی ایران/خارج، IP سمت مقابل SSH tunnel به‌صورت auto-detect پیشنهاد می‌شود و می‌تواند برای allowlist/Fail2ban ignore استفاده شود.

## نکته مهم

قبل از فعال‌سازی فایروال، حتماً یک دسترسی اضطراری (کنسول پنل/VNC/KVM) داشته باشید.

در حالت `SSH firewall mode = restricted`، فقط IPهای مدیریتی که وارد کرده‌اید اجازه SSH خواهند داشت. اگر IP فعلی/پشتیبان شما در لیست نباشد، ممکن است دسترسی SSH قطع شود (lockout).

برای سناریوی tunnel بین ایران/خارج، Wizard تلاش می‌کند IP سمت مقابل SSH tunnel را تشخیص دهد و آن را برای SSH allowlist و Fail2ban ignore پیشنهاد/اعمال کند تا تداخل کمتر شود.

در اجرای مجدد Wizard، IP سشن SSH فعلی شما و IPهای محدودشدهٔ قبلی UFW برای SSH به allowlist merge می‌شوند تا احتمال قطع دسترسی کاهش یابد.

## بکاپ‌ها

همه بکاپ‌ها در مسیر زیر ذخیره می‌شود:

```bash
/root/tunnel-secure-backups
```
