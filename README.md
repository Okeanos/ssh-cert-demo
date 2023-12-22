# SSH Certificates Example

This repository contains minimal examples showcasing SSH certificates using
[Fedora CoreOS](https://docs.fedoraproject.org/en-US/fedora-coreos/) configurations and scripts that help deploy them on
[VirtualBox](https://www.virtualbox.org).

---

The shell script template used for the generator scripts is the MIT licensed
[script-template.sh](https://gist.github.com/m-radzikowski/53e0b39e9a59a1518990e76c2bff8038) by Maciej Radzikowski.

## Required Software

- [bash](https://www.gnu.org/software/bash/) scripting environment
- [butane](https://github.com/coreos/butane) Fedora CoreOS configuration converter
- [curl](https://github.com/curl/curl) curl to download files off of the Internet
- [gpg](https://www.gnupg.org/) OpenPGP implementation for signature checks
- [jq](https://stedolan.github.io/jq/) JSON parser
- [ssh](https://www.openssh.com) SSH implementation

## Getting started

1. Run the `setup.sh` script to download the latest CoreOS image and generate an SSH certificate authority.
2. Run the `deploy.sh` script for each SSH certificate VM you want to configure and spawn.
