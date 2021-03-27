#!/bin/bash
# vim: set filetype=sh:
# shellcheck disable=SC2236  # prefer [ ! -z ] for readability over [ -n ]
set -o nounset;  # Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o pipefail; # Catch the error in case a piped command fails
# set -o errexit;  # Exit on error. Append "|| true" if you expect an error. Same as 'set -e'
# set -o errtrace; # Exit on error inside any functions or subshells.
# set -o xtrace;   # Turn on traces, useful while debugging (short form: on: 'set -x' off: 'set +x')

################################################################################
# Helpers

readonly SCRIPTNAME=$(basename "$0")
#readonly SCRIPTDIR=$(readlink -m "$(dirname "$0")")

DEBUG=

help() {
cat<<EOF
USAGE:
  $SCRIPTNAME <options> apk|appbundle

ARGUMENTS:
  apk|appbundle

OPTIONS:
  -c|--clean: clean build
  -h|--help: print this help
EOF
exit 1
}

# Logging: these all log to stderr
die() { >&2 colorecho red "FATAL: $*"; exit 1; }
die_with_rc() { local rc=$1; shift; >&2 colorecho red "FATAL: $*, rc=$rc"; exit "$rc"; }
check_rc_die() { local rc=$1; shift; [ "$rc" != "0" ] && die_with_rc "$rc" "$@"; return 0; }
log_error() { >&2 colorecho red "ERROR: $*"; }
log_warn() { >&2 colorecho orange "WARN: $*"; }
log_info() { >&2 echo "$*"; }
log_debug() { if [ -n "$DEBUG" ]; then >&2 echo "DEBUG: $*"; fi; }
log_progress() { >&2 colorecho green "$*"; }
get_logdate() { date '+%Y-%m-%d %H:%M:%S'; }  # eg: log_info "$(get_logdate) My log message"
# Optionals to log output to file (see http://mywiki.wooledge.org/BashFAQ/106)
redirect_output_to_file() { exec >"/tmp/${SCRIPTNAME%.*}.log" 2>&1; }  # output to file only
tee_output_to_file() { exec > >(tee "/tmp/${SCRIPTNAME%.*}.log") 2>&1; } # output to console and file

colorecho() {  # usage: colorecho <colour> <text> or colorecho -n <colour> <text>
  local echo_arg=
  if [ "$1" = "-n" ]; then echo_arg="-n"; shift; fi
  local colour="$1"; shift
  case "${colour}" in
    red) echo $echo_arg -e "$(tput setaf 1)$*$(tput sgr0)"; ;;
    green) echo $echo_arg -e "$(tput setaf 2)$*$(tput sgr0)"; ;;
    green-bold) echo $echo_arg -e "$(tput setaf 2; tput bold)$*$(tput sgr0)"; ;;
    yellow) echo $echo_arg -e "$(tput setaf 3; tput bold)$*$(tput sgr0)"; ;;
    orange) echo $echo_arg -e "$(tput setaf 3)$*$(tput sgr0)"; ;;
    blue) echo $echo_arg -e "$(tput setaf 4)$*$(tput sgr0)"; ;;
    purple) echo $echo_arg -e "$(tput setaf 5)$*$(tput sgr0)"; ;;
    cyan) echo $echo_arg -e "$(tput setaf 6)$*$(tput sgr0)"; ;;
    bold) echo $echo_arg -e "$(tput bold)$*$(tput sgr0)"; ;;
    normal|*) echo $echo_arg -e "$*"; ;;
  esac
}


################################################################################
# Script Functions
build_clean() {
  log_progress "clean"
  flutter clean
}

build_apk() {
  rm -f ~/sync/scratch-mobile/app-arm64-v8a-*.apk
  log_progress "building apk --split-per-abi $arg_debug"
  #flutter build apk --target-platform android-arm64 --split-per-abi && cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk ~/sync/scratch-mobile/
  #shellcheck disable=SC2086
  if flutter build apk --split-per-abi $arg_debug; then
    cp build/app/outputs/flutter-apk/app-arm64-v8a-*.apk ~/sync/scratch-mobile/
    log_progress "Successful build"
  fi
}

build_appbundle() {
  flutter build appbundle
}


################################################################################
# Main

main() {
  local arg_clean=
  local arg_cmd=
  local arg_debug=
  while [ $# -gt 0 ] ; do
    case "${1:-""}" in
      -h|--help)
        help
        ;;
      -c|--clean)
        arg_clean=1
        ;;
      -d|--debug)
        arg_debug='--debug'
        ;;
      apk)
        shift
        arg_cmd=build_apk
        break
        ;;
      appbundle)
        shift
        arg_cmd=build_appbundle
        break
        ;;
      *)
        die "Invalid command '$1' [use -h/--help for help]"
        ;;
    esac
    shift
  done
  if [ -n "$arg_clean" ]; then
    build_clean
  fi
  if [ -n "$arg_cmd" ]; then
    $arg_cmd "$@"
  fi
}

# Execute main if script is executed directly (not sourced):
# This allows for shunit2 testing (https://github.com/kward/shunit2)
if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
  main "$@"
fi
