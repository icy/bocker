#!/bin/bash
#
# Purpose: A Dockerfile compiler
# Author : Anh K. Huynh <kyanh@theslinux.org>
# License: MIT
#
# Copyright © 2015 Anh K. Huynh
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the “Software”), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall
# be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

set -u

export BOCKER_VERSION=1.1.1

ed_reset() {
  for _matter in \
    ${@:-\
      __MATTER_ENV__ \
      __MATTER_ONBUILD__ \
      __MATTER_VOLUME__ \
      __MATTER_EXPOSE__
    }; \
  do
    export $_matter=
  done
}

ed_from() {
  export __FROM="$@"
}

ed_maintainer() {
  export __MAINTAINER="$@"
}

ed_env() {
  local _name="$1"; shift
  export __MATTER_ENV__="${__MATTER_ENV__:-}^x^x^ENV ${_name^^} $@"
}

ed_onbuild() {
  export __MATTER_ONBUILD__="${__MATTER_ONBUILD__:-}^x^x^ONBUILD $@"
}

ed_expose() {
  while (( $# )); do
    export __MATTER_EXPOSE__="${__MATTER_EXPOSE__:-}^x^x^EXPOSE $1"
    shift
  done
}

ed_ship() {
  if [[ "${1:-}" == "--later" ]]; then
    shift
    while (( $# )); do
      export __MATTER_SHIP_LATER__="${__MATTER_SHIP_LATER__:-}^x^x^$1"
      shift
    done
    return
  fi

  # later => 0
  while (( $# )); do
    export __MATTER_SHIP__="${__MATTER_SHIP__:-}^x^x^$1"
    shift
  done
  return 0
}

ed_volume() {
  while (( $# )); do
    export __MATTER_VOLUME__="${__MATTER_VOLUME__:-}^x^x^VOLUME $1"
    shift
  done
}

ed_cmd() {
  export __MATTER_CMD__="CMD $@"
}

ed_entrypoint() {
  export __MATTER_ENTRYPOINT__="ENTRYPOINT $@"
}

__ed_bocker_filter() {
  echo "ed_bocker()"
  echo "{"
  for _idx in ${!__MATTER_ED_BOCKER__[@]}; do
    echo ${__MATTER_ED_BOCKER__[$_idx]} \
    | base64 -d \
    | awk '{if (NR>2) print}' \
    | sed -e '$d' \
    | sed -e 's#\b\(ed_[a-z0-9]\+\)#__ed_ship_method \1#gi'
  done
  echo "}"
}

__ed_method_definition() {
  declare -f "${1}"
}

__do_matter() {
  local _sort_args="${@:--uk1}"

  sed -e 's,\^x^x^,\n,g' \
  | sed -e '/^[[:space:]]*$/d' \
  | sort $_sort_args
}

__ed_ensure_method() {
  if [[ "$(type -t ${1:-})" != "function" ]]; then
    echo >&2 ":: Bocker: method '${1:-}' not found or not a function"
    return 1
  fi
}

__ed_ship_encoded_data() {
  echo "#"
  echo $@ | sed -e 's# ##g' | base64 -d | awk '{printf("# | %s\n", $0);}'
  echo "#"
  echo "RUN echo \\"
  echo $@ | sed -e 's# #\n#g' | while read __; do echo "${__}\\"; done
  echo "  | base64 -d | bash"
}

__ed_ship_method() {
  local _nextop="$1"
  local _methods=""
  local _count=0

  case $_nextop in
  "ed_add")      shift; echo ""; echo "ADD $@"; return 0 ;;
  "ed_copy")     shift; echo ""; echo "COPY $@"; return 0 ;;
  "ed_user")     shift; echo ""; echo "USER $@"; return 0 ;;
  "ed_workdir")  shift; echo ""; echo "WORKDIR $@"; return 0 ;;
  "ed_run")      shift; echo ""; echo "RUN $@"; return 0;;
  "ed_group")    shift; _nextop="$@" ;;
  esac

  for METHOD in $_nextop; do
    [[ "$METHOD" != "$FUNCNAME" ]] \
    || continue

    __ed_ensure_method $METHOD || exit 127
    _methods="${_methods:+$_methods }$METHOD"
    let _count++
  done

  if [[ -z "$_methods" ]]; then
    echo >&2 ":: $FUNCNAME: Warning: ed_group has no element."
    return 0
  fi

  _encoded_data="$(
    {
      echo "set -eux"
      echo "if [[ -f /bocker.sh ]]; then source /bocker.sh; fi"
      for METHOD in $_methods; do
        __ed_method_definition $METHOD
      done
      for METHOD in $_methods; do
        echo $METHOD
      done
    } \
    | base64 -w71
  )"

  echo ""
  if [[ $_count -ge 2 ]]; then
    echo "# Bocker methods:"
    for METHOD in $_methods; do
      echo "# - $METHOD"
    done
  else
    echo "# Bocker method => $_methods"
  fi
  __ed_ship_encoded_data $_encoded_data
}

__ed_ship() {
  local _methods=

  if [[ "${1:-}" == "--later" ]]; then
    shift
    _methods="$(echo "${__MATTER_SHIP_LATER__:-}" | __do_matter -uk1)"
  else
    _methods="$(echo "${__MATTER_SHIP__:-}" | __do_matter -uk1)"
  fi

  [[ -n "$_methods" ]] || return 0

  for METHOD in $_methods; do
    __ed_ensure_method $METHOD || return 127
  done

  echo ""
  echo "# Bocker method => $FUNCNAME"
  echo "# * The output is /bocker.sh in the result image."
  echo "# * List of methods:"
  for METHOD in $_methods; do
    echo "#   - $METHOD"
  done

  _encoded_data="$(
    {
      echo "set -eux"
      echo "if [[ -f /bocker.sh ]]; then source /bocker.sh; fi"

      for METHOD in $_methods; do
        __ed_method_definition $METHOD
      done

      echo "echo '#!/bin/bash' > /bocker.sh"
      echo "echo '# This file is generated by Bocker.' >> /bocker.sh"
      echo "declare -f >> /bocker.sh"
      echo "echo 'if [[ -n \"\$@\" ]]; then \$@; fi; ' >> /bocker.sh"
      echo "chmod 755 /bocker.sh"
    } \
    | base64 -w71
  )"

  __ed_ship_encoded_data $_encoded_data
}

