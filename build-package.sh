#!/bin/bash

set -eu

case "$1" in
    pull)
        craftctl default
        export DEBIAN_FRONTEND=noninteractive
        export DEBCONF_NONINTERACTIVE_SEEN=true
        apt-get build-dep -y ./
        ;;
    build)
        # unset the LD_FLAGS and LD_LIBRARY_PATH vars that snapcraft sets for us
        # as those will point to the $CRAFT_STAGE which on re-builds will
        # contain things like libc and friends that confuse the debian package
        # build system
        # TODO: should we unset $PATH to not include $CRAFT_STAGE too?
        unset LD_FLAGS
        unset LD_LIBRARY_PATH
        # run the real build (but just build the binary package, and don't
        # bother compressing it too much)
        dpkg-buildpackage -b -uc -us -Zgzip -zfast
        mkdir -p "${CRAFT_PART_INSTALL}/local-debs"
        source="$(dpkg-parsechangelog -SSource)"
        version="$(dpkg-parsechangelog -SVersion)"
        arch="$(dpkg --print-architecture)"
        dcmd mv "../${source}_${version}_${arch}.changes" "${CRAFT_PART_INSTALL}/local-debs"
        ;;
    stage)
        craftctl default
        # It is possible to add .deb packages into a "test-debs" folder in the
        # project. These packages are managed as an APT source, and pinned to
        # have maximum priority, so, if installed from APT, they will have preference
        # over the packages in the standard and PPA repositories, no matter their version
        # number. This allows to easily test packages before uploading them to the
        # Core Desktop PPA.
        if [ -e ${CRAFT_PROJECT_DIR}/test-debs ]; then
            /bin/cp -a ${CRAFT_PROJECT_DIR}/test-debs/*.deb ${CRAFT_STAGE}/local-debs/
        fi
        cd "${CRAFT_STAGE}/local-debs"
        dpkg-scanpackages . >Packages
        apt-ftparchive release . >Release
        ;;
esac
