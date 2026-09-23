# build

Everything in this directory is an input to the kernel image builds: the
Dockerfile, kernel configs and the scripts they invoke.

CI derives content-addressed *candidate tags* by hashing this entire directory
(see `scripts/candidate-tag.sh`). Identical contents produce an identical tag,
letting CI skip builds whose result already exists in the registry. Keep
anything that affects image contents in here, and keep everything else out, to
avoid needless rebuilds.

The toolchain is covered by the hash through the builder image tag pinned in the
Dockerfile.
