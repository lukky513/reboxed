#!/bin/bash

cd $(dirname $0)


if [[ $# -lt 1 ]]; then
    echo "This script isn't supposed to be run directly. Use setup.sh instead."
    exit 1
fi


source vars.sh 

# Override with config

if [[ -f $devconf ]]; then
    source $devconf
elif [[ ! -d $(dirname ${devconf}) ]]; then
    mkdir -p $(dirname ${devconf})
fi


function yesreply() {
    read
    [[ $(echo ${REPLY:0:1} | tr Y y) == "y" ]]
    return $?
}

# Save config to ${devconf}
function write_devconf() {
    cat << EOF > ${devconf}
# Autogenerated, do not edit
dev_group=${dev_group}
uin_group=${uin_group}
uin_rules=${uin_rules}
dev_rules=${dev_rules}
configured_devices=(${configured_devices})
EOF
}

# Write udev rules, for every device configured
function write_dev_rules() {
    local dev_match='SUBSYSTEM=="usb", ATTR{idVendor}=="'${1}'", ATTR{idProduct'\
'} =="'${2}'"'
    printf '%s, MODE="0660", OWNER="root" GROUP="%s"\n' "${dev_match}" "${dev_group}" >> $dev_rules
    printf 'ACTION=="add", %s, RUN+="/sbin/modprobe -r xpad"\n' "${dev_match}" >> $dev_rules
    printf 'ACTION=="add", %s, RUN+="/sbin/modprobe uinput"\n' "${dev_match}" >> $dev_rules
}


# Write general udev rules - permissions for created devices
function write_general_rules() {
    local rule_pattern='KERNEL=="%s*", SUBSYSTEMS=="input", ATTRS{name}=="Xbox'\
' Gamepad (userspace driver)", NAME="input/%%k", MODE:="%s", GROUP:="%s"\n'
    printf "# reboxed rules for xboxdrv\n" > $dev_rules
    printf "# script-generated, do not edit\n" >> $dev_rules
    printf "${rule_pattern}" "event" "0660" ${dev_group} >> $dev_rules
    # found 0664 to be default for js* for some reason
    printf "${rule_pattern}" "js" "0664" ${dev_group} >> $dev_rules
}


# Write uinput access rule; kicks in on uinput module load
function write_uinput_rules() {
    local mode
    
    # attempt to trigger existing rules
    modprobe uinput

    let mode=(0$(stat -c %a /dev/uinput) \| 0060)
    printf 'KERNEL=="uinput", MODE:="%04o", GROUP:="%s"\n' ${mode} ${uin_group} > $uin_rules
}

# Look for yet unconfigured devices; write rules for them
function check_devices() {
    local found=()

    for dev in "${supported_devices[@]}"; do
        if lsusb -d $dev > /dev/null; then
            found[${#found[@]}]=${dev} 
        fi
    done
    
    local diffs=($(echo ${found[@]} ${configured_devices[@]} | tr ' ' '\n' | sort | uniq -u))

    for dev in "${diffs[@]}"; do
        local vid=${dev:0:4}
        local pid=${dev:5:4}
        echo "Writing rules for device, vid: ${vid} pid: ${pid}" 
        write_dev_rules "${vid}" "${pid}"
    done

    configured_devices="${found[@]}"
}

function check_dev_group() {
    local group=""
    local dev_found=()

    for dev in "${supported_devices[@]}"; do
        if lsusb -d $dev > /dev/null; then
            dev_found[${#dev_found[@]}]=${dev} 
        fi
    done

    for dev in "${dev_found[@]}"; do
        local path=$(lsusb -d $dev | awk -F'[: ]+' '{print "/dev/bus/usb/" $2 "/" $4}')
        local found=$(stat -c %G ${path})
        if [[ $found != "root" ]]; then
            # is the non-root group we found the only one?
            if [[ $group == "" ]]; then
                group=$found
            elif [[ $group != $found ]]; then
                echo "Devices already belong to more than one non-root group! Aborting."
                exit 1
            fi

            # does that other group provide required permissions?
            if (( 0$(stat -c %a ${path}) & 060 != 060 )); then
                echo "Devices belong to group with insufficient permissions! Aborting."
                exit 2
            fi 
        fi
    done

    if [[ $group != "" ]]; then
        echo "One or more of devices had '${group}' group. Do you want to use this group? [y/n]:"
        if yesreply; then
            dev_group=${group}
        else
            echo "Aborting."
            exit 3
        fi
    fi
}

function check_uin_group() {
    modprobe uinput

    local group="$(stat -c %G /dev/uinput)"

    if [[ $group != "root" ]]; then
        if (( (0$(stat -c %a /dev/uinput) & 060) != 060 )); then
            echo "/dev/uinput is owned by '${group}' group and has no rw permissions! Aborting."
        else
            echo "/dev/uinput is owned by '${group}' group. Do you want to use this group? [y/n]:"
            if yesreply; then
                uin_group=${group}
            else
                echo "Aborting."
                exit 4
            fi
        fi
    fi
}

if [[ ! -f ${dev_rules} ]]; then
    check_dev_group
    groupadd -f -r ${dev_group}
    write_general_rules
fi

check_devices

if [[ ! -f ${uin_rules} ]]; then
    check_uin_group
    groupadd -f -r ${uin_group}
    write_uinput_rules
fi

write_devconf

# reload rules and trigger them
echo "Reloading udev rules."
udevadm control --reload
udevadm trigger
