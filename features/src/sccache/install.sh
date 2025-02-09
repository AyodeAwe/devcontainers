#! /usr/bin/env bash
set -ex

SCCACHE_VERSION="${VERSION:-latest}";

# Ensure we're in this feature's directory during build
cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

# install global/common scripts
. ./common/install.sh;

check_packages jq wget ca-certificates bash-completion;

echo "Installing sccache...";

if [ $SCCACHE_VERSION == latest ]; then
    find_version_from_git_tags SCCACHE_VERSION https://github.com/mozilla/sccache;
fi

# Install sccache
wget --no-hsts -q -O- "https://github.com/mozilla/sccache/releases/download/v$SCCACHE_VERSION/sccache-v$SCCACHE_VERSION-$(uname -p)-unknown-linux-musl.tar.gz" \
    | tar -C /usr/bin -zf - --wildcards --strip-components=1 -x */sccache \
 && chmod +x /usr/bin/sccache;

# export envvars in /etc/bash.bashrc
append_to_etc_bashrc "$(cat .bashrc)";
# export envvars in ~/.bashrc
append_to_all_bashrcs "$(cat .bashrc)";
# export envvars in /etc/profile.d
add_etc_profile_d_script sccache "$(cat .bashrc)";

# Clean up
# rm -rf /tmp/*;
rm -rf /var/tmp/*;
rm -rf /var/cache/apt/*;
rm -rf /var/lib/apt/lists/*;
