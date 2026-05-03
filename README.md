# AWUS036ACM_Setup

**Alfa AWUS036ACM (MT7612U) Setup Payload for the WiFi Pineapple Pager**

Sets up the Alfa AWUS036ACM external WiFi adapter in monitor mode with configurable channel hopping. Adapter and hopper persist after the payload exits so you can run other payloads immediately without reconfiguration.

---

## Compatible Hardware

- **Alfa AWUS036ACM** — MediaTek MT7612U chipset (USB ID `0e8d:7612`)
- WiFi Pineapple Pager

---

## Modes

| Mode | Channels | Dwell | Use Case |
|------|----------|-------|----------|
| Wardrive Hop 1/6/11 | 1, 6, 11 | 350ms | Flock Safety detection, standard wardriving |
| Wardrive Full Hop 1-13 | 1–13 | 500ms | Broad 2.4GHz coverage |
| Wardrive 5GHz | 36–165 | 400ms | 5GHz network discovery |
| Passive ch6 (StamenScan) | 6 (fixed) | — | Passive capture, StamenScan compatible |
| Disable / Cleanup | — | — | Kill hopper and remove wlan2mon |

---

## How it works

1. Detects AWUS036ACM by USB vendor/product ID
2. Finds the external phy by excluding internal Pager radio OUIs (`00:13:37`)
3. Creates `wlan2mon` in monitor mode
4. Starts a detached channel hopper process that persists after payload exits
5. Other payloads can use `wlan2mon` immediately

Run again and select **Disable / Cleanup** to kill the hopper and remove `wlan2mon`.

---

## Installation

```
/root/payloads/user/general/AWUS036ACM_Setup/
└── payload.sh
```

---

## Usage with other payloads

**StamenScan** — run this payload first in Passive ch6 mode, then run StamenScan. It will auto-detect `wlan2mon` and prefer it over internal interfaces.

**Wardrive payloads** — run in any hop mode before starting your wardrive session. `wlan2mon` will be available as a second monitor interface.

---

## Notes

- The channel hopper PID is saved to `/tmp/awus_hop.pid`
- If the adapter is unplugged the hopper will exit on its own
- The `external-mediatek-radio-loader` payload is **not required** — this payload handles setup independently
- Does not interfere with the Pager's internal radios (`wlan0mon`, `wlan1mon`)

---

## Author

**FusedStamen**

---

## Disclaimer

For use with authorized security research and wardriving only. Always comply with local laws regarding wireless scanning.
