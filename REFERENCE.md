# مرجع تجربة «مركز البيانات المصغّر»
# Local Production Simulation & Service Routing — مرجع كامل للتنفيذ والتعلم

آخر تحديث: 2026-11-10 — **الحالة: مُعَدّ بالكامل من جهة الملفات، ولم يُطبَّق بعد على النظام** (انتظار تشغيل سكربت الإعداد بـ `sudo` — محاولة سابقة فشلت دون أي تعديل على النظام).

---

## 1) الهدف والسيناريو

تحويل حاسوب Ubuntu محلي إلى «مركز بيانات مصغّر» يدير:

| الدور | البرنامج | الوظيفة |
|---|---|---|
| توزيع العناوين (DHCP) | `dnsmasq` | يوزّع IP تلقائيًا (مُعطّل عمدًا هنا — انظر §6) |
| ترجمة الأسماء (DNS) | `dnsmasq` | يربط `mysite.local` ← `192.168.0.4` |
| توجيه الخدمات (Reverse Proxy) | `nginx` | يستمع على المنفذ 80 ويوجّه الطلبات داخليًا |

ثم يُختبر الوصول من جهاز عميل خارجي (الهاتف) على نفس شبكة Wi-Fi.

**Definition of Done (DoD):** تظهر صفحة الموقع (`site/index.html`) على شاشة الجوال عند فتح `http://192.168.0.4` في المتصفح.

**الملفات في هذا المجلد (كلها جاهزة):**

```
site/index.html            الصفحة التي تُقدَّم (عربية RTL، ذاتية الاحتواء، بدون أصول خارجية)
nginx-mysite.conf          إعداد موقع nginx (default_server على المنفذ 80)
dnsmasq-mysite-block.conf  الكتلة المضافة إلى /etc/dnsmasq.conf (DNS فقط؛ DHCP معلّق)
setup-lab.sh               سكربت الإعداد الكامل (يشغَّل بـ sudo مرة واحدة)
README.md                  دليل سريع (الهدف، المراحل، Rollback)
lab-log.md                 سجل التحقق الفعلي خطوة بخطوة
REFERENCE.md               هذا المرجع
```

---

## 2) البيئة المكتشفة قبل التنفيذ (2026-11-10)

- النظام: Ubuntu 24.04.3 LTS — الحاسوب `tareq-HP-ZBook-15-G5`
- الواجهة: `wlp0s20f3` (Wi-Fi) — **IP: `192.168.0.4/24`** — العنوان قد يتغير بعد إعادة الاتصال بالشبكة، وعندها يجب تحديث `address=/mysite.local/...` في dnsmasq
- `dnsmasq` مثبّت ويعمل بإعدادات **افتراضية** (كل أسطر dhcp/address معلّقة)
- **فخ Ubuntu 24.04:** سطر `conf-dir=/etc/dnsmasq.d` في `/etc/dnsmasq.conf` **معلّق افتراضيًا** — أي ملف داخل `/etc/dnsmasq.d/` لن يُقرأ، لذلك تُلحق كتلة التجربة بالملف الرئيسي مباشرة
- التعايش مع `systemd-resolved`: يحجز `127.0.0.53:53` و`127.0.0.54:53` فقط، و`dnsmasq` يحجز باقي الواجهات — لا تعارض، ويكفي إعادة تشغيل dnsmasq
- `nginx`: غير مثبّت قبل التجربة
- `ufw`: موجود؛ تُضاف قاعدة المنفذ 80 **فقط إذا كان مفعّلًا** (يفعلها السكربت تلقائيًا)
- `sudo`: يتطلب كلمة مرور — الأوامر المميزة تُلزِم المستخدم (لا يمكن للجلسة إدخالها)

---

## 3) المرحلة الأولى — إعداد الخادم (تفصيل خطوة بخطوة)

### التشغيل (أمر واحد)

```bash
sudo bash /home/tareq/cs/tools/lan/setup-lab.sh
```

> تحذير شائع: تشغيل `./setup-lab.sh` **بدون sudo** يفشل عند خطوة apt بصلاحية مرفوضة ويتوقف السكربت قبل لمس أي إعداد — وهذا الوضع آمن تمامًا. التشغيل الصحيح هو `sudo bash ...`.

### ما يفعله السكربت ولماذا (كل خطوة)

1. **تثبيت nginx** — `apt-get update && apt-get install -y nginx`
   nginx هو الـ Reverse Proxy: يستقبل HTTP على المنفذ 80 ويقرر أين يذهب الطلب داخليًا.

