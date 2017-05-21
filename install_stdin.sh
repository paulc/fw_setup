#!/bin/ksh

trap _cleanup EXIT

set -A _tmpfiles

_cleanup() {
    rm -f ${_tmpfiles[*]}
}

install_stdin() {
    local _args _tmp
    _args=$(getopt B:bCcDdf:g:m:o:pSs "$@") || exit 1
    _tmp=$(mktemp) || exit 1
    set -A _tmpfiles ${_tmpfiles[*]} $_tmp
    cat >>$_tmp || exit 1
    _args=$(echo $_args | sed -e "s%--%$_tmp%") || exit 1
    install $_args || exit 1
    rm -f $_tmp
}

date | install_stdin -m 444 ./xxx/yyy/zzz || exit 1
