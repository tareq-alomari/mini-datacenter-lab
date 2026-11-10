<div dir="rtl">

# مركز البيانات المصغّر
**Mini Datacenter Lab — Local Production Simulation & Service Routing**

[![Ubuntu 24.04 LTS](https://img.shields.io/badge/Ubuntu-24.04%20LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![nginx](https://img.shields.io/badge/nginx-reverse%20proxy-009639?logo=nginx&logoColor=white)](https://nginx.org)
[![dnsmasq](https://img.shields.io/badge/dnsmasq-DNS%2FDHCP-76b900)](https://thekelleys.org.uk/dnsmasq/docs/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> تحويل حاسوب Ubuntu منزلي إلى «مركز بيانات مصغّر»: خادم DNS محلي، وموجّه وويب (Reverse Proxy)، ثم الوصول إليه من هاتفك عبر شبكة Wi-Fi — كمحاكاة كاملة لمعمارية **Microservices** خلف بوابة واحدة.

</div>

**English:** A hands-on home-lab that turns an Ubuntu machine into a mini datacenter — local DNS/DHCP via `dnsmasq`, web routing via `nginx` — reachable from a phone on the same Wi-Fi. Built to *learn* how reverse proxies and microservice gateways actually work, not just to read about them. All documentation is in Arabic (see [REFERENCE.md](REFERENCE.md)); this README mirrors the essentials.

---

## الفكرة

في الشركات، لا تصل أجهزتك أبدًا مباشرة إلى الخدمات الداخلية. هناك دائمًا **بوابة واحدة** (Ingress / API Gateway / Load Balancer) تستقبل الطلب ثم تقرر داخليًا أين يذهب. هذه التجربة تبني نفس المبنى المصغّر على مكتبك:

```
 الهاتف  ──HTTP──▶  الراوتر (Wi-Fi)  ──▶  Ubuntu @ 192.168.0.4
   │                                          │
   │  Host: mysite.local أو IP مباشرة         ├─ dnsmasq :53   ← mysite.local → 192.168.0.4
   │                                          └─ nginx   :80   ← default_server يوجّه إلى /var/www/mysite
   ▼                                                                (وفي المرحلة التالية: proxy_pass → API على :3000)
 صفحة «مركز بيانات مصغّر»
```

**Definition of Done:** تظهر صفحة `site/index.html` على شاشة الجوال بعد فتح `http://192.168.0.4` في المتصفح.

---

## المتطلبات

| المكوّن | الشرط |
|---|---|
| الخادم | Ubuntu 24.04 LTS (أو أحدث مع مراجعة الإعدادات) + صلاحية `sudo` |
| العميل | هاتف Android/iOS على **نفس شبكة Wi-Fi** |
| البرمجيات | `nginx` و `dnsmasq` (يثبّتهما سكربت الإعداد) |

---

## التشغيل بأمر واحد

```bash
sudo bash setup-lab.sh
```

ما يفعله السكربت (ولماذا) — التفصيل الكامل في [REFERENCE.md](REFERENCE.md):

1. تثبيت `nginx`.
2. نسخ احتياطي `/etc/dnsmasq.conf` ← `/etc/dnsmasq.conf.lab-backup` (مرة واحدة) ثم إلحاق قاعدة DNS: `address=/mysite.local/192.168.0.4` وإعادة تشغيل `dnsmasq`.
   - ⚠️ **DHCP معطّل عمدًا**: الراوتر هو من يوزّع العناوين على شبكة المنزل، وتشغيل خادم DHCP ثانٍ سيمنح الأجهزة عناوين متضاربة. السكربت لا يفعّل `dhcp-range` إطلاقًا؛ يوجد في [dnsmasq-mysite-block.conf](dnsmasq-mysite-block.conf) معلّقًا مع تعليمات تفعيله على شبكة معزولة (Hotspot) فقط.
   - 📌 فخ Ubuntu 24.04: سطر `conf-dir=/etc/dnsmasq.d` **معلّق افتراضيًا** في `/etc/dnsmasq.conf`، لذلك تُلحق القاعدة بالملف الرئيسي مباشرة.
3. نشر الموقع إلى `/var/www/mysite/`.
4. تفعيل `mysite.local` في `nginx sites-available/enabled` كـ `default_server` على المنفذ 80، و**تعطيل موقع nginx الافتراضي** (يحجز `default_server` ويمنع ظهور صفحتنا عند فتح IP مباشرة)، ثم `nginx -t` وإعادة التحميل.
5. فتح المنفذ 80 في `ufw` إن كان مفعّلًا.

> الخادم لا يتأثر إن فشل `nginx -t` — إعادة التحميل لا تتم إلا بعد نجاح الاختبار.

---

## التحقق (Definition of Done)

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/      # المتوقع: 200
curl -s -o /dev/null -w '%{http_code}\n' http://192.168.0.4/    # المتوقع: 200
nslookup mysite.local 127.0.0.1                                  # المتوقع: Address: 192.168.0.4
```

ثم على الهاتف: افتح **`http://192.168.0.4`** ← يجب أن تظهر صفحة «مركز بيانات مصغّر».

> الحالة الراهنة: جميع ملفات التجربة وسكربت الإعداد **جاهزة ومختبرة نحويًا**؛ تطبيقها على النظام بانتظار تشغيل السكربت بـ `sudo` (يتطلب كلمة المرور). راجع [lab-log.md](lab-log.md) لسجل التحقق الفعلي.

---

## بنية المشروع

```
.
├── README.md                  ← هذا الملف
├── REFERENCE.md               ← المرجع الكامل (الأسباب، الاختبارات، استكشاف الأخطاء، Rollback)
├── lab-log.md                 ← سجل التحقق الفعلي خطوة بخطوة
├── setup-lab.sh               ← سكربت الإعداد الكامل (idempotent قدر الإمكان)
├── dnsmasq-mysite-block.conf  ← قاعدة DNS المضافة لـ /etc/dnsmasq.conf (DHCP معلّق)
├── nginx-mysite.conf          ← إعداد موقع nginx (default_server, المنفذ 80)
└── site/
    └── index.html             ← الصفحة المُقدَّمة (عربية RTL، ذاتية الاحتواء)
```

## التراجع (Rollback)

```bash
sudo rm /etc/nginx/sites-enabled/mysite.local
sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
sudo systemctl reload nginx
sudo cp /etc/dnsmasq.conf.lab-backup /etc/dnsmasq.conf && sudo systemctl restart dnsmasq
sudo rm -rf /var/www/mysite
```

التفاصيل والحالات الحدّية في [REFERENCE.md](REFERENCE.md) §9.

## أمان

- هذا Lab مخصّص لشبكات **منزلية موثوقة**؛ المنفذ 80 ظاهر لكل من على الـ Wi-Fi.
- لا تُفعّل خادم DHCP على شبكة المنزل (راجع القسم أعلاه).
- المشروع لا يحتوي أي أسرار (لا مفاتيح، لا رموز، لا كلمات مرور) — لا تضف أيًا منها.

## المرحلة التالية: من Static إلى Microservices

استبدل الجذر الثابت بخادم API داخلي — هذه هي الفكرة كلها:

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:3000/;
    proxy_set_header X-Real-IP $remote_addr;
}
```

الهاتف يرى بوابة واحدة فقط على المنفذ 80؛ والخدمات الداخلية (`:3000` و`:3001`…) غير مرئية من الخارج.

## ماذا ستتعلم؟

- الفرق بين `ping` (ICMP، بلا منافذ) واختبار TCP/HTTP للمنفذ الفعلي
- كيف تعمل `Host` header و`default_server` في nginx
- لماذا لا ترى أجهزة الشبكة خدماتك الداخلية إلا عبر البوابة
- حدود DNS المنزلي (الراوتر هو من يجيب الأجهزة) وكيف تتجاوزها بـ hosts/التوجيه

## الترخيص

[MIT](LICENSE) — حقوق النشر © 2026 tareq. استخدمه وعدّله وتعلّم منه بحرية.

## التوثيق

- [REFERENCE.md](REFERENCE.md) — المرجع الهندسي الكامل (عربي)
- [lab-log.md](lab-log.md) — سجل التنفيذ والتحقق الفعلي

---

*صُنع كتجربة تعليمية لـ LAN + Reverse Proxy + Microservices. لا غرض إنتاجي — بيئة معملية فقط.*
