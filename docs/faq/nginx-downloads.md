# Nginx Downloads Setup (HTTP/HTTPS)

Use this to let clients download your custom map `.pk3` files over HTTP(S).

## Folder layout

Example:

```text
/var/www/mohaa/
  mp_snipervalley.pk3
  othermaps.pk3
```

This maps to URLs like:

- `http://yourdomain.com/mohaa/mp_snipervalley.pk3`
- `https://yourdomain.com/mohaa/mp_snipervalley.pk3`

## Nginx config (example)

```nginx
# HTTP (legacy/original clients)
server {
    listen 80;
    server_name yourdomain.com;
    root /var/www;

    location /mohaa/ {
        types { }
        default_type application/octet-stream;
        sendfile on;
        tcp_nopush on;
        add_header Cache-Control "public, max-age=86400";
    }
}

# HTTPS (OpenMohaa-friendly)
server {
    listen 443 ssl;
    server_name yourdomain.com;
    root /var/www;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    location /mohaa/ {
        types { }
        default_type application/octet-stream;
        sendfile on;
        tcp_nopush on;
        add_header Cache-Control "public, max-age=86400";
    }
}
```

## TLS certificates (Let's Encrypt)

```bash
sudo apt update
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

## Validate Nginx setup

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Server config

Set the base URL in `.env` and restart:

```bash
DOWNLOAD_URL=https://yourdomain.com/mohaa
```

The kit then sets `sv_allowDownload 1` and `sv_dlURL` to that URL. Put the
same `.pk3` files in `custom/` so the server loads them.

Only host files you are allowed to redistribute. Never host the game's own
`pak*.pk3` files.
