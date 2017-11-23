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
        echo "The command ${cmd} is not defined."
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

    __virtualenv_currently_active && __virtualb_deactivate

    VIRTUAL_ENV_NAME=$virtualenv_name
    VIRTUAL_ENV=$virtualenv_path

    source $virtualenv_path/bin/activate
}


__virtualb_deactivate () {
    ! __virtualenv_currently_active && echo "No virtualenv is active." 1>&2 && return 1

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

    if ! __virtualenv_exists ${VIRTUAL_ENV_NAME}; then
        echo "The virtualenv ${env_name} does not exist." 1>&2
        return 1
    fi

    __confirm_remove $env_name && rm -rf ${env_path}
}


__virtualb_which () {
    ! __virtualenv_currently_active && echo "No virtualenv is active." && return 0

    echo $VIRTUAL_ENV_NAME
}


__virtualb_freeze () {
    ! __virtualenv_currently_active && [[ $# -lt 1 ]] && echo "No virtualenv specified or active." 1>&2 && return 1
    
    local env=${1:-${VIRTUAL_ENV_NAME}}
    
	$VIRTUALB_HOME/${env}/bin/pip freeze
}


__virtualb_pwd () {
    ! __virtualenv_currently_active && echo "No virtualenv is active." && return 0

    echo $VIRTUAL_ENV
}


__virtualb_mv () {
    local current_name=$1
    local new_name=$2

    [[ -z "$current_name" || -z "$new_name" ]] && echo "Must specify virtualenv to rename and the new name." 1>&2 && return 1

    [[ ${VIRTUAL_ENV_NAME} == ${current_name} ]] && echo "Cannot rename virtualenv ${current_name} while it is in use." 1>&2 && return 1

    if ! __virtualenv_exists ${current_name}; then
        echo "The virtualenv ${current_name} does not exist." 1>&2
        return 1
    fi

    sed -i "s/$current_name/$new_name/g" ${VIRTUALB_HOME}/$current_name/bin/activate
    mv $VIRTUALB_HOME/$current_name $VIRTUALB_HOME/$new_name
}


__virtualb_rename () {
    __virtualb_mv "$@"
}


__virtualb_exec () {
    local exec_cmd exec_env env_python
    # vb exec [-e env] command
    if [[ $1 == "-e" || $1 == "--env" ]]; then
        shift
        exec_env=$1
        shift

    elif ! __virtualenv_currently_active; then
        echo "No virtualenv specified or active" 1>&2
        return 1

    else
        exec_env=$VIRTUAL_ENV_NAME
    fi

    ! __virtualenv_exists $exec_env && echo "virtualenv $exec_env does not exist." 1>&2 && return 1

    exec_cmd=''
    for i in "$@"; do
        i=`printf "%s" "$i" | sed "s/'/'\"'\"'/g"`
        exec_cmd="$exec_cmd '$i'"
    done

    eval "$VIRTUALB_HOME/$exec_env/bin/python" ${exec_cmd}

}

__virtualenv_exists () {
    [[ -d "$VIRTUALB_HOME/$1" ]]
}

__virtualenv_currently_active() {
    [[ -n ${VIRTUAL_ENV+x} ]]
}

__install_deps () {
    local install
    # Lets be helpful and ask to install virtualenv if it's not installed.
    read -p "virtualb requires virtualenv, and it is not installed. Would you like to install it now? [Y/n]" install

    [[ $install =~ [Yy] ]] && sudo pip install virtualenv
}


__confirm_remove () {
    local remove
    read -p "Are you sure you want to remove the virtualenv $1? " remove

    [[ $remove =~ [Yy] ]] || return 1
}


__vb_completions() {
    local complete_virtualenv=( "activate" "rm" "freeze" "mv" "rename" "-e" "--env" )
    # check if our command is one of the above; thanks to https://stackoverflow.com/a/15394738
    [[ " ${complete_virtualenv[@]} " =~ " $1 " ]] && __virtualb_ls

    [[ $1 == "help" ]] && __vb_all_cmds

    # let's be helpful and tab-complete the only argument that vb asks for
    [[ $1 == "exec" ]] && echo "--env"
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
        # progressively shift the array to the left, removing all entered words except the most recent
        local words=("${COMP_WORDS[@]:$(($COMP_CWORD - 1))}")
        local completions=$(__vb_completions "${words[@]}")
        COMPREPLY=( $(compgen -W "$completions" -- "$word") )
    fi
}


complete -F _vb vb
