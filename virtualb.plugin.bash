#!/usr/bin/env bash
#
# virtualb.plugin.bash
#
# Copyright (C) 2017 Tom Caruso <carusot42@gmail.com>
# Distributed under terms of the GPLv3 license.
#
#
# virtualb was heavily inspired by virtualz, a virtualenv manager for zsh: https://github.com/aperezdc/virtualz
#

: ${VIRTUALB_HOME:=${HOME}/.virtualenvs}


vb () {
    if [[ $# -eq 0 || $1 = --help || $1 == -h ]] ; then
		vb help
		return
	fi

	local cmd=$1 func="__virtualb_$1"
	shift

    if typeset -f "${func}" > /dev/null ; then
        if [[ $1 == --help ]]; then
            vb help "${cmd}"
        else
            "${func}" "$@"
        fi
    else
        echo "The subcommand ${cmd} is not defined."
    fi

}

__virtualb_help () {
    cat << EOF
vb - virtualb
A wrapper for Python's virtualenv, based off of virtualz & virtualfish.

Usage:

    vb <command> [OPTIONS]

Available commands:

    activate    -  Activate a virtualenv
    deactivate  -  Deactivate the current virtualenv
    ls          -  List all virtualenvs
    new         -  Create a new virtualenv
    rm          -  Remove a virtualenv
    which       -  Show current virtualenv

EOF
}

__virtualb_new () {
    ! type "virtualenv" > /dev/null && __install_deps

    [[ $# -lt 1 ]] && echo "Must specify virtualenv name." 1>&2 && return 1

    local virtualenv_name=$1
    local virtualenv_path=${VIRTUALB_HOME}/${virtualenv_name}
    shift

    virtualenv $@ "${virtualenv_path}"
    local virtualenv_status=$?

    if [[ ${virtualenv_status} -eq 0 && -d ${virtualenv_path} ]]; then
        vb activate ${virtualenv_name}
    else
        echo "Error when creating virtualenv" 1>&2 && return $virtualenv_status
    fi
}

__virtualb_activate () {
    [[ $# -ne 1 ]] && echo "Must specify virtualenv name." 1>&2 && return 1

    local virtualenv_name=$1
    local virtualenv_path=$VIRTUALB_HOME/${virtualenv_name}

    [[ ! -d $virtualenv_path ]] && echo "The virtualenv $virtualenv_name does not exist." 1>&2 && return 1

    [[ -z ${VIRTUAL_ENV+x} ]] || __virtualb_deactivate

    VIRTUAL_ENV_NAME=$virtualenv_name
    VIRTUAL_ENV=$virtualenv_path

    source $virtualenv_path/bin/activate

}

__virtualb_deactivate () {
    [[ -z ${VIRTUAL_ENV+x} ]] && echo "No virtualenv is active." 1>&2 && return 1

    typeset -f "deactivate" > /dev/null && deactivate
    unset VIRTUAL_ENV VIRTUAL_ENV_NAME
}

__virtualb_ls () {
    if [[ -n ${VIRTUALB_HOME+x} ]]; then
        for d in $VIRTUALB_HOME/*; do
            echo $(basename $d)
        done
    fi
}

__virtualb_rm () {
    [[ $# -lt 1 ]] && echo "No virtualenv specified." 1>&2 && return 1
    
    local env_name=$1
    local env_path=${VIRTUALB_HOME}/${env_name}

    [[ ${VIRTUAL_ENV_NAME} == ${env_name} ]] && echo "Cannot remove virtualenv ${env_name} while it is in use." 1>&2 && return 1

    [[ ! -d ${env_path} ]] && echo "The virtualenv ${env_name} does not exist." 1>&2 && return 1

    rm -rf ${env_path}
}


__virtualb_which () {
    [[ -z ${VIRTUAL_ENV+x} ]] && echo "No virtualenv is active." && return 0

    echo $VIRTUAL_ENV_NAME
}


__install_deps () {
    # Lets be helpful and ask to install virtualenv if it's not installed.
    read -p "virtualenv is not installed. Would you like to install it now? [Y/n]" INSTALL

    [[ $INSTALL =~ [Yy] ]] && sudo pip install virtualenv
}
