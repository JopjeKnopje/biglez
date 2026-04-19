<div align=center>
<img width="175" height="175" alt="image" src="https://github.com/user-attachments/assets/baa7041e-549d-45b0-ae5f-0b444abaaebb" />

# Biglez Cluster
_• Kubernetes on Talos Linux •_
<br />
</div>

## Overview
This repo contains the configuration for my homecluster running on a *Dell OptiPlex 7050 Micro*, which is efficient.
The main focus of this setup is to have the infrastructure as code, which makes it easy to "record" the state of the cluster in git.

Its currently just hosting a deadsimple immich instance, but its a nice canvas to run more workloads in the future.
This setup is large based on the [`launchpad023`](https://codeberg.org/launchpad023/launchpad023-infra/) config which proved to be a good example.


## Depenencies
Required tools
- [talosctl](https://docs.siderolabs.com/talos/v1.10/getting-started/talosctl#alternative-install) for interacting with the OS running on the server.
- [kluctl](https://kluctl.io/docs/kluctl/installation/#installation-with-bash) doing deployments.
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux) talking to the kubernetes API.

Handy stuff
- [k9s](https://github.com/derailed/k9s/releases/tag/v0.50.18) very nice TUI alternative for kluctl.
- [just](https://github.com/casey/just) simple command runner, used for running the kluctl deployments.

## Installation

I installed talos through a bootable [Ventoy](https://www.ventoy.net/en/download.html) USB stick. Take note if its IP address in the dashboard view (the main screen you see when its running).

Then from another computer run the following commands

```bash
# save the IP address in your env
export TALOS_IP=192.168.1.14
```

Find out what disks are avaliable, so we can later set it as our install location.

```bash
talosctl get disks --nodes http:/$TALOS_IP --insecure
```

Generate the talosconfig this will generate both a `controlplane.yaml` and `worker.yaml`. Since I'm just running 1 node, that node will be both the controlplane and the worker.
In order for this to work you need to set `cluster.allowSchedulingOnControlPlanes: true`.

```bash
talosctl gen config biglez https://$TALOS_IP:6443/
```

Make some other changes to the config if You wish to do so, and apply it.

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
Once you can access the cluster through kluctl, you're done with the talos configuration.

### Deploying
This is really simple, just run.
```
just kluctl-deploy
```

When deploying for the first time, make sure to checkout the [initial cluster setup](#initial_cluster_setup) instructions.



## Handy commands
```bash
# same view as the one being output on the display output
talosctl dashboard
talosctl services
```


## Initial cluster setup
### Restic backup
I don't have a job setup to initialize the restic repo yet, so for now that's gotta happen manaually.

```bash
restic -r $RESTIC_REPOSITORY init
```

> [!NOTE]
> The `RESTIC_REPOSITORY` is set in a secret.


### External Secrets Bitwarden setup
I created a "machine account" in Bitwarden Secrets Manager, I used the [Free tier](https://bitwarden.com/products/secrets-manager/#pricing). It allows you to have up to 3 machine-accounts and 3 projects, so its plenty for the home gamer.

The bitwarden access token is not being version controlled (for obvious reasons 🤓), you can create the secret with the following command instead.

```bash
kubectl create secret generic bitwarden-access-token --from-literal=token=$BW_ACCESS_TOKEN -n <NAMESPACE>
```




## Handy commands
Here are some commands I've found useful when working on this, some of these commands will later be automated.
### Refreshing external-secrets
You can just delete it, the CRD will create a new one, or run the following command

```bash
kubectl annotate es <NAME> force-sync=$(date +%s) --overwrite -n <NAMESPACE>
```

### Restic backup
Manually fire a cronjob
```
kubectl create job --from=cronjob/<cronjob-name> <job-name> -n <namespace-name>
```

## TODO
- [ ] Fix security warnings when deploying pods
- [x] Setup ESO
- [x] Setup ESO With reloader, to automagicaclly update secrets when they've changed in bitwarden.
- [ ] Add some kind of variable system, so I can (for example) set the namespace in the generated helm render from external-secrets. Instead of having to run `helm template ..... -n <namespace>` when this namespace is already set in the `kustomization.yaml`
- [x] ~Go through git history and purge any published secrets~ rotate all secrets instead.



## Notes 'n Thoughts

### 2026-04-19: Bitwarden
I Installed ESO and the [bitwarden-sdk-server](https://external-secrets.io/latest/provider/bitwarden-secrets-manager/)
https://wiki.privatetrace.io/en/Kubernetes/Security/external-secrets
https://external-secrets.io/latest/provider/bitwarden-secrets-manager/

### 2026-04-18: Got rid of volsync
Set up a cronjob for running restic instead, volsync didn't offer any actual support for the SFTP backend of restic. Mainly because you couldn't mount the ssh-config file in a VolSync spawned pod. I didn't wanna switch to hetzner s3 buckets because that would double the price.

https://dave.gv.ca/posts/kubernetes-restic/#always-check-your-logs

#### Upload ssh key to hetzner
I was being lazy, before creating the storage-box I added a secondary SSH-key to hetzner specifically for the backup service.

If you want you can also use something like.
```bash
ssh-copy-id -p 23 -i ~/.ssh/hetzner_immich.pub -s hetzner
```

> [!note]
> I've added `hetzner` to my `~/.ssh/config` file here.


### 2026-04-16: Restic secret setup

Creating the secret. I should probably use an external secret manager for this, like bitwarden.
```bash
kubectl -n immich create secret generic restic-config
--from-literal=RESTIC_REPOSITORY=hetzner/immich
--from-literal=RESTIC_PASSWORD=<password>
--from-file=id_rsa=/home/joppe/.ssh/hetzner_immich
--from-file=ssh-config=$PWD/klusrc/deployments/immich/ssh-config
--dry-run=client -o=yaml | xclip
```

- https://docs.hetzner.com/storage/storage-box/backup-space-ssh-keys/
- https://github.com/backube/volsync/issues/671

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
