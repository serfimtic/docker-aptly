# Container Aptly

The following environment variable can be used to configure behavior of `serfimtic/aptly` container.

## Gpg key generation

- `GPG_KEY_TYPE` RSA, DSA, ... Default to RSA

- `GPG_KEY_LENGTH` default to 2048

- `GPG_REAL_NAME` must be set

- `GPG_EMAIL` must be set

- `GPG_EXPIRE_DATE` Default to 0.

- `GPG_DIRECTORY` allow user to indicate where the gpg should be find on container file system. In addition to setting this environment variable, one must mount appropriate directory into container.

## Aptly configuration

- `APTLY_CONF` indicate a configuration file to use instead of the default one. This file has to be mounted into the container.

- `APTLY_DIR` indicate where on the container filesystem aptly root directory should be found. In addition to this environment variable, one must mount appropriate directory into container.

> **NB:** You can use only one of the above variable to configure Aptly simultaneously.

## Default mirror

- `DEFAULT_MIRROR_NAME` If this variable is set, the container will mirror the chosen repository, make snapshot of it and publish it.

- `DEFAULT_MIRROR_REPO_URL` Url to default mirror repository (can be set only when `DEFAULT_MIRROR_NAME` is set)

- `DEFAULT_MIRROR_DISTRO` Distribution of default mirror (can be set only when `DEFAULT_MIRROR_NAME` is set)

- `DEFAULT_MIRROR_COMPONENT` This variable can be set only when `DEFAULT_MIRROR_NAME` is set, its used to indicate the component to use for the default mirror. (default component is **main**)

- `DEFAULT_MIRROR_FILTER` Filter for default mirror (can be set only when `DEFAULT_MIRROR_NAME` is set)

- `DEFAULT_MIRROR_FILTER_WITH_DEPS` If set add switch **-filter-with-deps** to mirror creation command (can be set only when `DEFAULT_MIRROR_NAME` is set)
 
- `DEFAULT_MIRROR_ARCH` A comma separated list of arch for the mirror. Default to **amd64** (can be set only when `DEFAULT_MIRROR_NAME` is set)

## Custom repository

- `CUSTOM_REPOSITORY_NAME` Indicate the name of the custom repository

- `CUSTOM_REPOSITORY_DISTRO` Distribution name

- `CUSTOM_REPOSITORY_PATH` Path to directory with all package that should be added to the repository.

- `CUSTOM_REPOSITORY_COMPONENT` Component name of custom repository as a comma separated list (default: **main**)

- `CUSTOM_REPOSITORY_ARCH` Comma separated list of architectures (default: **amd64**)

## Custom startup script.

You can choose to pass to the container a script creating your repositories and snapshots, using the `CUSTOM_SCRIPT` variable pointing to a bash script mounted to the container with execute right.

## Serve existing repository

If you have a directory containing existing aptly repository, snapshot, ... You can mount that directory on **/aptly** and let the container serve them without creating any mirror or custom repository. If you do so, you must provide to the container the GPG key used to publish this existing entities with `GPG_DIRECTORY`.

You can also add to these existing repositories your own via `DEFAULT_MIRROR` and/or `CUSTOM_REPOSITORY` environment variables.
