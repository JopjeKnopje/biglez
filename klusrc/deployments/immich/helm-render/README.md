I rendered a helm chart manually using the following command
```

```bash
helm template --namespace immich immich oci://ghcr.io/immich-app/immich-charts/immich -f values.yaml > install.yaml
```

Now we can just apply it using kluctl
