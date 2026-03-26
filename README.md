## About
This is my own "homelab" yadi yada setup, largely based on: https://codeberg.org/launchpad023/launchpad023-infra/

## Requirements
- kluctl: ahttps://kluctl.io/docs/kluctl/installation/#installation-with-bash
- kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux
- talosctl: https://docs.siderolabs.com/talos/v1.10/getting-started/talosctl#alternative-install

### Additional tools 
- k9s: https://github.com/derailed/k9s/releases/tag/v0.50.18
- kluctl: https://kluctl.io/docs/kluctl/installation/#installation-with-bash



## Install steps


1. Boot from the USB device on the server, and note down its IP address.


Use that IP to access it.
```bash
talosctl gen config biglez https://192.168.1.32:6443/
talosctl get disks --nodes http://192.168.1.32 --insecure
talosctl apply-config --nodes http://192.168.1.32/ --insecure --file talos/controlplane.yaml
talosctl bootstrap -n 192.168.1.32 -e 192.168.1.32 --talosconfig talos/talosconfig
```


Dashboard
```bash
talosctl dashboard --talosconfig ./talos/talosconfig -n 192.168.1.32 -e 192.168.1.32
talosctl services
```


```bash
talosctl apply-config --file talos/controlplane.yaml 
```

### 2026-03-25

Populate the `image-factory.yaml` file.
```bash
curl -X POST --data-binary @talos/image-factory.yaml https://factory.talos.dev/schematics
```

Put the output in `controlplane.yaml` in the `install.image`

Apply the config

```bash
talosctl apply-config --file talos/controlplane.yaml 
```

Installed kernel modules 
```bash
talosctl upgrade --image factory.talos.dev/metal-installer/613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245:v1.12.6
```
