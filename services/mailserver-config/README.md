# docker-mailserver (reference config)

This directory holds the docker-mailserver configuration that is referenced by
the main `compose.yml` (`mailserver` service). docker-mailserver is checked out
as a git **submodule** at `../docker-mailserver` (upstream:
`docker-mailserver/docker-mailserver`) for its `setup.sh` management tooling.

## Layout

- `mailserver.env` — the env config for the `mailserver` service
  (`compose.yml` -> `env_file: ./services/mailserver-config/mailserver.env`). This is the
  **tracked, authoritative** config.
- The `mailserver` service is defined directly in the root `compose.yml` (no
  separate compose project). It reuses the existing `traefik` named volume for
  its TLS cert (reads `acme.json` natively) and stores mail data under
  `docker/mailserver/docker-data/dms/` (gitignored).
- The submodule checkout (`services/docker-mailserver`) is used only for
  `setup.sh` (accounts, DKIM). Its own `compose.yaml`/`mailserver.env` are not
  used at runtime.

## Startup / operation

```bash
# 1. Start the whole stack (includes traefik -> issues mail.<BASE_DOMAIN> cert
#    via the `mailcert` placeholder router, then mailserver):
docker compose up -d

# 2. Create the SMTP relay account used by AppFlowy and generate DKIM:
cd services/docker-mailserver
./setup.sh email add no-reply@<your-domain> <password>
./setup.sh config dkim        # paste the DKIM TXT record into DNS

# 3. Wire AppFlowy to send through the relay:
#    edit services/appflowy/.env -> GOTRUE_SMTP_* and APPFLOWY_MAILER_SMTP_*
#    (host mail.<your-domain>:587, user no-reply@<your-domain>, same password)
```

## Before going live — replace the `mail.example.com` / `example.com` placeholders

- `services/mailserver-config/mailserver.env` -> `SSL_DOMAIN=`, `POSTMASTER_ADDRESS=`
- `services/appflowy/.env` -> `GOTRUE_SMTP_HOST`, `APPFLOWY_MAILER_SMTP_HOST`, etc.

and set `BASE_DOMAIN` in the root `.env` (used by compose interpolation, e.g. the
`mailserver` hostname and the `mailcert` Traefik router).

## DNS records required (your domain)

- `A      mail.<domain>   <server ip>`
- `MX     <domain>        mail.<domain>`
- SPF:   `v=spf1 mx -all`
- DKIM:  from `./setup.sh config dkim`
- DMARC: `v=DMARC1; p=quarantine; rua=mailto:postmaster@<domain>`
- PTR/rDNS for the server IP -> `mail.<domain>` (with your hosting provider)
