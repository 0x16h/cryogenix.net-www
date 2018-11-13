#### OpenBSD as an authoritative DNS nameserver
Configuring NSD on OpenBSD as an authoritative DNS nameserver

OpenBSD ships with the [NLnet Labs Name Server Daemon](https://nlnetlabs.nl/projects/nsd/about/) - [nsd(8)](http://man.openbsd.org/nsd), a fast and secure (DNSSEC-enabled) implementation of an authoritative DNS nameserver.

First we should generate a [TSIG](https://en.wikipedia.org/wiki/TSIG) (Transaction SIGnature) key. If using hmac-md5:

    dd if=/dev/urandom of=/dev/stdout count=1 bs=32 | openssl base64
Or for sha256 (preferred):

    dd if=/dev/urandom of=/dev/stdout count=1 bs=64 | openssl base64

Keep the resulting base64-encoded key for later.  For demonstration purposes I will be using the following sha256 key:

    0i96GKeAPxwGZ2ALxrvM882oL107NuCnXLjv4PRpzCS31oySYILYzbs02Aes0OqCgy5+rA96YGep2xFWmzsKHg==

Open **/var/nsd/etc/nsd.conf** and create a simple configuration for our example domain:

    server:
            hide-version: yes
            verbosity: 1
            database: "" # disable database
            
    remote-control:
            control-enable: yes
            control-interface: /var/run/nsd.sock
		    server-key-file: "/var/nsd/etc/nsd_server.key"
		    server-cert-file: "/var/nsd/etc/nsd_server.pem"
		    control-key-file: /var/nsd/etc/nsd_control.key"
		    control-cert-file: "/var/nsd/etc/nsd_control.pem"
		    
    key:
       name: "sec_key"
       algorithm: hmac-sha256 # or hmac-md5
       secret: "0i96GKeAPxwGZ2ALxrvM882oL107NuCnXLjv4PRpzCS31oySYILYzbs02Aes0OqCgy5+rA96YGep2xFWmzsKHg=="
       
    zone:
            name: "foresthall.org.uk"
            zonefile: "master/foresthall.org.uk"
            notify: 192.0.2.69 sec_key
            provide-xfr: 192.0.2.69 sec_key

The IP in the last two lines should be that of your slave. If you are configuring the slave, this IP should be that of the master.

The default base location (OpenBSD users rarely deviate from good defaults!) for zonefiles is **/var/nsd/zones** so we create the file **/var/nsd/zones/master/foresthall.org.uk**:

    $ORIGIN foresthall.org.uk.    ; default zone domain
    $TTL 86400           		  ; default time to live
    
    @ IN SOA ns1.cryogenix.net. foresthall.org.uk. (
               2018010203  ; serial number
               28800       ; Refresh
               7200        ; Retry
               864000      ; Expire
               86400       ; Min TTL
               )
    
            NS      ns1.cryogenix.net.
            NS      ns2.cryogenix.net.
    @        MX    10 mail.foresthall.org.uk.
    www     IN      A       82.35.249.157
    mail    IN      A       82.35.249.157
    @       IN      A       82.35.249.157
See [RFC 1034](https://tools.ietf.org/rfc/rfc1034.txt) and [RFC 1035](https://tools.ietf.org/rfc/rfc1035.txt) if you are unfamiliar with the zone file format.

Next generate the SSL keys for nsd(8):

    $ doas nsd-control-setup
    setup in directory /var/nsd/etc
    generating nsd_server.key
    Generating RSA private key, 3072 bit long modulus
    .++
    ...............++
    e is 65537 (0x10001)
    generating nsd_control.key
    Generating RSA private key, 3072 bit long modulus
    .........................++
    ..++
    e is 65537 (0x10001)
    create nsd_server.pem (self signed certificate)
    create nsd_control.pem (signed client certificate)
    Signature ok
    subject=/CN=nsd-control
    Getting CA Private Key
    Setup success. Certificates created. Enable in nsd.conf file to use
 Check your configuration file contains no errors - this is good practice on a live production server before reloading the config:

	$ doas nsd-checkconf /var/nsd/etc/nsd.conf

 Run nsd(8) in the foreground to check everything is working:

        $ doas nsd -d -V 5
        [2018-10-31 15:51:02.541] nsd[12021]: notice: nsd starting (NSD 4.1.25)
        [2018-10-31 15:51:02.542] nsd[12021]: info: creating unix socket /var/run/nsd.sock
        [2018-10-31 15:51:02.633] nsd[76579]: info: zone foresthall.org.uk read with success
        [2018-10-31 15:51:02.711] nsd[76579]: notice: nsd started (NSD 4.1.25), pid 12021

Now use dig(1) to check that it is serving lookup requests for our new domain:

    voyager$ dig @ns1.cryogenix.net ANY foresthall.org.uk
    ;; Truncated, retrying in TCP mode.
    
    ; <<>> DiG 9.4.2-P2 <<>> @ns1.cryogenix.net ANY foresthall.org.uk
    ; (1 server found)
    ;; global options:  printcmd
    ;; Got answer:
    ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 48761
    ;; flags: qr aa rd; QUERY: 1, ANSWER: 4, AUTHORITY: 0, ADDITIONAL: 1
    ;; WARNING: recursion requested but not available
    
    ;; QUESTION SECTION:
    ;foresthall.org.uk.             IN      ANY
    
    ;; ANSWER SECTION:
    foresthall.org.uk.      86400   IN      SOA     ns1.cryogenix.net. foresthall.org.uk. 2018010203 28800 7200 864000 86400
    foresthall.org.uk.      86400   IN      NS      ns1.cryogenix.net.
    foresthall.org.uk.      86400   IN      MX      10 mail.foresthall.org.uk.
    foresthall.org.uk.      86400   IN      A       82.35.249.157
    
    ;; ADDITIONAL SECTION:
    mail.foresthall.org.uk. 86400   IN      A       82.35.249.157
    
    ;; Query time: 44 msec
    ;; SERVER: 82.35.249.157#53(82.35.249.157)
    ;; WHEN: Wed Oct 31 15:52:25 2018
    ;; MSG SIZE  rcvd: 155

ctrl-C to kill the nsd foreground process then enable and start it as a daemon:

	rcctl enable nsd
	rcctl start nsd

That's it! But we haven't enabled DNSSEC for our zone...

#### Signing our zone with DNSSEC

For this we will need ldns-keygen from [LDNS](https://www.nlnetlabs.nl/projects/ldns/about/):

    $ doas pkg_add ldns-utils

Now we generate keys - a zone-signing key (ZSK) and a key-signing key (KSK):

    $ cd /var/nsd/zones
    $ export ZSK=`/usr/local/bin/ldns-keygen -a RSASHA512 -b 2048 foresthall.org.uk`
    $ export KSK=`/usr/local/bin/ldns-keygen -k RSASHA512 -b 4096 foresthall.org.uk`

DS records were automagically generated, but we will create our own later so delete them:

    $ rm *.ds

Create a signed zone for foresthall.org.uk - this will create master/foresthall.org.uk.signed:

    $ ldns-signzone -n -s $(head -n 1000 /dev/urandom | sha256 | cut -b 1-16) master/foresthall.org.uk $ZSK $KSK

Change foresthall.org.uk's zonefile in **/var/nsd/etc/nsd.conf** to the new signed file:

    zonefile: foresthall.org.uk.signed

Reload our nsd configuration

    $ nsd-control reconfig
    $ nsd-control reload foresthall.org.uk

Now if we lookup our zone with dig, this time specifying DNSKEY, we should get different results that with the DNSSEC sigs:

    dig DNSKEY @ns2.cryogenix.net foresthall.org.uk. +multiline +norec

Generate DS records for our zone and save the result to your clipboard or somewhere:

    $ ldns-key2ds -n -f -2 master/foresthall.org.uk.signed
    foresthall.org.uk.      86400   IN      DS      28892 7 2 fa1b31305013e427a8dac5318fbf6ffcdbfda94309ddf12ebdca101a5e07167d
    foresthall.org.uk.      86400   IN      DS      28316 10 2 1e38d492215cd05a28b8ea64eaf42c82648064b7c563b7ea27eddd9a7e8d69d3

These records must be added at TLD level - as we're using a .org.uk domain, we are covered by nominet's dns*.nic.uk.  Your domain registrar may have a form in their control panel for you to add these DS records, else you may have to contact their customer services. Once the keys have been added, you can check them using dig:

    $ dig DS foresthall.org.uk. +trace +short | egrep '^DS'
    DS 28316 10 2 1E38D492215CD05A28B8EA64EAF42C82648064B7C563B7EA27EDDD9A 7E8D69D3 from server dns1.nic.uk in 29 ms.
    DS 28892 7 2 FA1B31305013E427A8DAC5318FBF6FFCDBFDA94309DDF12EBDCA101A 5E07167D from server dns1.nic.uk in 29 ms.

The easiest way to verify everything is working is to check the domain on [internet.nl](https://en.internet.nl/).

Unfortunately, this setup requires maintenance - the DNSSEC signatures will expire in four weeks (thanks [@Habbie](https://twitter.com/Habbie)!), so some hackery with shell scripts and cron jobs is probably the best solution until something more robust is included in OpenBSD.  One such example is [sign-DNSSEC](https://github.com/wekers/Sign-DNSSEC).

Update: Callum Smith, author of [dank-selfhosted](https://github.com/cullum/dank-selfhosted/) has a very clean script which can be run in a cron nightly [here](https://github.com/cullum/dank-selfhosted/blob/master/roles/nsd/files/resign-zone.sh)

To setup a slave, follow this procedure again - but replace the allow-notify and request-xfr IP with that of the master nameserver.  Once both are up and running, use nsd-control(8) with the force_transfer command to test a zone transfer.
