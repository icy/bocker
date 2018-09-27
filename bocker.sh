#!/usr/bin/env bash
#
# Purpose: A Dockerfile compiler
# Author : Anh K. Huynh <kyanh@theslinux.org>
# License: MIT
#
# Copyright © 2015 - 2018 Ky-Anh Huynh
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

# The bocker version. We change this for every new release
export BOCKER_VERSION=1.3.0

# Where the Bocker script takes place in the result container
export BOCKER_SH="${BOCKER_SH:-/bocker.sh}"

# The default shell of result container. Default to `bash`.
# For alpine system, you may need to use `/bin/sh`. Image developer
# may change this by using `ed_shell` instruction.
export BOCKER_SHELL="${BOCKER_SHELL:-/usr/bin/env bash}"

# The separator internally used by Bocker to build Dockerfile.
# Hopefully developer will not use this to trick Bocker :)
# shellcheck disable=2155
export BOCKER_DOT="$(printf \\u2694\\u2620\\u2694)" # ⚔☠⚔

readonly BOCKER_DOT
readonly BOCKER_VERSION
readonly BOCKER_SH

# Reset some environments / settings. This is useful, e.g, when you
# want to un-expose something from the previous layer (port, volume).
#
# The following invocations are the same
#
#   ed_reset __MATTER_ENV
#   ed_reset env
#   ed_reset ENV
#
# Historically, the method is intended for some special uses, hence
# the first form (__MATTER_ENV) is provided. But in practice, the
# method becomes more and more useful. Hence, the two later forms
# are also supported.
#
# By default, when being invoked without any arguments, the method
# will reset all important matters: ENV, ONBUILD, VOLUME, EXPOSE.
#
# shellcheck disable=2120
ed_reset() {
  # shellcheck disable=2068
  for _matter in \
    ${@:-\
      __MATTER_ENV__ \
      __MATTER_ONBUILD__ \
      __MATTER_LABEL__ \
      __MATTER_VOLUME__ \
      __MATTER_EXPOSE__
    }; \
  do
    case "${_matter:0:9}" in
    "__MATTER_") ;;
    *) _matter="__MATTER_${_matter^^}__";;
    esac

    export "${_matter}"=
  done
}

ed_from() {
  export __FROM="$*"
}

ed_maintainer() {
  export __MAINTAINER="$*"
}

ed_env() {
  if [[ "${1:-}" == "--later" ]]; then
    shift
    export __MATTER_ENV_LATER__="${__MATTER_ENV_LATER__:-}${BOCKER_DOT}ENV $*"
    return
  fi

  export __MATTER_ENV__="${__MATTER_ENV__:-}${BOCKER_DOT}ENV $*"
  return 0
}

ed_copy() {
  local _later=0
  local _add=0

  while (( $# )); do
    case "$1" in
      "--later") _later=1; shift ;;
      "--add")   _add=1; shift ;;
      *)  break;
    esac
  done

  if [[ "$_later" == 0 ]]; then
    echo >&2 ":: ${FUNCNAME[0]}: Can't use in preamble without --later option"
    exit 1
  fi

  if [[ "$_add" == "1" ]]; then
    export __MATTER_ADD_LATER__="${__MATTER_ADD_LATER__:-}${BOCKER_DOT}ADD $*"
  else
    export __MATTER_COPY_LATER__="${__MATTER_COPY_LATER__:-}${BOCKER_DOT}COPY $*"
  fi
}

ed_onbuild() {
  export __MATTER_ONBUILD__="${__MATTER_ONBUILD__:-}${BOCKER_DOT}ONBUILD $*"
}

ed_user() {
  if [[ "${1:-}" != "--later" ]]; then
    echo >&2 ":: ${FUNCNAME[0]}: Can't use in preamble without --later option"
    exit 1
  fi

  shift
  export __MATTER_USER_LATER__="USER $*"
}

