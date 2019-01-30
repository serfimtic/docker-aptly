#!/bin/bash

ERROR="\e[31m[ERROR]\e[0m"
PROMPT="\e[32m>\e[0m"

# If GPG_DIRECTORY is set 
if [ ! -z "$GPG_DIRECTORY" ];then
    # and match a directory
    if [ -d "$GPG_DIRECTORY" ];then
        cp $GPG_DIRECTORY $HOME/.gnupg
        echo -e "$PROMPT GPG_DIRECTORY copied into user .gnupg"
    else
        echo -e "$ERROR Cannot find $GPG_DIRECTORY in container"
        exit 1
    fi
else
    [ -z "$GPG_REAL_NAME" ] && echo -e "$ERROR You must set env GPG_REAL_NAME"
    [ -z "$GPG_EMAIL" ] && echo -e "$ERROR You must set env GPG_EMAIL"
    [ -z "$GPG_REAL_NAME" ] || [ -z "$GPG_EMAIL" ] && exit 1
fi

# If there is no existing gpg directory
if [ ! -d $HOME/.gnupg ];then

cat >/tmp/gpg.batch <<EOF
    %no-protection
    %echo Generating a basic OpenPGP key
    Key-Type: ${GPG_KEY_TYPE:-RSA}
    Key-Length: ${GPG_KEY_LENGTH:-2048}
    Subkey-Type: default
    Name-Real: ${GPG_REAL_NAME}
    Name-Email: ${GPG_EMAIL}
    Expire-Date: ${GPG_EXPIRE_DATE:-0}
    # Do a commit here, so that we can later print "done" :-)
    %commit
    %echo done
EOF

    echo -e "$PROMPT No GPG configuration found, generating new GPG key..."
    gpg --batch --generate-key /tmp/gpg.batch
    echo -e "$PROMPT Exporting public key generated in '/root/.gnupg/aptly_key.pub'. (It should "
    echo -e "$PROMPT be imported on computer which will be updated from this aptly instance with"
    echo -e "$PROMPT the following command 'sudo apt-key add <public.key>')"
    gpg --export --armor > /root/.gnupg/aptly_key.pub
    echo -e "$PROMPT Export done !"
fi

# Configure Aptly
if [ ! -z "$APTLY_CONF" ] && [ ! -z "$APTLY_DIR" ];then 
    echo -e "$ERROR You can't use APTLY_CONF and APTLY_DIR simultaneously"
    exit 1
fi

if [ ! -z "$APTLY_CONF" ];then
    if [ ! -f "$APTLY_CONF" ];then 
        echo -e "$ERROR Cannot find APTLY_CONF at $APTLY_CONF"
        exit 1
    else
        cp $APTLY_CONF /etc/aptly.conf
        echo -e "$PROMPT Container now used custom conf ($APTLY_CONF) for aptly."
    fi
fi

if [ ! -z "$APTLY_DIR" ];then
    [ -d "$APTLY_DIR" ] || mkdir $APTLY_DIR && echo -e "$PROMPT Create new aptly root directory"
    sed -i "s@\"rootDir\":.*,@\"rootDir\": \"$APTLY_DIR\",@g" /etc/aptly.conf
    echo -e "$PROMPT Update aptly rootDir in aptly.conf"
fi

# Build mirror snapshot and publish it

if [ ! -z "$CUSTOM_SCRIPT" ];then 
    if [ ! -f "$CUSTOM_SCRIPT" ];then 
        echo -e "$ERROR Cannot find CUSTOM_SCRIPT at $CUSTOM_SCRIPT"
        exit 1
    fi
    bash -x $CUSTOM_SCRIPT
