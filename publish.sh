#!/bin/sh
cp src/rss.xml dst/
doas cp dst/* /var/www/htdocs/cryogenix.net/
git add .
git commit -m "updates"
git push
