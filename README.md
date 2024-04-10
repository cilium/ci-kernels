# ci-kernels

A collection of kernels used for CI builds.

1. Update kernel versions in [versions.json](versions.json)
2. Commit and make a PR.

You can approximate CI by running `buildx.sh`:

```shell
$ ./buildx.sh 6.1 amd64 vmlinux --tag foo:vmlinux
```

## Updating versions

Use `update-version.sh` (requires `jq`):

```shell
./update-versions.sh
```

## Updating the configuration

The configuration consists of common options in [config](./config) and platform
specific options in [config-arm64](./config-arm64) and [config-x64_64](./config-x86_64).

To add a new config option:

1. Try adding it to `config` (keep sorted alphabetically)
2. In a checkout of the Linux source code:
   ```shell
   TARGETPLATFORM=linux/arm64 /path/to/configure-vmlinux.sh
   ```
3. If any symbols are missing you can now run `make menuconfig` and search for
   the missing symbols. Figure out which dependencies are missing and add them
   to the config as well.

Add the config to the arch specific files if it isn't available in general.

## Updating the builder

The builder image is still built manually.

1. `make image`
2. `make push`
3. Add files, commit and make a PR.
