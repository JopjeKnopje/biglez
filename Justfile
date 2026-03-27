export KLUCTL_PROJECT_DIR := "klusrc"
export KLUCTL_TARGET := "biglez"
export KLUCTL_PRUNE := "true"
export KUBECONFIG := "talos/kubeconfig"



kluctl-deploy:
	kluctl deploy --prune --replace-on-error

talos-apply:
	talosctl apply-config --file talos/controlplane.yaml 
talos-patch:
	talosctl patch mc --patch @talos/user-volume-config.yaml
