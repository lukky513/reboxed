#!/bin/bash

# Initial version of script relies on assumptions found true in Arch
# 1. USB devices were root:root with 0640 mask
# 2. /dev/uinput was root:root with 0600 mask
# 3. xpad module has to be blacklisted/unloaded
# 4. uinput module isn't loaded neither by default, nor while running xboxdrv
#    as a regular user
# 5. jsX and eventX weren't created with permissions required

# Solving them should create no problems, if possible - namely: 
# 1, 2 - we shouldn't take away anyone's access - devices should be safe as long
# as there's no one in root group other than root; uinput has no group perms
# 3, 4 - it's better to unload&load when needed; this requires module management
# capabilities, though, or being root
# 5 - solution has to be possibly narrow and precise 

# These are solved by:
# 1. Devices: if group equals 'root', create group - default: xboxdrv; add
#    current user; write udev rules with root:xboxdrv, |0060 mask
# 2. /dev/uinput: if there are no group permissions and group equals 'root',
#    create group - default: uinput, add user, write rules with root:uinput and
#    |0060 mask
# 3, 4 - blacklist and load globally, or use a wrapper with capabilities
# 5. Write udev rule using assumptions on xboxdrv device ATTRs 

# Commence.
 
cd $(dirname $0)

source setup/vars.sh

username=${1:-$(whoami)}

echo "Setting up/verifying devices..."
if sudo setup/device-setup.sh $username; then
    echo "Devices configured."
else
    echo "Problems with device configuration, aborting setup."
    exit 1
fi

source ${devconf}

echo "Adding ${username} to required groups." 
echo "Adding to '${dev_group}'."
sudo usermod -aG ${dev_group} ${username}
echo "Adding to '${uin_group}'."
sudo usermod -aG ${uin_group} ${username}
echo "Done. You might need to restart your desktop environment for the group \
membership to work. When done, try running xboxdrv."
