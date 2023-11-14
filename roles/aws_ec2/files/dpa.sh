#!/bin/bash
set -o errexit
set -o noclobber
set -o nounset
set -o pipefail
set -e  # exit if any subcommand fails

clear || true

stringNotContain() { case $2 in *$1* ) return 1 ;; *) return ;; esac ;}

# Check if script is running as sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# check if sshd config file exists
sshd_config_filename='/etc/ssh/sshd_config'
if [[ ! -f "$sshd_config_filename" ]]; then
    echo "$sshd_config_filename doesnt exists. exiting"
    exit 1
fi

ca='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC0ZV4ux1OT2GVVsy3Kl5LkG1LVXEeJsPGIvPYKfpFgmNbk5KOt3uRDzHJo8t1RKpfCyJ5sUHsylJOnGocwx8iNQEGAgLKTy+f4jmUiAbIK8MVk950g74IunQCd7LECRFRkkWeJEzPst9FXhqAOkxbc6FKKiYomJQQVlQ44iixperkE43w+aHdFoH6gPufJrn8Qrya+L8WOMmsblldXjbi3ENRxtkPcyWD7j13mO2Cg33K7uNMMIM3EcWuJHwaakK8jMzqWI/wL/vVB/nhDL9ZR3CGOoZdS9m5+f0myKsHC8IdTSDfkURN1xX0+AWzaZtzacRgaYkIan0ON6ltoxiC1wJzp3NAOdAHomaUzQW5uROCSasuD9jJRMyB/rMwfx25fah94kMK8QmOcTCnMohswyQxriLYJi5BMZaHwtwN0DrCHsQYmf6JTkoU6ascS8OK4y35YdGX0gWDfQ50PigebbXX3oRNgq4rvSIiROxjRv/8rVSCJqDv/YXvPKwhsH8ukPDwriMB/dhBKMDIfcQWyXsiHIQR3ygUol6cl/ucxFhnBf2xSVS0xB6zNPxTQeUmj1/6iHM1RPG4HCdvK+7mCK22N3nhJYpB2X0rTv6r1RyTRrvUgbsyIuzf401HU0wm4gz3u5YwQaswoUD0VinLjSl84YLquYnzPxoSaze5XcQ=='
ca_filename='735280068473_public_CA.pub'
target_ca_filename='/etc/ssh/'$ca_filename
echo -n "$ca" > $ca_filename
if [[ $(grep -c "^TrustedUserCAKeys" $sshd_config_filename) -eq 0 ]]
then
    # Move the CA file to sshd dir
    mv $ca_filename $target_ca_filename

    # Backing up the config file before
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    echo "TrustedUserCAKeys /etc/ssh/735280068473_public_CA.pub" >> /etc/ssh/sshd_config

    # Check new configuration and revert if with errors
    sshd_path=$(which sshd)
    config_ok=$($sshd_path -t > /dev/null;echo $?)
    with_errors=true
    if [ "$config_ok" -eq 0 ]; then
        echo "Trusted CA Certificate set succesfully to file: $ca_filename"
        with_errors=false
    else
        mv /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
        echo "Setup script Error. Trusted CA Certificate could not be set, reverting configuration. Error: $config_ok"
    fi

    # Restart the sshd server
    systemctl restart sshd
    sshd_service_up=$(systemctl status sshd > /dev/null;echo $?)
    if [ "$sshd_service_up" -eq 0 ]; then
        echo "Sshd service restarted successfully"
        if [ -z $with_errors ]; then
            echo "Installation Completed with errors"
        else
            sshd_conf=$(sshd -T)
            if stringNotContain "ssh-ed25519-cert-v01@openssh.com" "$sshd_conf"; then
               echo "WARNING: ssh-ed25519-cert-v01@openssh.com not found in list of supported host key algorithms"
            fi

            if stringNotContain "$ca_filename" "$sshd_conf"; then
               echo "WARNING: $ca_filename not found in TrustedUserCAKeys configuration"
            fi
            echo "Installation Completed"
        fi
    else
        echo "Fatal Error. Sshd service is not started, please start manually the sshd server"
        echo "Installation Failed"
    fi
else
    config_ca_filename=$(grep TrustedUserCAKeys $sshd_config_filename | awk '{print $2}')
    echo "Found Trusted CA file in $sshd_config_filename, CA Could not be set"
    echo "Installation Aborted"
    exit 1
fi
EOF
