#!/usr/bin/env bash

# script-template.sh https://gist.github.com/m-radzikowski/53e0b39e9a59a1518990e76c2bff8038 by Maciej Radzikowski
# MIT License https://gist.github.com/m-radzikowski/d925ac457478db14c2146deadd0020cd
# https://betterdev.blog/minimal-safe-bash-script-template/

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

# shellcheck disable=SC2034
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
	cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-f] -p param_value arg1 [arg2...]
Script description here.
Available options:
-h, --help             Print this help and exit
-v, --verbose          Print script debug info
EOF
	exit
}

cleanup() {
	trap - SIGINT SIGTERM ERR EXIT
	# script cleanup here
}

setup_colors() {
	if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
		# shellcheck disable=SC2034
		NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
	else
		# shellcheck disable=SC2034
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

	while :; do
		case "${1-}" in
		-h | --help) usage ;;
		-v | --verbose) set -x ;;
		--no-color) NO_COLOR=1 ;;
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
ca_dir=$(realpath --canonicalize-missing "${script_dir}/ca")
ca_file=$(realpath --canonicalize-missing "${ca_dir}/ca")
client_dir=$(realpath --canonicalize-missing "${script_dir}/client")
client_file=$(realpath --canonicalize-missing "${client_dir}/client")
client_cert_file=$(realpath --canonicalize-missing "${client_dir}/client_cert")

if [[ ! -d "${ca_dir}" ]]; then
	message=$(printf "Ensuring that SSH ca directory '%s' exists.\n" "${ca_dir}")
	msg "${message}"
	mkdir -p "${ca_dir}"
fi

if [[ ! -d "${client_dir}" ]]; then
	message=$(printf "Ensuring that SSH client directory '%s' exists.\n" "${client_dir}")
	msg "${message}"
	mkdir -p "${client_dir}"
fi

# Generating SSH CA
if [[ ! -f "${ca_file}" ]]; then
	message=$(printf "Generating OpenSSH CA Key Pair at %s\n" "${ca_dir}")
	msg "${message}"

	ssh-keygen -q -f "${ca_file}" \
		-t rsa \
		-b 4096 \
		-N "" \
		-C "Demo CA"

	ca_cert=$(cat "${ca_file}.pub")
	printf "@cert-authority ssh-* %s" "${ca_cert}" >"${client_dir}/known_cas"
fi

# Generating SSH client
if [[ ! -f "${client_file}" ]]; then
	message=$(printf "Generating OpenSSH client Key Pair at %s\n" "${client_dir}")
	msg "${message}"

	ssh-keygen -q -f "${client_file}" \
		-t ed25519 \
		-N "" \
		-C "Demo Client Key"
fi

if [[ ! -f "${client_cert_file}-cert.pub" ]]; then
	message=$(printf "Generating OpenSSH client certificate at %s\n" "${client_dir}")
	msg "${message}"

	cp "${client_file}" "${client_cert_file}"

	msg "Signing client Key Pair with CA"
	ssh-keygen -q -s "${ca_file}" \
		-t rsa-sha2-512 \
		-I "core client cert key" \
		-n "core" \
		-V "-5m:+1d" \
		-O "no-x11-forwarding" \
		-O "no-agent-forwarding" \
		-O "no-port-forwarding"
		"${client_dir}/client_cert"
fi

msg "Done"