2. **إعداد dnsmasq** — يعمل على ثلاث خطوات:
   - نسخ احتياطي: `cp /etc/dnsmasq.conf /etc/dnsmasq.conf.lab-backup` (مرة واحدة فقط، أساس الـ Rollback)
   - إلحاق الكتلة من `dnsmasq-mysite-block.conf` (مرة واحدة؛ السكربت يتحقق من وجودها بـ grep فلا يكررها):
     ```
     address=/mysite.local/192.168.0.4
     # dhcp-range=192.168.0.50,192.168.0.150,12h   ← معلّق عمدًا (انظر §6)
     ```
     `address=/mysite.local/192.168.0.4` تعني: أي استعلام عن `*.mysite.local` يُجاب بـ `192.168.0.4`.
   - إعادة تشغيل: `systemctl restart dnsmasq`

3. **نشر الموقع** — `mkdir -p /var/www/mysite && cp site/index.html /var/www/mysite/`

4. **تفعيل موقع nginx**:
   - نسخ `nginx-mysite.conf` ← `/etc/nginx/sites-available/mysite.local`
   - **تعطيل الموقع الافتراضي**: `rm -f /etc/nginx/sites-enabled/default`
     (الرمز `default` في sites-enabled هو الرابط الذي يُحذف؛ ملف الإعداد الأصلي يبقى في sites-available بلا مساس). السبب: الموقع الافتراضي يحجز `default_server` على المنفذ 80، والهاتف يفتح `http://192.168.0.4` بلا Host header مطابق — فلو بقي الافتراضي لظهرت صفحة nginx الافتراضية بدل موقعنا.
   - ربط موقعنا: `ln -sf .../sites-available/mysite.local .../sites-enabled/mysite.local`
   - **اختبار الإعداد قبل إعادة التحميل**: `nginx -t` ثم `systemctl reload nginx` (لا نُعيد تشغيل nginx قبل نجاح الاختبار — الإعداد الخاطئ لن يُسقط الخادم)

5. **الجدار الناري** — إذا كان `ufw` بحالة `Status: active` فقط: `ufw allow 80/tcp comment 'LAN lab - nginx'`. إن لم يكن مفعّلًا لا شيء.

6. **تحقق سريع** — `ss -tulpn | grep -E ':(53|80)'` يجب أن يُظهر nginx على `0.0.0.0:80` (وdnsmasq على الواجهات).

### شرح إعداد الموقع `nginx-mysite.conf`

```nginx
server {
    listen 80 default_server;          # يجيب على أي طلب بلا خادم مطابق (يشمل IP المباشر من الهاتف — شرط الـ DoD)
    listen [::]:80 default_server;     # نفس الشيء لـ IPv6
    server_name mysite.local _;        # النطاق + «كل شيء آخر»
    root /var/www/mysite;              # الجذر على القرص — خفيٌّ عن العميل تمامًا
    index index.html;
    location / { try_files $uri $uri/ =404; }
}
```

---

## 4) المرحلة الثانية — اختبار النظم الفرعية (محليًا)

> ملاحظة مصطلحية: «ping على المنفذ» غير دقيق — `ping` هو ICMP (بدون منافذ أصلًا). اختبار المنفذ يكون بـ HTTP/TCP. تحقّق بالترتيب:

```bash
# 1) ICMP — أن الجهاز الشبكي حيّ (اختبار الشبكة لا nginx)
ping -c 3 127.0.0.1

# 2) المنفذ 80 يستمع فعلًا
ss -tulpn | grep ':80'

# 3) nginx يجيب محليًا على IP المباشر
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/              # المتوقع: 200
curl -s -o /dev/null -w '%{http_code}\n' http://192.168.0.4/            # المتوقع: 200

# 4) nginx يوجّه بناءً على اسم النطاق (Host header) وليس على IP فقط
curl -s -H 'Host: mysite.local' http://127.0.0.1/ | head -8             # يجب أن تظهر صفحتنا (RTL، «مركز بيانات مصغّر»)

# 5) DNS: dnsmasq يترجم الاسم إلى IP
nslookup mysite.local 127.0.0.1        # المتوقع: Address: 192.168.0.4 (أو ::ffff:...)

# 6) منفذ TCP فعلي (اختياري، مثال على nc)
nc -zv 127.0.0.1 80                    # المتوقع: succeeded
```

ملاحظتان تعليميتان مهمتان:

- `nslookup mysite.local` **بدون تحديد خادم** سيستخدم `systemd-resolved` (127.0.0.53) وليس dnsmasq، فلن يعرف الاسم — لذلك نحدد `127.0.0.1` صراحة لإثبات أن dnsmasq هو من يترجم.
- `getent hosts mysite.local` لن ينجح إلا إذا عرفه النظام (مثلًا بإضافته إلى `/etc/hosts`) أو إذا وجّهت `systemd-resolved` نحو dnsmasq — اختبار dnsmasq الصحيح هو `nslookup ... 127.0.0.1` كما أعلاه.

