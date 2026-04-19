## Download CRDs.yaml
installed the crds with
```bash
curl -O https://raw.githubusercontent.com/external-secrets/external-secrets/<VERSION>/deploy/crds/bundle.yaml
```


## Render install.yaml
```bash
helm template external-secrets external-secrets/external-secrets -n external-secrets -f helm-render/values.yaml > helm-render/install.yaml
```
