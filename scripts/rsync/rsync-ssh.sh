#!/usr/bin/env bash

# example: rsync-ssh.sh kurtosis@192.168.1.21:/home/kurtosis/Documents/Rainbow/* .

argv="$@"

# original: http://everythinglinux.org/rsync/
#rsync --verbose --progress --stats --compress --rsh=/usr/local/bin/ssh \
#      --recursive --times --perms --links --delete \
#      --exclude "*bak" --exclude "*~" \
#      /www/* webserver:simple_path_name

rsync --recursive --times --perms --links \
      --info=name1,progress1,stats3 --compress --human-readable \
      --exclude="/lost+found" --exclude="*bak" --exclude="*~*" \
      -ae ssh $argv