### مفيد أيضًا: تجربة الـ DNS من أي أداة على الشبكة المحلية

```bash
nslookup mysite.local 192.168.0.4      # نفس الإثبات لكن عبر واجهة Wi-Fi الفعلية (كما سيفعل عميل خارجي لو عرف العنوان)
```

---

## 5) المرحلة الثالثة — اختبار الوصول من الجوال (DoD)

1. تأكد أن الهاتف على **نفس شبكة Wi-Fi** (وليس بيانات الجوال، وليس شبكة ضيف معزولة — انظر §8).
2. افتح في المتصفح: `http://192.168.0.4` ← يجب أن تظهر صفحة «مركز بيانات مصغّر» (HTTP 200).

### لماذا لن يعمل `http://mysite.local` على الهاتف مباشرة؟

لأن هاتفك يسأل **الراوتر** عن الأسماء، والراوتر لا يعرف `mysite.local` — قواعد dnsmasq هذه تُخدم فقط على المنفذ 53 من هذا الحاسوب، ولا يراها أي عميل ما لم يُوجَّه إليه صراحة. الحلول المتقدمة اختيارية:

- **(أ) ملف hosts على الهاتف** (يحتاج Termux بصلاحيات، أو هاتف مروّت): أضف `192.168.0.4 mysite.local` ثم افتح `http://mysite.local`.
- **(ب) توجيه DNS الراوتر** إلى `192.168.0.4` (إعدادات الرواتر ← DNS primary): تجعل كل الأجهزة تترجم عبر dnsmasq — أقوى حل لكنه يؤثر على كل الشبكة، فلا تفعله على شبكة منزلية دون فهم.
- **(ج) إبقاء DoD على IP المباشر** — وهذا هو المطلوب من التجربة أصلًا.

---

## 6) DHCP — لماذا هو معطّل في هذه التجربة؟

الراوتر (`192.168.0.1`) هو خادم DHCP الفعلي على شبكة المنزل. تشغيل `dnsmasq` بخادم DHCP ثانٍ على نفس الواجهة (`wlp0s20f3`) يعني خادمين يتسابقان على الرد، وقد تحصل الأجهزة على عناوين متضاربة أو بوابات خاطئة ← انقطاع الإنترنت عن أجهزة المنزل. لذلك:

- الكتلة في `dnsmasq.conf` تتضمن `dhcp-range` **معلّقًا** للتوثيق فقط، مع شرح طريقة تفعيله.
- لتفعيله فعليًا بأمان: شبكة **معزولة** (Hotspot الهاتف) + سطر `interface=<واجهة-الهوتسبوت>` قبل `dhcp-range`، فتُخدم DHCP على تلك الواجهة فقط.

---

## 7) المرحلة الرابعة — المراجعة الهندسية (بعد نجاح الـ DoD)

### 7.1 كيف «يعمل» الـ Port Forwarding هنا؟

الهاتف أرسل `GET /` إلى `192.168.0.4:80`. nginx (المستمع على المنفذ):

1. يقبل TCP من أي عميل LAN،
2. يقرأ `Host` (هنا: `192.168.0.4` لأننا فتحنا IP مباشرة — وفي التفعيل النمطي: `mysite.local`)،
3. يطابق الـ `server` block (`default_server` هنا)،
4. يحوّل الطلب داخليًا إلى مسار على القرص `/var/www/mysite/index.html` ويعيد المحتوى كـ HTTP 200.

العميل **لا يعرف ولا يستطيع أن يعرف** مسار الملف أو بنيته — ما يراه واجهة HTTP فقط. هذه هي قاعدة: «التوجيه قرار داخلي، والواجهة معلنة».

### 7.2 الإسقاط على Microservices — `proxy_pass`

استبدل الجذر الثابت بخادم API حقيقي:

```bash
# تجربة حية اختيارية: خادم Node/Python على منفذ داخلي ثم توجيه nginx إليه
python3 -m http.server 3000 --directory /tmp &   # بديل مؤقت عن Node API
```

وفي `/etc/nginx/sites-available/mysite.local` أضف داخل الـ `server`:

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:3000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

ثم `sudo nginx -t && sudo systemctl reload nginx`، وافتح `http://192.168.0.4/api/`.

