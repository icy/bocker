#!/bin/bash

ed_ship apt_clean apt_purge
ed_env  DEBIAN_FRONTEND noninteractive

ed_apt_clean() {
  rm -fv /var/cache/apt/*.bin
  rm -fv /var/cache/apt/archives/*.*
  rm -fv /var/lib/apt/lists/*.*
  apt-get autoclean
}

ed_apt_purge() {
  apt-get purge -y --auto-remove $@
  ed_apt_clean
}
