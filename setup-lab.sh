#!/bin/bash
# Microservices Simulation Lab — إعداد الخادم كاملًا بأمر واحد
# الاستخدام:  sudo bash /home/tareq/cs/tools/lan/setup-lab.sh
set -euo pipefail

LAN=/home/tareq/cs/tools/lan
say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

say "1/6 تثبيت nginx"
apt-get update -qq
apt-get install -y nginx

say "2/6 إعداد dnsmasq (DNS فقط — DHCP معلّق عمدًا)"
if [ ! -f /etc/dnsmasq.conf.lab-backup ]; then
  cp /etc/dnsmasq.conf /etc/dnsmasq.conf.lab-backup
  echo "نُسخت /etc/dnsmasq.conf إلى /etc/dnsmasq.conf.lab-backup"
fi
if grep -q 'Microservices Simulation Lab' /etc/dnsmasq.conf; then
  echo "كتلة التجربة موجودة مسبقًا — تخطي الإلحاق"
else
  cat "$LAN/dnsmasq-mysite-block.conf" >> /etc/dnsmasq.conf
  echo "أُضيفت الكتلة إلى /etc/dnsmasq.conf"
fi
systemctl restart dnsmasq
systemctl --no-pager --full status dnsmasq | head -5 || true

say "3/6 نشر الموقع في /var/www/mysite"
mkdir -p /var/www/mysite
cp "$LAN/site/index.html" /var/www/mysite/index.html

say "4/6 تفعيل موقع nginx وتعطيل الافتراضي (يحجز default_server)"
cp "$LAN/nginx-mysite.conf" /etc/nginx/sites-available/mysite.local
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/mysite.local /etc/nginx/sites-enabled/mysite.local
nginx -t
systemctl reload nginx

say "5/6 الجدار الناري"
if ufw status | grep -q 'Status: active'; then
  ufw allow 80/tcp comment 'LAN lab - nginx'
  echo "أُضيفت قاعدة ufw للمنفذ 80"
else
  echo "ufw غير مفعّل — لا حاجة لقواعد (الهاتف سيصل مباشرة)"
fi

say "6/6 تحقق سريع"
ss -tulpn | grep -E ':(53|80)\s' || true
echo
echo "اكتمل الإعداد. افحص من طرفيتك:"
echo "  curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/"
echo "  nslookup mysite.local 127.0.0.1"
