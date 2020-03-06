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

VIRTUALB_HOME=${VIRTUALB_HOME:-$HOME/.virtualenvs}
VIRTUALB_DEFAULT_PYTHON=${VIRTUALB_DEFAULT_PYTHON:-$(which python3)}

__virtualb_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


vb () {
    # Entrypoint
    if [[ $# -eq 0 || $1 = --help || $1 == -h || $1 == "-?" ]] ; then
		vb help
		return
	fi

	local cmd=$1 func="__virtualb_$1"
	shift

    if typeset -f "${func}" > /dev/null ; then
        if [[ $1 == --help || $1 == -h || $1 == "-?" ]]; then
            vb help "${cmd}"
        else
            "${func}" "$@"
        fi
    else
        echo "The command ${cmd} is not defined."
    fi
}


__virtualb_help () {
    # Print help info to stdout.
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
    # Create a new virtualenv.

    [[ $# -lt 1 ]] && echo "Must specify virtualenv name." 1>&2 && return 1

    local virtualenv_name=$1
    local virtualenv_path=${VIRTUALB_HOME}/${virtualenv_name}
    shift

    # Thanks to https://unix.stackexchange.com/a/258514/214736
    for arg do
      echo $arg
        shift
        if [[ "$arg" == "-r" ]]; then
            requirements_file=$1
            shift
        elif [[ "$arg" == "-p" ]]; then
            python_executable=$1
            shift
        fi
    done

    if [[ -z "${python_executable}" ]]; then
      # If the user didn't specify a python version to use, use the default.
      python_executable=$VIRTUALB_DEFAULT_PYTHON
    fi

    $python_executable -m venv "${virtualenv_path}"

    local virtualenv_status=$?

    if [[ ${virtualenv_status} -eq 0 && -d ${virtualenv_path} ]]; then
        vb activate ${virtualenv_name}
    else
        echo "Error when creating virtualenv" 1>&2 && return $virtualenv_status
    fi

    if [[ -n "${requirements_file}" ]]; then
      pip install -r $requirements_file
    fi

    return $?
}


__virtualb_activate () {
    # Activate the specified virtualenv.
    local virtualenv_name

    if [[ $# -ne 1 ]]; then
          virtualenv_name=$(basename "$PWD")
    else
          virtualenv_name=$1
    fi

    local virtualenv_path=$VIRTUALB_HOME/${virtualenv_name}

    ! __virtualenv_exists $virtualenv_name && echo "The virtualenv $virtualenv_name does not exist." 1>&2 && return 1

    __virtualenv_currently_active && __virtualb_deactivate

    VIRTUAL_ENV_NAME=$virtualenv_name
    VIRTUAL_ENV=$virtualenv_path

    source $virtualenv_path/bin/activate
}


__virtualb_deactivate () {
    # Deactivate the currently active virtualenv.
    ! __virtualenv_currently_active && echo "No virtualenv is active." 1>&2 && return 1

    typeset -f "deactivate" > /dev/null && deactivate
    unset VIRTUAL_ENV VIRTUAL_ENV_NAME
}


__virtualb_ls () {
    # Print the names of all virtualenvs to stdout.
    if [[ -n ${VIRTUALB_HOME+x} ]]; then
        for directory in $VIRTUALB_HOME/*; do
            echo $(basename $directory)
        done
    fi
}


__virtualb_rm () {
    # Delete a virtualenv.
    [[ $# -lt 1 ]] && echo "No virtualenv specified." 1>&2 && return 1
    local override
    # Check for the -y flag
    [[ "$1" = "-y" ]] && override=true && shift

    local env_name=$1
    local env_path=${VIRTUALB_HOME}/${env_name}

    # Don't remove the virtualenv if it's the one currently in use.
    [[ ${VIRTUAL_ENV_NAME} == ${env_name} ]] && echo "Cannot remove virtualenv ${env_name} while it is in use." 1>&2 && return 1

    # We can't remove a virtualenv that doesn't exist.
    ! __virtualenv_exists ${VIRTUAL_ENV_NAME} && echo "The virtualenv ${env_name} does not exist." 1>&2 && return 1

    [[ -n ${override+x} ]] || __confirm_remove $env_name && rm -rf ${env_path}
}


__virtualb_which () {
    # Print the name of the currently active virtualenv to atdout.
    ! __virtualenv_currently_active && echo "No virtualenv is active." && return 0

    echo $VIRTUAL_ENV_NAME
}


__virtualb_freeze () {
    # Print the installed packages + versions of the specified or active virtualenv to stdout.
    ! __virtualenv_currently_active && [[ $# -lt 1 ]] && echo "No virtualenv specified or active." 1>&2 && return 1

    # Check if $1 is set; if not then use the active virtualenv.
    local env=${1:-${VIRTUAL_ENV_NAME}}
    
	$VIRTUALB_HOME/${env}/bin/pip freeze
}


__virtualb_pwd () {
    # Print the source directory for the specified or currently active virtualenv.
    ! __virtualenv_currently_active && [[ $# -eq 0 ]] && echo "No virtualenv specified or active." && return 0

    [[ $# -eq 1 ]] && echo $VIRTUALB_HOME/$1 || echo $VIRTUAL_ENV
}


__virtualb_mv () {
    # Rename a virtualenv.
    local current_name=$1
    local new_name=$2
    # This one is pretty straightforward, because we always want two parameters: the current name and new name.
    [[ -z "$current_name" || -z "$new_name" ]] && echo "Must specify virtualenv to rename and the new name." 1>&2 && return 1

    # We could probably let the user rename a virtualenv while it's in use if we deactivate, rename, and then reactivate
    # with the new name. But for now, we'll just make them deactivate manually, first.
    [[ ${VIRTUAL_ENV_NAME} == ${current_name} ]] && echo "Cannot rename virtualenv ${current_name} while it is in use." 1>&2 && return 1

    # make sure the virtualenv we're trying to rename exists, first.
    ! __virtualenv_exists ${current_name} && echo "The virtualenv ${current_name} does not exist." 1>&2 && return 1

    # Assuming we're all good, we need to first change the activate script to remove all references of the old name,
    # and make them the new name.
    sed -i "s/$current_name/$new_name/g" ${VIRTUALB_HOME}/$current_name/bin/activate
    # Then we just change the directory name, and we're all set.
    mv $VIRTUALB_HOME/$current_name $VIRTUALB_HOME/$new_name
}


__virtualb_rename () {
    # Rename a virtualenv. Aliased with mv.
    __virtualb_mv "$@"
}


__virtualb_exec () {
    # Execute a command against the specified Python virtualenv.
    # I kind of hate the implementation here. I'm debating nixing it and trying again later.
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


__virtualb_requires () {
    # Create a requirements file for the active or specified virtualenv.

    local target requirements_file
    if [[ $# -eq 2 ]]; then
        target=$1 requirements_file=$2
    elif [[ $# -eq 1 ]]; then
        # Check if the single argument is a valid virtualenv.
        # if it is, then it's the one we want to target, and we want the default value for requirements file.
        if __virtualenv_exists $1; then
            target=$1
            requirements_file="$(pwd)/requirements.txt"
        # Otherwise, the single argument is the requirements file, and we want to use the current virtualenv.
        else
            # But of course, we need to make sure one is active first. If one isn't, exit.
            ! __virtualenv_currently_active && echo "No virtualenv specified or active." 1>&2 && return 1
            target=$VIRTUAL_ENV_NAME requirements_file=$1
        fi
    else
        # Otherwise, we want to use all defaults: the current virtualenv and $PWD/requirements.txt.
        ! __virtualenv_currently_active && echo "No virtualenv specified or active." 1>&2 && return 1
        target=$VIRTUAL_ENV_NAME requirements_file="$(pwd)/requirements.txt"
    fi

    $VIRTUALB_HOME/$target/bin/pip freeze > $requirements_file

}


__virtualb_install () {
    # Install a package to any number of virtualenvs.

    target="${@: -1}"
    local install_cmd

    [[ -f $target ]] && install_cmd="install -r $target" || install_cmd="install $target"

    if [[ $# -eq 1 ]]; then
        # If there's only one argument, then there are two possibilities:
        # 1. The user passed only a package name;
        # 2. The user passed only an environment name.
        # All we can really do is check to see if there's a virtualenv active; if there is we'll take the single
        # argument and try to install it with pip. If there's no virtualenv active, then we need to exit,
        # because we don't have enough information to proceed.
        ! __virtualenv_currently_active && echo "No virtualenv specified or active." 1>&2 && return 1
        $VIRTUAL_ENV/bin/pip $install_cmd && return 0

    fi
    # Otherwise, we'll assume that they used the command correctly and simply iterate through the virtualenvs,
    # installing the package or requirements file.
    for env in ${@/$target}; do
        $VIRTUALB_HOME/$env/bin/pip $install_cmd
    done

}

__virtualb_update () {
    # Update virtualb.
    pushd $__virtualb_dir > /dev/null && git pull && popd > /dev/null

}


__virtualenv_exists () {
    # Helper function to see if a virtualenv exists.
    [[ -d "$VIRTUALB_HOME/$1" ]]
}


__virtualenv_currently_active() {
    # Helper function to see if any virtualenv is currently active.
    [[ -n ${VIRTUAL_ENV+x} ]]
}


__confirm_remove () {
    local remove
    read -p "Are you sure you want to remove the virtualenv $1? (y/n) " -n 1 remove

    [[ $remove =~ [Yy] ]] || return 1
}


__vb_completions() {
    local complete_virtualenv=( "activate" "rm" "pwd" "freeze" "mv" "rename" "requires" "install" "-e" "--env" "-y" )
    # To stop completions from continuing after the correct number of arguments have been reached,
    # we'll have to keep track of commands and how many args they need.
    local no_complete_after_4=( "activate" "freeze" "mv" "rename" "requires" "pwd" )
    local no_complete_after_5=( "rm" )

    # Yeah, there's definitely a more elegant way to do this, but...
    [[ " ${no_complete_after_4[@]} " =~ " $2 " && $# -eq 4 ]] && return
    [[ " ${no_complete_after_5[@]} " =~ " $2 " && $# -eq 5 ]] && return

    [[ "$2" == "help" ]] && __vb_all_cmds && return

    # let's be helpful and tab-complete the only argument that vb asks for
    [[ "$2" == "exec" && "${@}" = "${@/--env}" ]] && echo "--env" && return

    # Otherwise, we probably just want to autocomplete the name of a virtualenv.
    [[ " ${complete_virtualenv[@]} " =~ " $2 " ]] && __virtualb_ls
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
#        local words=("${COMP_WORDS[@]:$(($COMP_CWORD - 1))}")
        local words=("${COMP_WORDS[@]}")
        local completions=$(__vb_completions "${words[@]}")
        COMPREPLY=( $(compgen -W "$completions" -- "$word") )
    fi
}


complete -F _vb vb
