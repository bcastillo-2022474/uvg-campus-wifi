# UVG CAMPUS CENTRAL Wi-Fi on any Linux (x86_64, aarch64/Asahi, ...)

Native enrollment for the UVG **CAMPUS CENTRAL** 802.1X (EAP-TLS) network. HPE's official Onboard
client is x86-64 only and closed source. This tool talks to the same Aruba CloudGuest API directly,
so it runs on **any architecture** with no emulation (developed and tested on Fedora Asahi Remix 43,
aarch64, Apple Silicon).

## Use it

```bash
git clone <this repo> && cd uvg-aruba-onboard-native
./install.sh
```

That installs the tool, registers it as the `arubadp://` link handler and opens the enrollment portal.
There: **"Yes, I already have HPE Aruba Networking Onboard"** → **"Install using HPE Aruba Networking
Onboard app"** → allow the browser to open the link. A terminal shows the enrollment. Then, on campus:

```bash
nmcli connection up "UVG CAMPUS CENTRAL"
```

Needs: `python3`, `openssl`, NetworkManager + wpa_supplicant (not iwd). Internet is required only for
enrollment, and you don't need to be on campus.

Uninstall: `./install.sh --remove` (certs in `~/.aruba-onboard` and the NM profile stay).

## If the browser doesn't offer to open the link

Firefox/Chromium will only prompt once a handler for `arubadp://` is registered (`install.sh` does it).
Otherwise get the link yourself, save it to `~/arubadp-link.txt` and run `aruba-native-enroll`.
`aruba-native-enroll --no-nm` only downloads certs and skips NetworkManager.

## Good to know

- The enrollment link is **single use** and short-lived. If it fails, get a fresh one from the portal.
- Certificates last **1 year**. Re-run enrollment with a new link before they expire.
- Credentials: `~/.aruba-onboard/` (mode 600): CA, client cert, PKCS#12 key with a random 32-char
  password that is also stored in the NM profile.
- File names have no spaces on purpose: `nmcli` splits `802-1x.private-key "<file> <password>"`
  on whitespace (the original x86 package's helper breaks on this).
- Works with SELinux enforcing (tested on Fedora); no policy changes needed.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `token exchange returned HTTP 401` | Link already used/expired: get a new one from the portal |
| `cannot reach ...` | You need internet during enrollment (phone hotspot is fine) |
| `eapFail` / `reason: 23` | iwd is in use: `sudo systemctl disable --now iwd`, use NetworkManager |
| Connect fails after enrolling | `journalctl -u NetworkManager -u wpa_supplicant --since "-3 min"` |
| Network not visible | Not in range of campus APs; enrollment still works anywhere |

How it works: [docs/PROTOCOL.md](docs/PROTOCOL.md). Machine-readable contract: [docs/openapi.yaml](docs/openapi.yaml).

## Disclaimer

Unofficial, not affiliated with HPE Aruba or UVG. It only does what the official client does, with
your own account, against your university's own portal.
