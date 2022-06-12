# ci-kernels

A collection of kernels used for CI builds. You'll need [podman]() to run the build.

1. Update kernel versions in `make.sh`
2. `make`
3. Add new files, commit and make a PR.

# Updating the builder

1. `make image`
2. `make push`

[podman]: https://podman.io/
