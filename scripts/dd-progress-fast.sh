#!/usr/bin/env bash
# Just run `sudo sh dd-progress-fast.sh` with no arguments

echo "Staring dd, please specify source file path and destination path." 

read -p "> Source file full path and name (ex: /media/iso/nixos-21.05.iso): " INFILE
read -p "> You entered '$INFILE'.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

read -p "> Destination full path (ex: /dev/sdd): " OUTFILE
read -p "> You entered '$OUTFILE'.  Is this correct?  (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

dd bs=4M status=progress oflag=sync if=$INFILE of=$OUTFILE 
