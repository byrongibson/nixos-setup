#!/usr/bin/env bash

# takes two arguments, OS name and container name, eg:
# `lxc launch ubuntu:20.04 pristine`

# https://www.srid.ca/lxc-nixos
lxc launch -c security.nesting=true $@ 