ed_expose() {
  while (( $# )); do
    export __MATTER_EXPOSE__="${__MATTER_EXPOSE__:-}${BOCKER_DOT}$1"
    shift
  done
}

ed_ship() {
  if [[ "${1:-}" == "--later" ]]; then
    shift
    while (( $# )); do
      export __MATTER_SHIP_LATER__="${__MATTER_SHIP_LATER__:-}${BOCKER_DOT}$1"
      shift
    done
    return
  fi

  # later => 0
  while (( $# )); do
    export __MATTER_SHIP__="${__MATTER_SHIP__:-}${BOCKER_DOT}$1"
    shift
  done
  return 0
}

ed_label() {
  while (( $# )); do
    export __MATTER_LABEL__="${__MATTER_LABEL__:-}${BOCKER_DOT}$1"
    shift
  done
}

ed_volume() {
  while (( $# )); do
    export __MATTER_VOLUME__="${__MATTER_VOLUME__:-}${BOCKER_DOT}$1"
    shift
  done
}

ed_cmd() {
  export __MATTER_CMD__="CMD $*"
}

ed_entrypoint() {
  export __MATTER_ENTRYPOINT__="ENTRYPOINT $*"
}

ed_shell() {
  export BOCKER_SHELL="$*"
}

# FIXME: The `sed` regexp. only sees two following patterns as *one*:
# FIXME:    ed_foo  , ed_foo-bar
# FIXME: The problem is that, we don't know what is the ending mark.
# FIXME: We only know the starting patern (ed_*).
__ed_bocker_filter() {
  echo "ed_bocker()"
  echo "{"
  while read -r _encoded_data; do
    echo "${_encoded_data}" \
    | base64 -d \
    | awk '{if (NR>2) print}' \
    | sed -e '$d' \
    | sed -e 's#\b\(ed_[a-z0-9-]\+\)#__ed_ship_method \1#gi'
  done < \
    <( \
      # shellcheck disable=2068
      for _idx in ${!__MATTER_ED_BOCKER__[@]}; do
         echo "${__MATTER_ED_BOCKER__[$_idx]}"
      done \
      | awk '!LINES[$0]++'
    )
  echo "}"
}

# Important note: The result format is heavily used by other methods,
# so please don't change, insert or remove anything from this method.
# Just keep it as simple as possible. An example
#
# | foobar()
# | {
# |   # stuff
# | }
#
# The method `__ed_bocker_filter` will remove the first two lines
# and the last line to get the actual body of the definition.
#
__ed_method_definition() {
  declare -f "${1}"
}

__do_matter() {
  local _sort_args="${*:--uk1}"

  # shellcheck disable=2086
  sed -e "s,\\${BOCKER_DOT},\\n,g" \
  | sed -e '/^[[:space:]]*$/d' \
  | sort $_sort_args
}

__ed_ensure_method() {
  if [[ "$(type -t "${1:-}")" != "function" ]]; then
    echo >&2 ":: Bocker: method '${1:-}' not found or not a function"
    return 1
  fi
}

__ed_ship_encoded_data() {
  __ed_echo "#"
  __ed_echo "$@" | sed -e 's# ##g' | base64 -d | awk '{printf("# | %s\n", $0);}'
  __ed_echo "#"
  __ed_echo "RUN echo \\"
  __ed_echo "$@" | sed -e 's# #\n#g' | while read -r __; do echo "${__}\\"; done
  __ed_echo "  | base64 -d | $BOCKER_SHELL"
}

__ed_ship_method() {
  local _nextop="$1"
  local _methods=""
  local _count=0

  case $_nextop in
  "ed_add")      shift; __ed_echo ""; __ed_echo "ADD $*"; return 0 ;;
  "ed_copy")     shift; __ed_echo ""; __ed_echo "COPY $*"; return 0 ;;
  "ed_user")     shift; __ed_echo ""; __ed_echo "USER $*"; return 0 ;;
  "ed_workdir")  shift; __ed_echo ""; __ed_echo "WORKDIR $*"; return 0 ;;
  "ed_run")      shift; __ed_echo ""; __ed_echo "RUN $*"; return 0;;
  "ed_group")    shift; _nextop="${*}" ;;
  esac

  for METHOD in $_nextop; do
    [[ "$METHOD" != "${FUNCNAME[0]}" ]] \
    || continue

    __ed_ensure_method "${METHOD}" || exit 127
    _methods="${_methods:+$_methods }${METHOD}"
    let _count++
  done

  if [[ -z "$_methods" ]]; then
    echo >&2 ":: ${FUNCNAME[0]}: Warning: ed_group has no element."
    return 0
  fi

  _encoded_data="$(
    {
      echo "set -eux"
      echo "if [ -f '$BOCKER_SH' ]; then source '$BOCKER_SH'; fi"
      for METHOD in $_methods; do
        __ed_method_definition "${METHOD}"
      done
      for METHOD in $_methods; do
        echo "${METHOD}"
      done
    } \
    | base64 -w71
  )"

  __ed_echo ""
  if [[ $_count -ge 2 ]]; then
    __ed_echo "# Bocker methods:"
    for METHOD in $_methods; do
      __ed_echo "# - $METHOD"
    done
  else
    __ed_echo "# Bocker method => $_methods"
  fi
  __ed_ship_encoded_data "${_encoded_data}"
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
    __ed_ensure_method "${METHOD}" || return 127
  done

  __ed_echo ""
  __ed_echo "# Bocker method => ${FUNCNAME[0]}"
  __ed_echo "# * The output is ${BOCKER_SH} in the result image."
  __ed_echo "# * List of methods:"
  for METHOD in $_methods; do
    __ed_echo "#   - $METHOD"
  done

  # FIXME: -n may not work correctly in /bin/sh
  _encoded_data="$(
    {
      echo "set -eux"
      echo "if [ -f '${BOCKER_SH}' ]; then source '${BOCKER_SH}'; fi"

      for METHOD in $_methods; do
        __ed_method_definition "${METHOD}"
      done

      echo "echo '#!${BOCKER_SHELL}' > '${BOCKER_SH}'"
      echo "echo '# This file is generated by Bocker.' >> '${BOCKER_SH}'"
      echo "declare -f >> '${BOCKER_SH}'"
      echo "echo 'if [ -n \"\$@\" ]; then \$@; fi; ' >> '${BOCKER_SH}'"
      echo "chmod 755 '${BOCKER_SH}'"
    } \
    | base64 -w71
  )"

  __ed_ship_encoded_data "${_encoded_data}"
}

__ed_before_ship() {
  cat << 'EOF'

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Here is from `__ed_before_ship` method. You may need your own
# custom one to advance the base image when it doesn't have Bash.
#
# The default `__ed_before_ship` method is to print this message.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
EOF
}

ed_reuse() {
  for f in "$@"; do
    # shellcheck disable=1090
    source "${f}" || exit 1
    if [[ "$(type -t ed_bocker 2>/dev/null)" == "function" ]]; then
      __MATTER_ED_BOCKER__+=( "$(__ed_method_definition ed_bocker | base64 -w0)" )
    fi
  done
}

ed_source() {
  for f in "$@"; do
    # shellcheck disable=1090
    source "${f}" || exit 1
  done
}

__ed_echo() {
  [[ "${__MATTER_DRY_RUN__:-0}" == "1" ]] \
  || echo "$@"
}

########################################################################
# All default settings
########################################################################

ed_from        debian:wheezy
ed_maintainer  "Anh K. Huynh <kyanh@theslinux.org>"
ed_env         DEBIAN_FRONTEND noninteractive
# shellcheck disable=2119
ed_reset       # reset all environments

readonly -f \
  __do_matter \
  __ed_bocker_filter \
  __ed_echo \
  __ed_ensure_method \
  __ed_method_definition \
  __ed_ship \
  __ed_ship_encoded_data \
  __ed_ship_method \
  ed_cmd \
  ed_copy \
  ed_entrypoint \
  ed_env \
  ed_expose \
  ed_from \
  ed_label \
  ed_maintainer \
  ed_onbuild \
  ed_reset \
  ed_reuse \
  ed_ship \
  ed_source \
  ed_user \
  ed_volume

export __MATTER_ED_BOCKER__=()
export __MATTER_DRY_RUN__=0

########################################################################
# Print version information
########################################################################

while (( $# )); do
  case "$1" in
  "-v"|"--version")
      echo >&2 ":: Bocker version v$BOCKER_VERSION"
      exit 1
      ;;
  "-t"|"--test")
      shift;
      echo >&2 ":: Bocker test mode enabled. Nothing is printed."
      export __MATTER_DRY_RUN__=1
      ;;
  *)  # stop at the first non-option argument
      break;
  esac
done

########################################################################
# Now loading all users definitions
########################################################################

for f in "${@}"; do
  ed_reuse "${f}" || exit
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

__ed_echo "###############################################################"
__ed_echo "# Dockerfile generated by Bocker-v${BOCKER_VERSION%.*}. Do not edit this file. #"
__ed_echo "###############################################################"

__ed_echo ""
__ed_echo "FROM $__FROM"
__ed_echo "MAINTAINER $__MAINTAINER"

if [[ -n "${__MATTER_ENV__:-}" ]]; then
  __ed_echo ""
  __ed_echo "${__MATTER_ENV__:-}" | __do_matter -uk1
fi

__ed_before_ship

__ed_ship || exit 127

while read -r METHOD; do
  # shellcheck disable=2163
  export -f "${METHOD}"
done < <(declare -fF | awk '{print $NF}')

bash < <(__ed_bocker_filter; echo ed_bocker) || exit

__ed_ship --later || exit 127

if [[ -n "${__MATTER_ENV_LATER__:-}" ]]; then
  __ed_echo ""
  __ed_echo "${__MATTER_ENV_LATER__:-}" | __do_matter -uk1
fi

if [[ -n "${__MATTER_ADD_LATER__:-}" ]]; then
  __ed_echo ""
  __ed_echo "${__MATTER_ADD_LATER__:-}" | __do_matter -uk1
fi

if [[ -n "${__MATTER_COPY_LATER__:-}" ]]; then
  __ed_echo ""
  __ed_echo "${__MATTER_COPY_LATER__:-}" | __do_matter -uk1
fi

if [[ -n "${__MATTER_LABEL__:-}" ]]; then
  __ed_echo ""
  __ed_echo "LABEL$(echo "${__MATTER_LABEL__:-}" | __do_matter -uk1 | awk '{printf(" %s", $0)}')"
fi

if [[ -n "${__MATTER_VOLUME__:-}" ]]; then
  __ed_echo ""
  __ed_echo "VOLUME$(echo "${__MATTER_VOLUME__:-}" | __do_matter -uk1 | awk '{printf(" %s", $0)}')"
fi

if [[ -n "${__MATTER_EXPOSE__:-}" ]]; then
  __ed_echo ""
  __ed_echo "EXPOSE$(echo "${__MATTER_EXPOSE__:-}" | __do_matter -unk1 | awk '{printf(" %s", $0)}')"
fi

if [[ -n "${__MATTER_USER_LATER__:-}" ]]; then
  __ed_echo ""
  __ed_echo "${__MATTER_USER_LATER__:-}" | __do_matter -uk1
fi

if [[ -n "${__MATTER_CMD__:-}" ]]; then
  __ed_echo ""
  __ed_echo "${__MATTER_CMD__:-}" | __do_matter -uk1
fi

if [[ -n "${__MATTER_ENTRYPOINT__:-}" ]]; then
  __ed_echo ""
  __ed_echo "${__MATTER_ENTRYPOINT__:-}" | __do_matter -uk1
fi

if [[ -n "${__MATTER_ONBUILD__:-}" ]]; then
  __ed_echo ""
  __ed_echo "${__MATTER_ONBUILD__:-}" | __do_matter -k1
fi
