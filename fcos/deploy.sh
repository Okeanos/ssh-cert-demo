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
Deploy the SSH Certificate example for a particular VM.
Available options:
-h, --help             Print this help and exit
-v, --verbose          Print script debug info
-b, --bu-file          Path to the bu config to use for provisioning
-e, --debug            Enable extra debugging of the VM via Serial Connection logging
-l, --library          VMWare Library name to store the VM in (defaults to '~/Virtual Machines.localized')
-n, --name             Name of the VM to create
-o, --ova              Path where CoreOS image is stored
-p, --prefix           Prefix for the VM names for easier identification in VMWare, defaults to 'fcos-'
EOF
	exit
}

cleanup() {
	trap - SIGINT SIGTERM ERR EXIT
	# script cleanup here

	if [[ -n "${buInc}" ]]; then
		if [[ -n "${commonConfig}" ]]; then
			for tmp in "${commonConfig}"/*; do
				tmpName=$(realpath --canonicalize-missing "${buInc}/$(basename "${tmp}")")
				message=$(printf "Removing temporary common config from '%s'\n" "${tmpName}")
				[[ $verbose == 1 ]] && msg "${message}"
				rm -rf "${tmpName}"
			done
		fi
		for tmp in "${buInc}/ssh/ssh_host_"*; do
			tmpName=$(realpath --canonicalize-missing "${buInc}/ssh/$(basename "${tmp}")")
			message=$(printf "Removing temporary SSH host key from '%s'\n" "${tmpName}")
			[[ $verbose == 1 ]] && msg "${message}"
			rm -f "${tmpName}"
		done
		if [[ -f "${buInc}/ssh/ssh_user_ca.pub" ]]; then
			message=$(printf "Removing temporary SSH user signing certificate from '%s'\n" "${buInc}/ssh/ssh_user_ca.pub")
			[[ $verbose == 1 ]] && msg "${message}"
			rm -f "${buInc}/ssh/ssh_user_ca.pub"
		fi
	fi
	if [[ -n "${ign_config_file}" ]]; then
		message=$(printf "Removing Ignition file from '%s'\n" "${ign_config_file}")
		[[ $verbose == 1 ]] && msg "${message}"
		rm -f "${ign_config_file}"
	fi
	if [[ -n "${ign_config_b64_file}" ]]; then
		message=$(printf "Removing Ignition file from '%s'\n" "${ign_config_b64_file}")
		[[ $verbose == 1 ]] && msg "${message}"
		rm -f "${ign_config_b64_file}"
	fi
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
	bu=''
	debug=0
	hostSigningKey=''
	library=$(realpath --canonicalize-missing "${HOME}/Virtual Machines.localized")
	name=''
	ovaFilePath=''
	prefix='fcos-'
	verbose=0

	while :; do
		case "${1-}" in
		-h | --help) usage ;;
		-v | --verbose) set -x ;;
		--no-color) NO_COLOR=1 ;;
		-b | --bu-file)
			bu="${2-}"
			shift
			;;
		-e | --debug)
			debug=1
			;;
		-l | --library)
			library="${2-}"
			shift
			;;
		-n | --name)
			name="${2-}"
			shift
			;;
		-o | --ova)
			ovaFilePath="${2-}"
			shift
			;;
		-?*) die "Unknown option: $1" ;;
		*) break ;;
		esac
		shift
	done

	# check required params and arguments
	[[ -z "${bu-}" ]] && die "Missing required parameter: bu-file"
	[[ -z "${name-}" ]] && die "Missing required parameter: name"
	[[ -z "${ovaFilePath-}" ]] && die "Missing required parameter: ova"

	return 0
}

parse_params "$@"
setup_colors

# script logic here
bu=$(realpath --canonicalize-missing "${bu}")
buDir=$(dirname "${bu}")
buInc=$(realpath --canonicalize-missing "${buDir}/includes")
commonConfig=$(realpath --canonicalize-missing "${buDir}/../common")
hostSigningKey=$(realpath --canonicalize-missing "${buDir}/../ca/ca")
[[ ! -f "${hostSigningKey-}" ]] && die "Parameter 'host-signing-key' does not point to an existing SSH key file"
ign_config=''
ovaFilePath=$(realpath --canonicalize-missing "${ovaFilePath}")
[[ ! -f "${ovaFilePath-}" ]] && die "Parameter 'ova' does not point to an existing CoreOS image file"

msg "Creating SSH Host Keys"
ssh-keygen -t ecdsa -N "" -f "${buInc}/ssh/ssh_host_ecdsa_key" -C "${name},${name}.local"
ssh-keygen -t ed25519 -N "" -f "${buInc}/ssh/ssh_host_ed25519_key" -C "${name},${name}.local"
ssh-keygen -t rsa -b 4096 -N "" -f "${buInc}/ssh/ssh_host_rsa_key" -C "${name},${name}.local"

msg "Creating signed SSH certificates"
ssh-keygen -s "${hostSigningKey}" \
	-t rsa-sha2-512 \
	-I "${name} host key" \
	-n "${name},${name}.local" \
	-V "-5m:+1d" \
	-h \
	"${buInc}/ssh/ssh_host_ecdsa_key" \
	"${buInc}/ssh/ssh_host_ed25519_key" \
	"${buInc}/ssh/ssh_host_rsa_key"

message=$(printf "Temporarily copying common config from '%s' to '%s'\n" "${commonConfig}" "${buInc}")
msg "${message}"
cp -fr "${commonConfig}/." "${buInc}"
cp -fr "${hostSigningKey}.pub" "${buInc}/ssh/ssh_user_ca.pub"

msg

message=$(printf "Converting bu file '%s' to ign config\n" "${bu}")
msg "${message}"
ign_config=$(butane --strict --files-dir="${buInc}" "${bu}")
ign_config_file=$(realpath --canonicalize-missing "${buDir}/coreos.ign")
echo "${ign_config}" >"${ign_config_file}"
ign_config_b64=$(butane --strict --files-dir="${buInc}" "${bu}" | gzip | base64 -w0)
ign_config_b64_file=$(realpath --canonicalize-missing "${buDir}/coreos.ign.gzip.b64")
echo "${ign_config_b64}" >"${ign_config_b64_file}"

msg

msg "\nIgnition configuration transpiled and CoreOS Template available; will now deploy to VMWare\n\n"
message=$(printf "Deploying '%s'\n" "${prefix}${name}")
msg "${message}"

ovftool \
	--powerOffTarget \
	--overwrite \
	--name="${prefix}${name}" \
	--maxVirtualHardwareVersion=21 \
	--allowExtraConfig \
	--extraConfig:guestinfo.hostname="${name}" \
	--extraConfig:guestinfo.ignition.config.data.encoding="gzip+base64" \
	--extraConfig:guestinfo.ignition.config.data="${ign_config_b64}" \
	"${ovaFilePath}" "${library}"

# Migrate to current HW level for better support
vmcli "${library}/${prefix}${name}.vmwarevm/${prefix}${name}.vmx" configparams setentry 'virtualhw.version' 21

if [[ $debug == 1 ]]; then
	if [[ -f "${script_dir}/${name}/serial-output" ]]; then
		rm -f "${script_dir}/${name}/serial-output"
	fi
	vmcli "${library}/${prefix}${name}.vmwarevm/${prefix}${name}.vmx" serial SetBackingInfo \
		serial0 \
		file \
		"${script_dir}/${name}/serial-output" \
		'' \
		server \
		server
fi

vmcli "${library}/${prefix}${name}.vmwarevm/${prefix}${name}.vmx" power start
