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

I installed talos through a bootable [Ventoy](https://www.ventoy.net/en/download.html) USB stick, then once its running take note if its IP address in the dashboard view (the main screen you see when its running).

Then from another computer run the following commands

```bash
# save the IP address in your env
export TALOS_IP=192.168.1.13
```


find out what disks are avaliable, so we can later set it as our install location.

```bash
talosctl get disks --nodes http:/$TALOS_IP --insecure
```



Generate the talos config this will generate both a controlplane.yaml and worker.yaml. Since I'm just running 1 node, that node will be both the controlplane and the worker.
In order for this to work you need to set `cluster.allowSchedulingOnControlPlanes: true`.

```bash
talosctl gen config biglez https://$TALOS_IP:6443/
```


Make some other changes to the config if you wish to do so, and apply it.

```bash
talosctl apply-config --nodes http://$TALOS_IP/ --insecure --file talos/controlplane.yaml
# get the newly acquired configs into our env
source set-env.sh
# setup the k8s server
talosctl bootstrap
# generate kubeconfig
talosctl kubeconfig
# access it
kubectl get pods -n kube-system
```


## Handy commands
```bash
# same view as the one being output on the display output
talosctl dashboard
talosctl services
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
