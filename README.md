# ci-kernels

A collection of kernels used for CI builds, focusing on testing user space
tools for networking and eBPF.

The output of this project are [vimto](https://github.com/lmb/vimto)-compatible
OCI images pushed to
[ghcr.io/cilium/ci-kernels](https://ghcr.io/cilium/ci-kernels).

## Supported Versions

Here's an up-to-date list of supported Linux kernel images available in the
registry. Older images may be cleaned up at any time.

The latest images in each channel receive a floating tag for those not
particular about targeting specific versions.

<!-- This table is maintained by `update-versions.py`, do not edit. -->
<!-- versions:begin -->
| Version | Channel | Image | Tag |
|---|---|---|---|
| 7.3-rc4 | mainline | `ghcr.io/cilium/ci-kernels:7.3-rc4` | mainline |
| 7.2.7 | stable | `ghcr.io/cilium/ci-kernels:7.2.7` | stable |
| 6.18.53 | longterm | `ghcr.io/cilium/ci-kernels:6.18.53` | longterm |
| 6.12.111 | longterm | `ghcr.io/cilium/ci-kernels:6.12.111` |  |
| 6.6.157 | longterm | `ghcr.io/cilium/ci-kernels:6.6.157` |  |
| 6.1.188 | longterm | `ghcr.io/cilium/ci-kernels:6.1.188` |  |
| 5.15.221 | longterm | `ghcr.io/cilium/ci-kernels:5.15.221` |  |
| 5.10.270 | longterm | `ghcr.io/cilium/ci-kernels:5.10.270` |  |
<!-- versions:end -->

Images are built for `linux/amd64` and `linux/arm64` targets.

## Running with `vimto`

[vimto](https://github.com/lmb/vimto) is a tool for running interactive programs
in microVMs. Running Go tests in a sandboxed kernel using a ci-kernels image is
as simple as:

`vimto -kernel ghcr.io/cilium/ci-kernels:7.2.7 -- go test . -v`

See `vimto --help` for more information.

## Bumping Kernel Versions

1. `./scripts/update-versions.py`
2. Commit and make a PR.

## Building Locally

You can approximate CI by running `scripts/buildx.sh`:

```shell
$ ./scripts/buildx.sh 6.1 amd64 vmlinux --tag foo:vmlinux
```

To inspect the result of a build:

```shell
$ ./scripts/buildx.sh 6.1 amd64 build-vmlinux-debug
...
 => => writing image sha256:18d00182c5495376d87dfef5a4363a1b2cbd936af4f893ab437ce006b0f893d4                             0.0s
$ docker run -it sha256:18d00182c5495376d87dfef5a4363a1b2cbd936af4f893ab437ce006b0f893d4
root@1a64a0ade637:/usr/src/linux#
```

## Publishing images manually

CI builds candidate images on pull requests, named after the kernel version plus
a hash of the [build](./build) directory. Merging to main normally just retags
the already-tested candidates. If that fails (e.g. for fork PRs, which cannot
push candidates), promotion falls back to building on main. To break-glass the
process by hand from the merged commit:

```shell
$ docker login ghcr.io
$ ./scripts/buildx.sh 6.12.111 amd64,arm64 vmlinux --tag "ghcr.io/cilium/ci-kernels:$(./scripts/candidate-tag.sh 6.12.111)" --push
$ ./scripts/promote.sh 6.12.111
```

## Updating the configuration

The configuration consists of common options in [config](./build/config) and
platform specific options in [config-arm64](./build/config-arm64) and
[config-x64_64](./build/config-x86_64).

To add a new config option:

1. Try adding it to `build/config` (keep sorted alphabetically)
2. In a checkout of the Linux source code:
   ```shell
   TARGETPLATFORM=linux/arm64 /path/to/build/configure-vmlinux.sh
   ```
3. If any symbols are missing you can now run `make menuconfig` and search for
   the missing symbols. Figure out which dependencies are missing and add them
   to the config as well.

Add the config to the arch specific files if it isn't available in general.

## Updating the builder

The builder image is still built manually.

1. `make builder`
2. Test a build via instruction above.
3. `make push`
4. Add files, commit and make a PR.
