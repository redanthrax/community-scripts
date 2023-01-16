#!/bin/bash

vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "This script must be run as root."
    exit
fi

while getopts :i:s:a:u flag
do
    case "${flag}" in
        i) ikey=${OPTARG};;
        s) skey=${OPTARG};;
        a) api_hostname=${OPTARG};;
        u) uninstall="true";;
    esac
done

ikey=$( echo $ikey | sed -e "s/'//g" )
skey=$( echo $skey | sed -e "s/'//g" )
api=$( echo $api_hostname | sed -e "s/'//g" )

if ! [ -z $uninstall ]; then
    echo "Uninstalling Duo Authentication..."
    curl -s https://dl.duosecurity.com/MacLogon-latest.zip -o /tmp/MacLogon-latest.zip
    echo "Deflating Duo installer..."
    [ -d "/tmp/MacLogon-latest" ] && rm -rf /tmp/MacLogon-latest
    unzip -q /tmp/MacLogon-latest.zip -d /tmp/MacLogon-latest
    pkg_path=$( find /tmp/MacLogon-latest/MacLogon-* -name 'MacLogon-Uninstaller-*.pkg' )
    installer -pkg ${pkg_path}
    echo "Cleaning up..."
    rm -rf /tmp/MacLogon-latest
    rm -rf /tmp/MacLogon-latest.zip
    echo "Duo uninstall complete."
    exit 0
fi

if [ -z "$ikey" ] || [ -z "$skey" ] || [ -z "$api_hostname" ]; then
    echo "Usage: ./Mac_Duo_Install.sh -i IKEY -s SKEY -a ApiHostname"
else
    prodver="$(sw_vers -productVersion)"
    vercomp $prodver "12.9"
    vercode="$?"
    if [[ $vercode == "1" ]]; then
        echo "Duo is not compatible with this version of MacOS."
        exit 0
    fi

    echo "Checking if Duo is already installed..."
    if [ -f /private/var/root/Library/Preferences/com.duosecurity.maclogon.plist ]; then
        echo "Duo is already installed."
        exit 0
    fi

    echo "Downloading the Duo installation..."
    curl -s https://dl.duosecurity.com/MacLogon-latest.zip -o /tmp/MacLogon-latest.zip
    echo "Deflating Duo installer..."
    [ -d "/tmp/MacLogon-latest" ] && rm -rf /tmp/MacLogon-latest
    unzip -q /tmp/MacLogon-latest.zip -d /tmp/MacLogon-latest
    echo "Installing Duo..."

    version="2.0.0"

    echo "Duo Security Mac Logon configuration tool v${version}."
    echo "See https://duo.com/docs/macos for documentation"

    pkg_path=$( find /tmp/MacLogon-latest/MacLogon-* -name 'MacLogon-NotConfigured-*.pkg' )

    if [ ! -f "${pkg_path}" ]; then
        echo "No package found at $pkg_path. Exiting."
        exit 1
    fi

    fail_open="false"
    smartcard_bypass="false"
    auto_push="true"

    pkg_dir=$(dirname "${pkg_path}")
    pkg_name=$(basename "${pkg_path}" | awk -F\. '{print $1 "." $2}')
    tmp_path="/tmp/${pkg_name}"
    echo "Modifying ${pkg_path}..."
    pkgutil --expand "${pkg_path}" "${tmp_path}"
    echo "Updating config.plist ikey, skey, api_hostname, fail_open, smartcard_bypass, and auto_push config..."
    defaults write "${tmp_path}"/Scripts/config.plist ikey -string "${ikey}"
    defaults write "${tmp_path}"/Scripts/config.plist skey -string "${skey}"
    defaults write "${tmp_path}"/Scripts/config.plist api_hostname -string "${api_hostname}"
    defaults write "${tmp_path}"/Scripts/config.plist fail_open -bool "${fail_open}"
    defaults write "${tmp_path}"/Scripts/config.plist smartcard_bypass -bool "${smartcard_bypass}"
    defaults write "${tmp_path}"/Scripts/config.plist auto_push -bool "${auto_push}"
    defaults write "${tmp_path}"/Scripts/config.plist twofa_unlock -bool false
    plutil -convert xml1 "${tmp_path}/Scripts/config.plist"
    out_pkg="${pkg_dir}/MacLogon-${version}.pkg"
    echo "Finalizing package, saving as ${out_pkg}"
    pkgutil --flatten "${tmp_path}" "${out_pkg}"

    echo "Cleaning up temp files..."
    rm -rf "${tmp_path}"

    echo "Done! The package ${out_pkg} has been configured for your use."
    
    echo "Installing Duo..."
    installer -allowUntrusted -verboseR -pkg ${out_pkg}
    echo "Cleaning up..."
    rm -rf /tmp/MacLogon-latest
    rm -rf /tmp/MacLogon-latest.zip
    echo "Duo install complete."
fi
