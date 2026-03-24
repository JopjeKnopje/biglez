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
talosctl --talosconfig ./talosconfig -n 192.168.1.32 -e 192.168.1.32 services
```


```bash
talosctl apply-config --nodes 192.168.1.32 -e 192.168.1.32 --file talos/controlplane.yaml --talosconfig talos/talosconfig
```
