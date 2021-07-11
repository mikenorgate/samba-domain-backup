#!/bin/bash

set -e

IP_ADDRESS="${1}"
OUTPUT="${2}"

help() {
	local help
	read -r -d '' help << EOM
Usage: docker run [-it] --rm -v <target_dir>:<output_dir> mikenorgate/samba-backup ip_address output_file
EOM
	echo "$help"
	exit 1
}

if [[ -z "$IP_ADDRESS" ]]; then
  help
fi

if [[ -z "$OUTPUT" ]]; then
  help
fi

mkdir /backup
mkdir ~/.ssh

echo "HostName $IP_ADDRESS" > ssh_config
echo "User pi" >> ssh_config
echo "ControlMaster auto" >> ssh_config
echo "ControlPath ~/.ssh/%C" >> ssh_config
echo "StrictHostKeyChecking no" >> ssh_config
master_ssh='ssh -F ssh_config'

$master_ssh -MNf $IP_ADDRESS
trap cleanup EXIT
function cleanup {
	echo "Cleanup temporary files"
	if [[ -n "$target_dir" ]]; then
		$master_ssh $IP_ADDRESS "sudo rm -r $target_dir"
	fi
	$master_ssh -O exit $IP_ADDRESS
}

IFS=" " read -a ERRORS <<< `$master_ssh $IP_ADDRESS "sudo samba-tool dbcheck" | tail -1`

if [ ${ERRORS[3]//(} -gt 0 ]
then
	echo "samba-tool dbcheck reported errors"
	exit 3
fi

target_dir=$($master_ssh $IP_ADDRESS "mktemp -d")

$master_ssh $IP_ADDRESS "sudo samba-tool domain backup offline --targetdir=$target_dir"

backup_file=$($master_ssh $IP_ADDRESS "files=($target_dir/*) && echo \${files[0]}")

scp -F ssh_config $IP_ADDRESS:$backup_file $OUTPUT