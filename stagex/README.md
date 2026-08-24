# StageX build

This is a StageX `user` package definition for the native Linux artifact. It
targets StageX commit `9bdf430d09ce2ba53932df0182faef00d4feecd1`;
`stagex.lock` records the expected amd64 dependency-image digests.

Copy this directory to `packages/user/stack-wallet-sparkmobile` in a checkout
of that StageX revision, add it to the Git index, then run:

```sh
make fetch PKG=stack-wallet-sparkmobile
make user-stack-wallet-sparkmobile NOCACHE=1
python3 src/package-digests.py user-stack-wallet-sparkmobile
```

Repeat the build on an independent machine and compare the image digest. The
plugin and Boost archives are SHA-256 locked, all compilation is performed
with `--network=none`, and StageX supplies dependencies as content-addressed
OCI contexts.
