# How Aruba Onboard enrollment works (reverse-engineered)

Derived from the official Linux client (`onboard-cli`, a Go binary): its Go symbol table
(`hpe.com/aruba/onboard/linux/common/data.*`) and disassembly of the request builders, then
verified against the live server. No traffic was decrypted or intercepted. Nothing here is a
secret: all values below are placeholders.

## Overview

The portal's "Install using ... Onboard app" button navigates to an `arubadp://` link. The app
turns it into a client certificate via **EST (RFC 7030)** and writes a Wi-Fi profile.

```
arubadp://<host>/provision?data=<base64url JSON>
          JSON = { "token": "CBT1....", "config_endpoint": "https://<host>/portal/scope.cust-<id>/cda-user-portal/client/config" }
```

## Sequence

| # | Request | Auth | Result |
|---|---|---|---|
| 1 | `GET config_endpoint` | `Authorization: Bearer <bootstrap token>` | JSON of endpoints: `token_endpoint`, `passpoint_endpoint`, `userinfo_endpoint`, `est_endpoint`, ... |
| 2 | `POST token_endpoint` body `{}` | `X-CloudGuest-API-Key: <bootstrap token>` | `{"access_token": "CBT1...."}`. **The bootstrap token is single use.** |
| 3 | `POST passpoint_endpoint` body `{}` | `X-CloudGuest-API-Key: <access token>` | Profile: `ssid`, `realm`, `recommended_identity`, `username`, `server_trust_ca` (PEM), `est_endpoint`, `est_token`, `refresh_at` |
| 3b | `GET userinfo_endpoint` | `X-CloudGuest-API-Key: <access token>` | `organization_name`, `username`, `display_name` (optional) |
| 4 | `GET <est>/csrattrs` | `Authorization: Bearer <est_token>` | base64 DER: EC P-384, ECDSA-SHA384 (+ challengePassword OID) |
| 5 | `GET <est>/cacerts` | `Authorization: Bearer <est_token>` | `application/pkcs7-mime`, base64 DER certs-only PKCS#7 |
| 6 | `POST <est>/simpleenroll` | `Authorization: Bearer <est_token>`, `Content-Type: application/pkcs10` | base64 DER PKCS#7 containing the client certificate |

Notes:
- Header names differ per step: the config call uses `Authorization: Bearer`, the API calls use
  `X-CloudGuest-API-Key`, EST uses `Authorization: Bearer`.
- Sending any plausible `User-Agent` works; the official client sends OS, kernel and device info.
- The client **generates its own key**, so the PKCS#12 password is client-side and random
  (`GenerateRandomPassword` in the binary). It never travels from the server. The old
  "capture the password from D-Bus" workaround is unnecessary.
- Subject of the issued cert: `O=<scope id>, OU=<org>, CN=<user email>`; validity 1 year.
- No machine-id binding was observed on the server side in this flow.

## Network profile

EAP-TLS, WPA2-Enterprise, identity `anonymous@<realm>`, CA = `server_trust_ca`, client cert + key.
In NetworkManager: `wifi-sec.key-mgmt wpa-eap`, `802-1x.eap tls`, `802-1x.phase1-auth-flags 1`.

## Why the official client doesn't run on ARM

`onboard-ui` (Qt5) and `onboard-cli`/`onboard-srv` (Go) are x86-64 ELF only. On Asahi (16K pages)
they need FEX inside `muvm`, and the Go binaries segfault there. The native tool avoids all of it.