else

    if [ ! -z "$DEFAULT_MIRROR_NAME" ] || [ ! -z "$DEFAULT_MIRROR_REPO_URL" ] || [ ! -z "$DEFAULT_MIRROR_DISTRO" ];then
        [ -z "$DEFAULT_MIRROR_NAME" ] && echo -e "$ERROR DEFAULT_MIRROR_NAME must be set"
        [ -z "$DEFAULT_MIRROR_REPO_URL" ] && echo -e "$ERROR DEFAULT_MIRROR_REPO_URL must be set"
        [ -z "$DEFAULT_MIRROR_DISTRO" ] && echo -e "$ERROR DEFAULT_MIRROR_DISTRO must be set"

        [ -z "$DEFAULT_MIRROR_NAME" ] || [ -z "$DEFAULT_MIRROR_REPO_URL" ] || [ -z "$DEFAULT_MIRROR_DISTRO" ] && exit 1

        echo -e "$PROMT Import default debian key into keyring" 
        gpg --no-default-keyring --keyring /usr/share/keyrings/debian-archive-keyring.gpg --export | gpg --no-default-keyring --keyring trustedkeys.gpg --import

        echo -e "$PROMPT About to mirror chosen repository"
        aptly mirror create -architectures=${DEFAULT_MIRROR_ARCH:-amd64} $([ ! -z "$DEFAULT_MIRROR_FILTER" ] && echo -filter=\'"$DEFAULT_MIRROR_FILTER"\') $([ ! -z "$DEFAULT_MIRROR_FILTER_WITH_DEPS" ] && echo "-filter-with-deps") $DEFAULT_MIRROR_NAME $DEFAULT_MIRROR_REPO_URL $DEFAULT_MIRROR_DISTRO ${DEFAULT_MIRROR_COMPONENT:-main}
        echo -e "$PROMPT Mirror created"

        echo -e "$PROMPT About to download chosen mirror"
        aptly mirror update $DEFAULT_MIRROR_NAME
        echo -e "$PROMPT Mirror downloaded"

        snapshot_name=${DEFAULT_MIRROR_NAME}-$(date --iso-8601)
        echo -e "$PROMPT About to create a snapshot $snapshot_name of $DEFAULT_MIRROR_NAME repository"
        aptly snapshot create $snapshot_name from mirror $DEFAULT_MIRROR_NAME
        echo -e "$PROMPT Snapshot created"

        echo -e "$PROMPT About to publish snapshot $snapshot_name"
        aptly publish snapshot -distribution=$DEFAULT_MIRROR_DISTRO -architectures=${DEFAULT_MIRROR_ARCH:-amd64} $snapshot_name $DEFAULT_MIRROR_NAME
        echo -e "$PROMPT Snapshot published"
    fi

    # Build custom snapshot and publish it
    if [ ! -z "$CUSTOM_REPOSITORY_NAME" ] || [ ! -z "$CUSTOM_REPOSITORY_DISTRO" ] || [ ! -z "$CUSTOM_REPOSITORY_PATH" ];then
        [ -z "$CUSTOM_REPOSITORY_NAME" ] && echo -e "$ERROR CUSTOM_REPOSITORY_NAME must be set"
        [ -z "$CUSTOM_REPOSITORY_DISTRO" ] && echo -e "$ERROR CUSTOM_REPOSITORY_DISTRO must be set"
        [ -z "$CUSTOM_REPOSITORY_PATH" ] && echo -e "$ERROR CUSTOM_REPOSITORY_PATH must be set"

        [ -z "$CUSTOM_REPOSITORY_NAME" ] || [ -z "$CUSTOM_REPOSITORY_DISTRO" ] || [ -z "$CUSTOM_REPOSITORY_PATH" ] && exit 1

        aptly repo create -distribution=$CUSTOM_REPOSITORY_DISTRO -component=${CUSTOM_REPOSITORY_COMPONENT:-main} $CUSTOM_REPOSITORY_NAME
        echo -e "$PROMPT Custom repository $CUSTOM_REPOSITORY_NAME created"

        echo -e "$PROMPT About to import chosen packages into $CUSTOM_REPOSITORY_NAME repository"
        aptly repo add $CUSTOM_REPOSITORY_NAME $CUSTOM_REPOSITORY_PATH
        echo -e "$PROMPT Import done"

        custom_snapshot_name=${CUSTOM_REPOSITORY_NAME}-$(date --iso-8601)
        echo -e "$PROMPT About to create a snapshot $custom_snapshot_name of $CUSTOM_REPOSITORY_NAME repository"
        aptly snapshot create $custom_snapshot_name from repo $CUSTOM_REPOSITORY_NAME
        echo -e "$PROMPT Snapshot created"

        echo -e "$PROMPT About to publish snapshot $custom_snapshot_name of $CUSTOM_REPOSITORY_NAME"
        aptly publish snapshot -distribution=$CUSTOM_REPOSITORY_DISTRO -architectures=${CUSTOM_REPOSITORY_ARCH:-amd64} $snapshot_name $CUSTOM_REPOSITORY_NAME
        echo -e "$PROMPT Snapshot published"
    fi
fi

exec $@