CLUSTER_NAME		:= "biglez"
CONTROL_PLANE_IP	:= "192.168.1.14"
NODE_IP				:= CONTROL_PLANE_IP
TALOSCONFIG			:= "./talosconfig"
KUBECONFIG			:= "./kubeconfig"
GENERATED_MANIFEST	:= "controlplane-generated.yaml"


export KLUCTL_PROJECT_DIR := "klusrc"
export KLUCTL_TARGET := CLUSTER_NAME
export KLUCTL_PRUNE := "true"



_talos-gen-manifest:
    talosctl gen config --with-secrets secrets.yaml \
      --kubernetes-version 1.35.2 \
      --talos-version 1.12.6 \
      --config-patch-control-plane talos/controlplane.yaml \
      --config-patch @talos/patches/local-path-volume.yaml \
      --config-patch @talos/patches/hostname.yaml \
      --output-types controlplane --output {{GENERATED_MANIFEST}} --force \
      {{CLUSTER_NAME}} https://{{CONTROL_PLANE_IP}}:6443

# generate the `talosconfig` based on the `secrets.yaml` file
talos-config:
    talosctl gen config --with-secrets secrets.yaml \
      --output-types talosconfig --output {{TALOSCONFIG}} \
      {{CLUSTER_NAME}} https://{{CONTROL_PLANE_IP}}:6443 --force
    talosctl config endpoint {{CONTROL_PLANE_IP}} --talosconfig={{TALOSCONFIG}}
    talosctl config node {{NODE_IP}} --talosconfig={{TALOSCONFIG}}

# apply our config for the first time on a cluster
talos-init: _talos-gen-manifest
    talosctl apply-config --insecure --file {{GENERATED_MANIFEST}} -e {{CONTROL_PLANE_IP}} -n {{NODE_IP}} --context {{CLUSTER_NAME}}
    rm controlplane-generated.yaml

# bootstrap kube cluster, this should be ran after `talos-init`
talos-bootstrap: talos-config
	talosctl bootstrap --talosconfig={{TALOSCONFIG}}

talos-apply: talos-config _talos-gen-manifest
    talosctl --context {{CLUSTER_NAME}} apply-config --file {{GENERATED_MANIFEST}} --talosconfig={{TALOSCONFIG}}
    rm controlplane-generated.yaml

kube-config: talos-config
	talosctl kubeconfig -n {{NODE_IP}} --talosconfig={{TALOSCONFIG}} {{KUBECONFIG}}

kluctl-deploy:
	kluctl deploy --prune --replace-on-error --kubeconfig={{KUBECONFIG}}
