<div align=center>
<img width="175" height="175" alt="image" src="https://github.com/user-attachments/assets/baa7041e-549d-45b0-ae5f-0b444abaaebb" />

# Biglez Cluster
_• Kubernetes on Talos Linux •_
<br />
</div>


This repo contains the configuration for my homecluster running on a *Dell OptiPlex 7050 Micro*, which is a pretty  efficient machine. It consumes about `18w` while idling the currently deployed workloads, with my current energy contract that be around `~50EUR` a year.
The main focus of this setup is to have the cluster _Infrastructure as Code_, which makes it easy to "record" the state of the cluster in git.

Its currently just hosting a [immich](https://immich.app/) instance, with a Hetzner [Storage Box](https://www.hetzner.com/storage/storage-box/) for backups.
For secret management I'm running [External Secrets Operator](https://external-secrets.io/latest/) hooked up to the Free Tier of [Bitwarden Secret Manager](https://bitwarden.com/help/secrets-manager-plans/) paired with [Reloader](https://docs.stakater.com/reloader/latest/)
This setup is large based on the [launchpad023](https://codeberg.org/launchpad023/launchpad023-infra/) config which is a nice example of how to set things up.
<br/>



## Depenencies
Required tools
- [talosctl](https://docs.siderolabs.com/talos/v1.10/getting-started/talosctl#alternative-install) for interacting with the OS running on the server.
- [kluctl](https://kluctl.io/docs/kluctl/installation/#installation-with-bash) doing deployments.
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux) talking to the kubernetes API.
- [CloudNativePG kubectl-plugin](https://cloudnative-pg.io/documentation/1.20/kubectl-plugin/) Accessing the cnpg databases, without fiddling around in a psql pod.

Handy stuff
- [k9s](https://github.com/derailed/k9s/releases/tag/v0.50.18) very nice TUI alternative for kluctl.
- [just](https://github.com/casey/just) simple command runner, used for running the kluctl deployments.

## Talos Installation

I installed talos through a bootable [Ventoy](https://www.ventoy.net/en/download.html) USB stick. Take note if its IP address in the dashboard view (the main screen you see when its running).

It is highy recommended to assign the Talos machine a static ip address, this will prevent head-aches in the future.

Then from another computer run the following commands

Generate the secrets, this only needs to be done once for every install. The secrets will be embedded in the talos manifest/config that we will apply using `just talos-apply` later on. So its important to not loose them.
Thus it is highy recommended to store these in something like bitwarden, which is what I've done.

```bash
# generate the secrets
talosctl gen secrets -o secrets.yaml
# hacky way to store them across multiple `secret-notes` due to their size limit
cat secrets.yaml | split -b 4000
# you can stitch them back togeher like
cat secrets.yaml.pt1 secrets.yaml.pt2 secrets.yaml.pt3 > secrets.yaml
```


With that out of the way, lets get Talos running.

Optionally: edit the variables set in [`Justfile`](./Justfile) to match your setup.

```bash
just talos-init
# wait for previous step to complete, it may reboot.
just talos-bootstrap
# install our manifests
just talos-apply
# try and generate a `kubeconfig`
just kube-config

# get the env variables from the `Justfile`
source set-env.sh
# try the kube access
kubectl get pods -n kube-system
```

Once you can access the cluster through kluctl, you're done with the talos configuration.

### Storing the secrets
The `secrets.yaml` is stored in multiple bitwarden secure notes (due to the 10000 chars size limit, per note)

```bash
cat secrets.yaml.pt1 secrets.yaml.pt2 secrets.yaml.pt3 > secrets.yaml
```

## Deploying to kubernetes
Before running kluctl to deploy we have to prepare some things,
This is really simple, just run.


```
just kluctl-deploy
```

When deploying for the first time, make sure to checkout the [initial cluster setup](#initial-cluster-setup) instructions.



## Initial cluster setup

### ESO Bitwarden setup
I created a "machine account" in Bitwarden Secrets Manager, I used the [Free tier](https://bitwarden.com/products/secrets-manager/#pricing). It allows you to have up to 3 machine-accounts and 3 projects, so its plenty for the home gamer.

The bitwarden access token is not being version controlled (for obvious reasons 🤓), you can create the secret with the following command instead.

```bash
kubectl create secret generic bitwarden-access-token --from-literal=token=$BW_ACCESS_TOKEN -n external-secrets
```

### Initialite restic
I don't have a job setup to initialize the restic repo yet, so for now that's gotta happen manaually.
Initialize the remote restic repo.

```bash
restic -r $RESTIC_REPOSITORY init
```

> [!NOTE]
> The `RESTIC_REPOSITORY` is set in a secret.






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

### Immich restore
This is a semi manual process for now, since I've only done it once.
It involves two steps:
- Downloading the snapshot data down from the hetzner server using restic.
- Restoring the immich database, through the immich web-ui (I suppose you could also script this but this seems easier)
#### Restic restore
1. Manually disable the active immich deployment in [`kustomization.yaml`](kluctl/deployments/immich/kustomization.yaml) by commenting it out. This will ensure that there is no funny business going when writing to the PVC.
1. Create a pod attached to the `immich-user-data` PVC so we can write to it.
3. Start the [`restic-pvc-write.yaml`](utils/restic-pvc-write.yaml) pod, get a shell into it.
4. List the snapshots on the server, `restic snapshots` pick one and run `restic restore <SNAPSHOT-ID|latest> --target /home/photos`. Let it rip, upon completion your data should be downloaded onto the PVC
5. Re-deploy the immich stuff again, and you should now get prompted for a database backup.

Database backup, this is a shitty process because immich wants to have superuser permissions when restoring the DB. This is because it creates some extenions? I haven't read too much into this, but here is a workaround.


#### Database restore
1. Grant our immich user superuser access. `kubectl cnpg -n immich psql immich-database -- app -c "alter user app with superuser;"`
2. Do the database backup through the immich web-ui
3. Revoke the permission `kubectl cnpg -n immich psql immich-database -- app -c "alter user app with nosuperuser;"`.
Super simple, yet quite annoying :)


## Cost savings
More about the costs of running this thing.
For the server's power consumption I assumed a `20h` period of idling and `4h` of max CPU usage (for example when running the immich ML pods)
The yearly costs of running just the server would be the previously mentioned `~50EUR`.

For calculating the server's power consumption I assumed a `20h` period of idling and `4h` of max CPU usage (for example when running the immich ML pods)
Taking those numbers into account the yearly costs of running just the server would be the previously mentioned `~50EUR`.

The Hetzner Storage bucket adds an extra `46.44EUR`, so lets say about `100EUR` a year.
Previously I was using a Hetzner [Nextcloud](https://www.hetzner.com/storage/storage-share/) instance which is absolutely dogshit for hosting photos btw. As an added bonus it also cost `206EUR` a year 🤡🤡🤡


Summary: I'm already saving `~100EUR` this year by running it myself.



## TODO
- [ ] light file server for desktop backups
- [ ] somekind of SSO for all the services I might like to add in the future
- [ ] pi-hole?
- [ ] Add healthcheck.io and markdown badge
- [ ] Fix security warnings when deploying pods
- [ ] Job which initializes the restic repo on the hetzner remote
- [x] Setup ESO
- [x] Setup ESO With reloader, to automagicaclly update secrets when they've changed in bitwarden.
- [ ] Add some kind of variable system, so I can (for example) set the namespace in the generated helm render from external-secrets. Instead of having to run `helm template ..... -n <namespace>` when this namespace is already set in the `kustomization.yaml`
- [x] ~Go through git history and purge any published secrets~ rotate all secrets instead.

---


## Notes 'n Thoughts

### 2026-05-07: Fix stuff fr

Installed ESO like [here](https://github.com/external-secrets/bitwarden-sdk-server#install)
`bitwarden-sdk-server` is currently waiting for the `bitwarden-tls-certs` secrets.


kubectl apply -f bitwarden-sdk-server/hack/cluster_issuer.yaml
kubectl apply -f bitwarden-sdk-server/hack/bitwarden-certificate.yaml -n external-secrets



#### Keys &Certs
- CA.key, private key
- CA.cert, self signed CA Certificate, signed with the private key.
- bitwarden-sdk-server.key, private key for bitwarden-sdk
- bitwarden-sdk-server.csr, certificate-signing-request, signed with the servers (bitwarden-sdk) private key.
- bitwarden-sdk-server.crt, signed (by the CA) certificate get produced from the `bitwarden-sdk-server.csr`, `CA.key` and the `CA.cert`.


### 2026-05-06
Started playing around with using `secrets.yaml` to do a local generation of the credentials, also noticed I pushed some secrets in the `controlplane.yaml`. Fucking dumb, so I'm gonna start generating that file instead using the `secrets.yaml`.

Also, the external-secrets manager is still failing, something with its certs?

### 2026-04-21: Problems :(
- I've noticed that sometimes (about every hour) one of the [ESO](https://external-secrets.io/) pods has an certificate issue.
### Hetzner
The Hetzner storage bucket is just fucking unreachable at random, causing the backups to fail.
When I try to SSH into it from within my LAN I get a `Network is unreachable`, which I don't fully understand because `traceroute` seems to work fine. So its definitely not a DNS issue.
It seems to be a LAN issue, when I use my mobile hot spot the uptime seems to be good.

#### Dig
When running dig I noticed the TTL was 30 seconds, my current theory is that my router has a setting regarding that.


### 2026-04-23: Hetzner
Looks like the hetzner "problem" fixed itself, I talked with the Odido (ISP) people. They were gonna do some black box remote "fixing", they were being very vague about it. After that it seemed to magically work.


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

## Credits / Resources
- [immich certs - reddit](https://old.reddit.com/r/kubernetes/comments/1maptgy/anyone_using_externalsecrets_and_bitwarden/n5gm6or/)
