#!/usr/bin/env bash

# script-template.sh https://gist.github.com/m-radzikowski/53e0b39e9a59a1518990e76c2bff8038 by Maciej Radzikowski
# MIT License https://gist.github.com/m-radzikowski/d925ac457478db14c2146deadd0020cd
# https://betterdev.blog/minimal-safe-bash-script-template/

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
	cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-f] -p param_value arg1 [arg2...]
Deploy the SSH Certificate example stack
Available options:
-h, --help             Print this help and exit
-v, --verbose          Print script debug info
-x, --expiry           SSH host certificate expiry, defaults to +3650d
EOF
	exit
}

cleanup() {
	trap - SIGINT SIGTERM ERR EXIT
	# script cleanup here
}

setup_colors() {
	if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
		NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
	else
		NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
	fi
}

msg() {
	echo >&2 -e "${1-}"
}

die() {
	local msg=$1
	local code=${2-1} # default exit status 1
	msg "$msg"
	exit "$code"
}

parse_params() {
	# default values of variables set from params
	expiry='+3650d'
	hostSigningKey=''
	verbose=0

	while :; do
		case "${1-}" in
		-h | --help) usage ;;
		-v | --verbose) set -x ;;
		--no-color) NO_COLOR=1 ;;
		-x | --expiry)
			expiry="${2-}"
			shift
			;;
		-?*) die "Unknown option: $1" ;;
		*) break ;;
		esac
		shift
	done

	# check required params and arguments

	return 0
}

parse_params "$@"
setup_colors

# script logic here
hostSigningKey=$(realpath --canonicalize-missing "${script_dir}/ca/ca")
[[ ! -f "${hostSigningKey-}" ]] && die "Parameter 'host-signing-key' does not point to an existing SSH key file"

msg "Creating SSH Host Keys"
# TODO iterate over all services in the docker-compose file and name the files correctly
ssh-keygen -t ecdsa -N "" -f "${script_dir}/ssh/ssh_host_ecdsa_key" -C "${name},${name}.local"
ssh-keygen -t ed25519 -N "" -f "${script_dir}/ssh/ssh_host_ed25519_key" -C "${name},${name}.local"
ssh-keygen -t rsa -b 4096 -N "" -f "${script_dir}/ssh/ssh_host_rsa_key" -C "${name},${name}.local"

msg "Creating signed SSH certificates"
ssh-keygen -s "${hostSigningKey}" \
	-t rsa-sha2-512 \
	-I "${name} host key" \
	-n "${name},${name}.local" \
	-V "-5m:${expiry}" \
	-h \
	"${script_dir}/ssh/ssh_host_ecdsa_key" \
	"${script_dir}/ssh/ssh_host_ed25519_key" \
	"${script_dir}/ssh/ssh_host_rsa_key"

docker compose up -d
