# Live Setup on an Existing Raspberry Pi Zero OS

This guide configures USB HID gadget mode (keyboard + mouse) on a Pi Zero that is already running Raspberry Pi OS.

Use this when you do **not** want to build a new image and just want to install on the live system.

## What this does

The installer script:

- installs `usb-hid-gadget.sh` to `/usr/local/sbin/`
- installs `hid-postboot-verify.sh` to `/usr/local/sbin/`
- installs and enables `hid-gadget.service`
- ensures boot config includes `dtoverlay=dwc2,dr_mode=peripheral`
- ensures kernel cmdline includes `modules-load=dwc2`
- optionally writes `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf`

## Requirements

- Raspberry Pi Zero / Zero W / Zero 2 W with Raspberry Pi OS already booting
- sudo/root access
- internet access on the Pi (to clone/pull this repo)
- a USB data cable connected to the Pi's USB OTG/data port (not power-only port)

## 1) Get the project on the Pi

If you already have this repo on the Pi, skip to step 2.

```bash
git clone <your-repo-url> ~/pizero_hid
cd ~/pizero_hid
```

If already cloned:

```bash
cd ~/pizero_hid
git pull
```

## 2) Run live setup

```bash
cd ~/pizero_hid
chmod +x ./setup-live-pizero.sh
sudo ./setup-live-pizero.sh
```

Expected result:

- script completes with `Setup complete. Reboot required: sudo reboot`

## 3) Reboot

```bash
sudo reboot
```

After reboot, keep the Pi connected through the USB OTG/data port to the host machine.

## 4) Verify HID state

Run:

```bash
sudo /usr/local/sbin/hid-postboot-verify.sh
```

Successful verification should report:

- `hid-gadget.service` enabled and active
- `/dev/hidg0` exists
- `/dev/hidg1` exists
- `HID verification PASSED`

## Optional: apply Wi-Fi config during setup

By default, `setup-live-pizero.sh` does not change Wi-Fi config.

To write `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf` during setup:

```bash
sudo APPLY_WIFI=1 WIFI_SSID="your_ssid" WIFI_PSK="your_psk" WIFI_COUNTRY="US" ./setup-live-pizero.sh
```

Then reboot and verify as above.

## Quick troubleshooting

Check service logs:

```bash
sudo systemctl status hid-gadget.service --no-pager
journalctl -u hid-gadget.service -b --no-pager
```

Check UDC availability (required for gadget bind):

```bash
ls /sys/class/udc
```

If host does not see HID:

- confirm cable supports data (not charge-only)
- confirm connected to Pi USB OTG/data port
- reboot Pi after any boot config changes

## Rollback (disable HID gadget)

```bash
sudo systemctl disable --now hid-gadget.service
```

Optional cleanup:

```bash
sudo rm -f /etc/systemd/system/hid-gadget.service
sudo rm -f /usr/local/sbin/usb-hid-gadget.sh
sudo rm -f /usr/local/sbin/hid-postboot-verify.sh
sudo systemctl daemon-reload
```

If needed, manually remove added boot options from:

- `/boot/firmware/config.txt` (or `/boot/config.txt`)
- `/boot/firmware/cmdline.txt` (or `/boot/cmdline.txt`)
