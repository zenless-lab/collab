#!/bin/bash

set -e

INSTALL_ZSH="${INSTALL_ZSH:-"true"}"
INSTALL_OH_MY_ZSH="${INSTALL_OH_MY_ZSH:-"true"}"
UPGRADE_PACKAGES="${UPGRADE_PACKAGES:-"true"}"
OMZ_PLUGINS="${OMZ_PLUGINS:-"git sudo jsontools z"}"
OMZ_THEME="${OMZ_THEME:-"robbyrussell"}"


install_packages() {
    # Ensure apt is in non-interactive to avoid prompts
    export DEBIAN_FRONTEND=noninteractive

    local package_list="apt-utils \
        bash-completion \
        openssh-client \
        gnupg2 \
        dirmngr \
        iproute2 \
        procps \
        lsof \
        htop \
        net-tools \
        psmisc \
        curl \
        tree \
        wget \
        rsync \
        ca-certificates \
        unzip \
        bzip2 \
        xz-utils \
        zip \
        nano \
        vim-tiny \
        less \
        jq \
        lsb-release \
        apt-transport-https \
        dialog \
        libc6 \
        libgcc1 \
        libkrb5-3 \
        libgssapi-krb5-2 \
        libicu[0-9][0-9] \
        liblttng-ust[0-9] \
        libstdc++6 \
        zlib1g \
        locales \
        sudo \
        ncdu \
        man-db \
        strace \
        manpages \
        manpages-dev \
        init-system-helpers"

    # Include libssl1.1 if available
    if [[ -n $(apt-cache --names-only search ^libssl1.1$) ]]; then
        package_list="${package_list} libssl1.1"
    fi

    # Include libssl3 if available
    if [[ -n $(apt-cache --names-only search ^libssl3$) ]]; then
        package_list="${package_list} libssl3"
    fi

    # Include appropriate version of libssl1.0.x if available
    local libssl_package
    libssl_package=$(dpkg-query -f '${db:Status-Abbrev}\t${binary:Package}\n' -W 'libssl1\.0\.?' 2>&1 || echo '')
    if [ "$(echo "$libssl_package" | grep -o 'libssl1\.0\.[0-9]:' | uniq | sort | wc -l)" -eq 0 ]; then
        if [[ -n $(apt-cache --names-only search ^libssl1.0.2$) ]]; then
            # Debian 9
            package_list="${package_list} libssl1.0.2"
        elif [[ -n $(apt-cache --names-only search ^libssl1.0.0$) ]]; then
            # Ubuntu 18.04
            package_list="${package_list} libssl1.0.0"
        fi
    fi

    # Include git if not already installed (may be more recent than distro version)
    if ! type git > /dev/null 2>&1; then
        package_list="${package_list} git"
    fi

    # Install the list of packages
    echo "Packages to verify are installed: ${package_list}"
    rm -rf /var/lib/apt/lists/*
    apt-get update -y
    apt-get -y install --no-install-recommends ${package_list} 2> >( grep -v 'debconf: delaying package configuration, since apt-utils is not installed' >&2 )

    # Install zsh (and recommended packages) if needed
    if [ "${INSTALL_ZSH}" = "true" ] && ! type zsh > /dev/null 2>&1; then
        apt-get install -y zsh
    fi

    # Get to latest versions of all packages
    if [ "${UPGRADE_PACKAGES}" = "true" ]; then
        apt-get -y upgrade --no-install-recommends
        apt-get autoremove -y
    fi

    # Ensure at least the en_US.UTF-8 UTF-8 locale is available = common need for both applications and things like the agnoster ZSH theme.
    if [ "${LOCALE_ALREADY_SET}" != "true" ] && ! grep -o -E '^\s*en_US.UTF-8\s+UTF-8' /etc/locale.gen > /dev/null; then
        echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
        locale-gen
        LOCALE_ALREADY_SET="true"
    fi

    # Clean up
    apt-get -y clean
    rm -rf /var/lib/apt/lists/*
}

configure_zsh() {
    apt-get update -y
    apt-get install -y --no-install-recommends \
        zsh

    if [ "$INSTALL_OH_MY_ZSH" == "true" ]; then
        sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        sed -i "s/plugins=(.*)/plugins=(${OMZ_PLUGINS})/" "${ZDOTDIR:-$HOME}/.zshrc"
        sed -i "s/ZSH_THEME=\".*\"/ZSH_THEME=\"${OMZ_THEME}\"/" "${ZDOTDIR:-$HOME}/.zshrc"
    fi

    apt-get install -y --no-install-recommends \
        zsh-autosuggestions \
        zsh-syntax-highlighting

    {
        echo "export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=\"fg=#808080\""
        echo "source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
        echo "source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    } >> "${ZDOTDIR:-$HOME}/.zshrc"

    # Clean up
    apt-get -y clean
    rm -rf /var/lib/apt/lists/*
}

install_packages
if [ "${INSTALL_ZSH}" = "true" ]; then
    configure_zsh
fi
