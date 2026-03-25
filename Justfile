export KLUCTL_PROJECT_DIR := "klusrc"
export KLUCTL_TARGET := "biglez"
export KLUCTL_PRUNE := "true"
export KUBECONFIG := "talos/kubeconfig"



kluctl-deploy:
	kluctl deploy --prune --replace-on-error