**هذا بالضبط** كيف تتواصل الخدمات في معمارية الميكروسيرفيس: nginx (أو Ingress/API Gateway) هو الباب الوحيد، والخدمات الداخلية (`:3000`، `:3001`…) غير مرئية من الخارج. امتداد طبيعي: عدة `upstream` backends + توزيع حمل.

---

## 8) استكشاف الأخطاء (Troubleshooting)

| العَرَض | السبب المرجّح | الحل |
|---|---|---|
| `Permission denied` عند `./setup-lab.sh` | شُغّل بدون sudo | `sudo bash /home/tareq/cs/tools/lan/setup-lab.sh` |
| `apt`: lock file / permission | نفس السبب أعلاه | نفس الحل |
| الهاتف: «لا يمكن الوصول للموقع» لكن curl محلي ينجح | (1) ufw مفعّل ويمنع 80؛ (2) شبكة الضيف/عزل العملاء في الراوتر؛ (3) VPN على الهاتف؛ (4) IP تغيّر بعد إعادة الاتصال بالـ Wi-Fi | (1) `sudo ufw allow 80/tcp`؛ (2) استخدم شبكة المنزل الرئيسية أو ألغِ Client Isolation من إعدادات الراوتر؛ (3) أوقف VPN مؤقتًا؛ (4) `ip -4 addr show wlp0s20f3` وصحّح الـ `address=` وملفات الإعداد |
| صفحة nginx الافتراضية تظهر بدل موقعنا | بقي `sites-enabled/default` | `sudo rm /etc/nginx/sites-enabled/default && sudo systemctl reload nginx` |
| `nslookup mysite.local` لا يجيب | استعلمت systemd-resolved وليس dnsmasq | `nslookup mysite.local 127.0.0.1` |
| `dnsmasq` لا يعيد التشغيل / المنفذ 53 محجوز | تعارض نادر مع مُحلِّل آخر يحجز كل الواجهات | `sudo ss -tulpn | grep :53` ثم راجع من يحجزه؛ في Ubuntu العادي systemd-resolved لا يحجز إلا loopback فلا يحدث تعارض |
| `nginx -t` يفشل بعد تعديل يدوي | خطأ إملائي في الإعداد | اقرأ رسالة الخطأ (رقم السطر)، صحّح، ثم `nginx -t` مجددًا — الخادم الحالي لا يتأثر حتى ينجح الاختبار |
| `ping` ينجح و`curl` يفشل والعكس | `ping` (ICMP) ≠ المنفذ 80 (TCP) | النجاح الحقيقي يُقاس بـ `curl`/`nc -zv` على 80 |

## 9) التراجع الكامل (Rollback)

```bash
sudo rm /etc/nginx/sites-enabled/mysite.local
sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
sudo systemctl reload nginx          # يعود nginx لحالته الافتراضية
sudo cp /etc/dnsmasq.conf.lab-backup /etc/dnsmasq.conf
sudo systemctl restart dnsmasq       # تختفي قاعدة mysite.local
sudo rm -rf /var/www/mysite
sudo ufw delete allow 80/tcp         # فقط إذا كنت أضفتها (السكربت يذكرها)
```

ملفات المشروع في هذا المجلد لا تؤثر على النظام وتبقى كما هي للتوثيق.

---

## 10) DoD — قائمة التحقق النهائية

- [ ] `sudo bash .../setup-lab.sh` اكتمل بلا أخطاء (الصقه هنا إن أردت مراجعته)
- [ ] `curl http://127.0.0.1/` ← 200
- [ ] `curl http://192.168.0.4/` ← 200
- [ ] `nslookup mysite.local 127.0.0.1` ← `Address: 192.168.0.4`
- [ ] الهاتف ← `http://192.168.0.4` ← **تظهر صفحة «مركز بيانات مصغّر»** ← DoD محقق
- [ ] (اختياري) `http://mysite.local` من الهاتف بعد ضبط hosts/الراوتر

---

## 11) أسئلة المراجعة (للتعلم الذاتي)

1. لماذا اشترطنا `default_server` وليس `server_name mysite.local` فقط؟ ماذا سيحدث للهاتف بدونه؟
2. لماذا لا يكفي ملف `hosts` على الحاسوب بدل dnsmasq؟ (Hint: ماذا يحدث مع 50 جهازًا و100 اسم؟)
3. أين بالضبط يحدث الـ «proxying» في داخل nginx؟ ما الذي يراه الـ upstream؟
4. كيف تحوّل هذا الإعداد إلى مرحلة إنتاج حقيقي؟ (TLS عبر certbot، `server_name` حقيقي، upstream متعدد، مراقبة)
5. لماذا عزلنا DHCP عن هذه الشبكة عمدًا، وما الثمن التعليمي لذلك؟
