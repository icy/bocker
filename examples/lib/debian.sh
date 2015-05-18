#!/bin/bash

ed_ship ed_apt_clean ed_apt_purge
ed_ship --later ed_ship_later_example
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

ed_ship_later_example() {
  echo "This is an example."
  echo "This is shipped at the end of Dockerfile."
  echo 'Quoting example.'
}
