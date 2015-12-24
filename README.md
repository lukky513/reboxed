# reboxed

This is repository of *reboxed*, an attempt to make good and easy-to-use xboxdrv wrapper.

Very coarse roadmap:
- create setup script for xboxdrv usage as an regular user (without sudo)
- provide runner daemon for management of configuration and driver itself
- write some default configuration files
- create GUI for bindings and management

Then? That remains to be seen.

## What's done

Setup script for devices, groups and user might be working correctly. So far it was only tested on Arch GNU/Linux, so beware!

You can run it with `./setup.sh`; it will run sudo on it's way. 

To setup more devices, simply plug them in and rerun the script!
