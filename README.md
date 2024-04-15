# SSH Certificates Example

This repository contains minimal examples showcasing SSH certificates using
[Fedora CoreOS](https://docs.fedoraproject.org/en-US/fedora-coreos/) configurations and scripts that help deploy them on
[VirtualBox](https://www.virtualbox.org) as well as a functionally identical
[Docker](https://www.docker.com) based version.

---

The shell script template used for the generator scripts is the MIT licensed
[script-template.sh](https://gist.github.com/m-radzikowski/53e0b39e9a59a1518990e76c2bff8038) by Maciej Radzikowski.

## Required Software

- [bash](https://www.gnu.org/software/bash/) scripting environment, preferably a modern version (>=5.0)
- [butane](https://github.com/coreos/butane) Fedora CoreOS configuration converter when using VirtualBox
- [curl](https://github.com/curl/curl) curl to download files off of the Internet
- [Docker](https://www.docker.com) as an alternative to VirtualBox
- [gpg](https://www.gnupg.org/) OpenPGP implementation for signature checks
- [jq](https://stedolan.github.io/jq/) JSON parser
- [ssh](https://www.openssh.com) SSH implementation
- [VirtualBox](https://www.virtualbox.org) as an alternative to Docker

## Getting started

What's included?

### Docker with Docker Compose

1. Run the `setup.sh` script to generate an SSH certificate authority & SSH certificates.
2. Run `docker compose up -d` to start the stack

### FCOS Based using VirtualBox

1. Run the `setup.sh` script to download the latest CoreOS image and generate an SSH certificate authority.
2. Run the `deploy.sh` script for each SSH certificate VM you want to configure and spawn.
