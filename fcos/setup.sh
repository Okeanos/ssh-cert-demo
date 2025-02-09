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
-d, --download-dir     Path where CoreOS images should be stored
-s, --stream           CoreOS stream (defaults to stable)
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
	download=''
	stream='stable'

	while :; do
		case "${1-}" in
		-h | --help) usage ;;
		-v | --verbose) set -x ;;
		--no-color) NO_COLOR=1 ;;
		-s | --stream)
			stream="${2-}"
			shift
			;;
		-d | --download-dir)
			download="${2-}"
			shift
			;;
		-?*) die "Unknown option: $1" ;;
		*) break ;;
		esac
		shift
	done

	# check required params and arguments
	[[ -z "${stream-}" ]] && die "Missing required parameter: stream"
	[[ -z "${download-}" ]] && die "Missing required parameter: download-dir"

	return 0
}

parse_params "$@"
setup_colors

# script logic here
download=$(realpath --canonicalize-missing "${download}")
signing_key=$(realpath --canonicalize-missing "${download}/fedora.asc")
stream_json=$(realpath --canonicalize-missing "${download}/${stream}.json")
ova_version=''
ca_dir=$(realpath --canonicalize-missing "${script_dir}/ca")
ca_file=$(realpath --canonicalize-missing "${ca_dir}/ca")
client_dir=$(realpath --canonicalize-missing "${script_dir}/client")
client_file=$(realpath --canonicalize-missing "${client_dir}/client")

# Init download directory if it doesn't exist
if [[ ! -d "${download}" ]]; then
	message=$(printf "Creating CoreOS Downloads Folder at '%s'\n" "${download}")
	msg "${message}"
	mkdir -p "${download}"
fi

# Download the signing key for verification purposes
if [[ ! -f "${signing_key}" ]]; then
	message=$(printf "Downloading the Fedora signing key to '%s'" "${signing_key}")
	msg "${message}"
	curl --silent --show-error "https://getfedora.org/static/fedora.gpg" --output "${signing_key}"
fi

# Make the signing key useful for verification purposes
if [[ ! -f "${signing_key}.gpg" ]]; then
	gpg --dearmor "${signing_key}"
fi

# Download the CoreOS VM description for the particular stream
message=$(printf "Downloading stream json to '%s'\n" "${stream_json}")
msg "${message}"
curl --silent --show-error "https://builds.coreos.fedoraproject.org/streams/${stream}.json" --output "${stream_json}"

ova_version=$(jq --raw-output '.architectures.x86_64.artifacts.vmware.release' "${stream_json}")
ova_url_location=$(jq --raw-output '.architectures.x86_64.artifacts.vmware.formats.ova.disk.location' "${stream_json}")
ova_url_signature=$(jq --raw-output '.architectures.x86_64.artifacts.vmware.formats.ova.disk.signature' "${stream_json}")
ova_sha256=$(jq --raw-output '.architectures.x86_64.artifacts.vmware.formats.ova.disk.sha256' "${stream_json}")
ova_file_path=$(realpath --canonicalize-missing "${download}/coreos-${stream}-${ova_version}.ova")
ova_file_signature=$(realpath --canonicalize-missing "${download}/coreos-${stream}-${ova_version}.sig")
message=$(printf "Latest CoreOS Version for stream '%s' is '%s'\n" "${stream}" "${ova_version}")
msg "${message}"

# Download the latest available ova file for a particular stream
if [[ ! -f "${ova_file_path}" ]]; then
	message=$(printf "Downloading CoreOS Version for stream '%s' with version '%s'\n" "${stream}" "${ova_version}")
	msg "${message}"
	curl --silent --show-error "${ova_url_location}" --output "${ova_file_path}"
	curl --silent --show-error "${ova_url_signature}" --output "${ova_file_signature}"
fi

message=$(printf "Verifying signature for '%s'\n" "${ova_file_path}")
msg "${message}"
gpg --no-default-keyring --keyring "${signing_key}.gpg" --verify "${ova_file_signature}" "${ova_file_path}"

message=$(printf "Verifying checksum for '%s'\n" "${ova_file_path}")
msg "${message}"
message=$(printf "%s %s" "${ova_sha256}" "${ova_file_path}" | sha256sum --check)
msg "${message}"
message=$(printf "Latest CoreOS image available at: %s\n" "${ova_file_path}")
msg "${message}"

msg

# Generating SSH CA
if [[ ! -d "${ca_dir}" ]]; then
	message=$(printf "Ensuring that SSH ca directory '%s' exists.\n" "${ca_dir}")
	msg "${message}"
	mkdir -p "${ca_dir}"
fi

if [[ ! -f "${ca_file}" ]]; then
	message=$(printf "Generating OpenSSH CA Key Pair at %s\n" "${ca_dir}")
	msg "${message}"

	ssh-keygen -q -f "${ca_file}" \
		-t rsa \
		-b 4096 \
		-N "" \
		-C "Demo CA"
fi

# Generating SSH client
if [[ ! -d "${client_dir}" ]]; then
	message=$(printf "Ensuring that SSH client directory '%s' exists.\n" "${client_dir}")
	msg "${message}"
	mkdir -p "${client_dir}"
fi

if [[ ! -f "${client_file}" ]]; then
	message=$(printf "Generating OpenSSH client Key Pair at %s\n" "${client_dir}")
	msg "${message}"

	ssh-keygen -q -f "${client_file}" \
		-t ed25519 \
		-N "" \
		-C "Demo Client Key"

	msg "Signing client Key Pair with CA"
	ssh-keygen -q -s "${ca_file}" \
		-t rsa-sha2-512 \
		-I "core client key" \
		-n "core,root" \
		-V "-5m:+1d" \
		-O "no-x11-forwarding" \
		-O "no-agent-forwarding" \
		"${client_dir}/client"

	# moving certificate to a different location to prevent auto-loading
	mv "${client_dir}/client-cert.pub" "${client_dir}/client-certificate.pub"
	ca_cert=$(cat "${ca_file}.pub")
	printf "@cert-authority ssh-* %s" "${ca_cert}" >"${client_dir}/known_cas"
fi

msg "Done"
