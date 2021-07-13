#!/usr/bin/env bash

# -x includes explanatory text where available
# -b with no boot number shows journal for current boot
# --list-boots to see all boots  
journalctl -xb
