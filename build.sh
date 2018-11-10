#!/bin/sh

rssg src/index.md > src/rss.xml
~/bin/ssg3 src dst 'Cryogenix' 'https://cryogenix.net'
