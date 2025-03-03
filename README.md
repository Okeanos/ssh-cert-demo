# SSH Certificates Example

This repository contains minimal examples showcasing SSH certificates using [Fedora CoreOS](https://docs.fedoraproject.org/en-US/fedora-coreos/)
configurations and scripts that help deploy them on [VMWare Desktop Hypervisor](https://www.vmware.com/products/desktop-hypervisor).

---

The shell script template used for the generator scripts is the MIT licensed [script-template.sh](https://gist.github.com/m-radzikowski/53e0b39e9a59a1518990e76c2bff8038)
by Maciej Radzikowski.

## Required Software

- [bash](https://www.gnu.org/software/bash/) scripting environment, preferably a modern version (>=5.0)
- [butane](https://github.com/coreos/butane) Fedora CoreOS configuration converter when using VirtualBox
- [curl](https://github.com/curl/curl) curl to download files off of the Internet
- [gpg](https://www.gnupg.org/) OpenPGP implementation for signature checks
- [jq](https://stedolan.github.io/jq/) JSON parser
- [ssh](https://www.openssh.com) SSH implementation
- [VMWare Desktop Hypervisor](https://www.vmware.com/products/desktop-hypervisor) free for personal and commercial use

## Getting started

What's included?

### FCOS Based using VMWare Hypervisor (Fusion)

1. Run the `setup.sh` script to download the latest CoreOS image and generate an SSH certificate authority.
2. Run the `deploy.sh` script for each SSH certificate VM you want to configure and spawn.

### What's next?

Update your `/etc/hosts` file and ensure that your VMs can be easily reached by DNS from your local machine.

The machines all need a name ending in `.local` as TLD to work with the generated SSH certificate authority.

Technically, DHCP + local DNS is supposed to take care of this but … you never know.

## SSH What Now?

SSH Certificates!

- [OpenSSH on Certificates](https://man.openbsd.org/ssh-keygen.1#CERTIFICATES)
- [Fedora on Using OpenSSH Certificate Authentication](https://docs.fedoraproject.org/en-US/fedora/rawhide/system-administrators-guide/infrastructure-services/OpenSSH/#sec-Using_OpenSSH_Certificate_Authentication)
- [Using a CA with SSH](https://www.lorier.net/docs/ssh-ca.html)
- [How to create an SSH certificate authority](https://jameshfisher.com/2018/03/16/how-to-create-an-ssh-certificate-authority/)
- [If you’re not using SSH certificates you’re doing SSH wrong](https://smallstep.com/blog/use-ssh-certificates/)
- [Managing servers with OpenSSH Certificate Authority](https://ibug.io/blog/2019/12/manage-servers-with-ssh-ca/)

### Tools

- [HashiCorp Vault](https://developer.hashicorp.com/vault/docs/secrets/ssh/signed-ssh-certificates)
- [smallstep ca](https://smallstep.com/docs/step-ca/#ssh-certificate-authority)
- [KeePassXC Feature Request](https://github.com/keepassxreboot/keepassxc/issues/5486) 
