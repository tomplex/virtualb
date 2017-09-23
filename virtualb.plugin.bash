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

__virtualb_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


vb () {
    if [[ $# -eq 0 || $1 = --help || $1 == -h || $1 == "-?" ]] ; then
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
    if [[ $# -eq 0 ]]; then
        cat << EOF
Virtualb: A bash-based wrapper for Python's virtualenv.

Usage:

    vb <command> [OPTIONS]

Available commands:

EOF

        for file in ${__virtualb_dir}/docs/cmd_*; do
            local cmd="${file#*/cmd_}"
            printf "    %-14s - %s \n" "${cmd}" "$(head -n 1 $file)"
        done
        printf "\n"
    elif [[ $# -eq 1 ]]; then
        if [[ -r ${__virtualb_dir}/docs/cmd_$1 ]]; then
            cat ${__virtualb_dir}/docs/cmd_$1
        else
            echo "No such command: $1" 1>&2
            echo "use vb help for a list of commands." 1>&2
            return 1
        fi
    fi
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

    __confirm_remove $env_name && rm -rf ${env_path}
}

__virtualb_which () {
    [[ -z ${VIRTUAL_ENV+x} ]] && echo "No virtualenv is active." && return 0

    echo $VIRTUAL_ENV_NAME
}

__virtualb_freeze () {
    [[ -z ${VIRTUAL_ENV+x} && $# -lt 1 ]] && echo "No virtualenv specified or active." 1>&2 && return 1
    
    local env=${1:-${VIRTUAL_ENV_NAME}}
    
	$VIRTUALB_HOME/${env}/bin/pip freeze

}

#__virtualb_test () {
#    for f in $__virtualb_dir/docs/cmd_*; do
#        local cmd="${f#*/cmd_}"
#        echo $cmd
#    done
#    echo $__virtualb_dir
#}

__install_deps () {
    local install
    # Lets be helpful and ask to install virtualenv if it's not installed.
    read -p "virtualb requires virtualenv, and it is not installed. Would you like to install it now? [Y/n]" install

    [[ $install =~ [Yy] ]] && sudo pip install virtualenv
}

__confirm_remove () {
    local remove
    read -p "Are you sure you want to remove the virtualenv $1? " remove

    [[ $remove =~ [Yy] ]] && return 0 || return 1

}

__vb_completions() {
    [[ $1 == "activate" || $1 == "rm" || $1 == "freeze" ]] && __virtualb_ls
    [[ $1 == "help" ]] && __vb_all_cmds
}

__vb_all_cmds() {
    for f in $__virtualb_dir/docs/cmd_*; do
        local cmd="${f#*/cmd_}"
        echo $cmd
    done
}

_vb () {

    COMPREPLY=()

    local word="${COMP_WORDS[COMP_CWORD]}"

    if [[ "${COMP_CWORD}" -eq 1 ]]; then
        local cmds=$(__vb_all_cmds)
        COMPREPLY=( $(compgen -W "$cmds" -- "$word") )

    else
        local words=("${COMP_WORDS[@]}")
        unset words[0]
        unset words[$COMP_CWORD]
        local completions=$(__vb_completions "${words[@]}")
        COMPREPLY=( $(compgen -W "$completions" -- "$word") )
    fi
}


complete -F _vb vb