ed_reuse() {
  for f in $@; do
    source $f || exit 1
    if [[ "$(type -t ed_bocker 2>/dev/null)" == "function" ]]; then
      __MATTER_ED_BOCKER__+=( $(__ed_method_definition ed_bocker | base64 -w0) )
    fi
  done
}

########################################################################
# All default settings
########################################################################

ed_from        debian:wheezy
ed_maintainer  "Anh K. Huynh <kyanh@theslinux.org>"
ed_env         DEBIAN_FRONTEND noninteractive
ed_reset       # reset all environments

readonly -f \
  __do_matter \
  __ed_bocker_filter \
  __ed_method_definition \
  __ed_ship \
  __ed_ship_method \
  __ed_ship_encoded_data \
  __ed_ensure_method \
  ed_cmd \
  ed_entrypoint \
  ed_env \
  ed_expose \
  ed_from \
  ed_maintainer \
  ed_onbuild \
  ed_reset \
  ed_reuse \
  ed_ship \
  ed_volume

readonly BOCKER_VERSION

export __MATTER_ED_BOCKER__=()

########################################################################
# Print version information
########################################################################

for _arg in "$@"; do
  case "$_arg" in
  "-v"|"--version")
      echo >&2 ":: Bocker version v$BOCKER_VERSION"
      exit 1
  esac
done

########################################################################
# Now loading all users definitions
########################################################################

for f in $@; do
  ed_reuse $f || exit
done

########################################################################
# Basic checks
########################################################################

__ed_ensure_method ed_bocker \
|| {
  echo >&2 ":: Syntax: $0 Bockerfile(s)..."
  exit 127
}

########################################################################
# Shipping the contents
########################################################################

echo "###############################################################"
echo "# Dockerfile generated by Bocker-v${BOCKER_VERSION%.*}. Do not edit this file. #"
echo "###############################################################"

echo ""
echo "FROM $__FROM"
echo "MAINTAINER $__MAINTAINER"

if [[ -n "${__MATTER_ENV__:-}" ]]; then
  echo ""
  echo "${__MATTER_ENV__:-}" | __do_matter -uk1
fi

__ed_ship || exit 127

while read METHOD; do
  export -f $METHOD
done < <(declare -fF | awk '{print $NF}')

bash < <(__ed_bocker_filter; echo ed_bocker) || exit

__ed_ship --later || exit 127

if [[ -n "${__MATTER_VOLUME__:-}" ]]; then
  echo ""
  echo "${__MATTER_VOLUME__:-}" | __do_matter -uk1
fi

if [[ -n "${__MATTER_EXPOSE__:-}" ]]; then
  echo ""
  echo "${__MATTER_EXPOSE__:-}" | __do_matter -unk2
fi

if [[ -n "${__MATTER_CMD__:-}" ]]; then
  echo ""
  echo "${__MATTER_CMD__:-}" | __do_matter -uk1
fi

if [[ -n "${__MATTER_ENTRYPOINT__:-}" ]]; then
  echo ""
  echo "${__MATTER_ENTRYPOINT__:-}" | __do_matter -uk1
fi

if [[ -n "${__MATTER_ONBUILD__:-}" ]]; then
  echo ""
  echo "${__MATTER_ONBUILD__:-}" | __do_matter -k1
fi
