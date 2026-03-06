# ar0234 MIPI NVIDIA driver

![JetPack 6.2.1](https://img.shields.io/badge/JetPack_6.2.1-L4T_36.4.4-brightgreen?logo=nvidia&logoColor=white)
![JetPack 6.2.2](https://img.shields.io/badge/JetPack_6.2.2-L4T_36.5.0-brightgreen?logo=nvidia&logoColor=white)

## Quickstart

Connect camera to `cam0` port.

> [!NOTE]
> Currently, only `cam0` port support is implemented.

---

Install required tools:

```bash
sudo apt install -y dkms
```

Clone the repository to your Jetson machine and navigate to the cloned directory:

```bash
cd ~
git clone https://github.com/Kurokesu/ar0234-mipi-nvidia.git
cd ar0234-mipi-nvidia/
```

---

Build and install:

```bash
sudo ./setup.sh
```

The setup script:
- Fetches NVIDIA device tree headers
- Installs the kernel module via [DKMS](https://github.com/dell/dkms), which automatically rebuilds the module and device tree overlay when the kernel is updated
- Builds and installs the device tree overlay (`.dtbo`) to `/boot` via a DKMS post-install hook

---

To install the ISP tuning file, run:

```bash
sudo cp ./tuning/camera_overrides.isp /var/nvidia/nvcam/settings
```

To uninstall and restore the default ISP parameters, remove the overrides file:

```bash
sudo rm /var/nvidia/nvcam/settings/camera_overrides.isp
```

---

Use the Jetson-IO tool to configure the CSI connector:

```bash
sudo /opt/nvidia/jetson-io/jetson-io.py
```

Navigate through the menu:
1. Configure Jetson CSI Connector (named "22pin" on 6.2.2, "24pin" on 6.2.1)
2. Configure for compatible hardware
3. Select Camera AR0234-A

![jetson-io-tool](./img/jetson-io-tool.png "jetson-io-tool")

4. Save pin changes
5. Save and reboot to reconfigure pins

---

After reboot verify that the sensor is detected over I2C:

```bash
sudo dmesg | grep ar0234
```

![dmesg-ar0234](./img/dmesg.png "dmesg-ar0234")

## Image output

### GStreamer

```bash
gst-launch-1.0 -e nvarguscamerasrc sensor-id=0 ! \
   'video/x-raw(memory:NVMM),width=1920,height=1200,framerate=30/1' ! \
   queue ! nvvidconv ! queue ! nveglglessink
```

### NVIDIA sample camera capture application

```bash
nvgstcapture-1.0 --sensor-id 0
```

## Test mode

The sensor has a built-in test pattern generator that can be used to verify data validity.

After running `sudo ./setup.sh` the driver is installed and loaded automatically at boot.  
The `test_mode` module parameter can then be controlled at runtime via sysfs:

```bash
# 100% color-bar test pattern (test_mode = 2)
echo 2 | sudo tee /sys/module/nv_ar0234/parameters/test_mode
```

To turn the test pattern off:

```bash
echo 0 | sudo tee /sys/module/nv_ar0234/parameters/test_mode
```

| Test pattern code | Description |
| ----------------- | ----------- |
| 0 | Off (normal operation) |
| 1 | Solid color |
| 2 | 100% color bar |
| 3 | Fade-to-grey color bar |
| 256 | Walking 1s (10-bit) |

## Development builds

For manual builds without DKMS:

```bash
make              # build everything (dtbo + kernel module)
sudo make install # copy dtbo to /boot, rmmod + insmod the module
```

> [!NOTE]
> The module is loaded immediately via `insmod` but won't persist across reboots. Use `sudo ./setup.sh` for permanent installation via DKMS.

Individual targets:

```bash
make dtbo      # build only the device tree overlay
make module    # build only the kernel module
make clean     # remove build artifacts
```

All build artifacts are placed in the `./build` directory.
