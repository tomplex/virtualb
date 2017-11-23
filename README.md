## virtualb

A bash wrapper around Python's `virtualenv` tool. Inspired by [virtualz](https://github.com/aperezdc/virtualz), it aims to pull all virtualenv management into one command, with explicit and easy to remember subcommands.

### Quick install

```bash
git clone https://github.com/tomplex/virtualb.git ~/.bash_plugins/virtualb
echo "source $HOME/.bash_plugins/virtualb/virtualb.plugin.bash" >> ~/.bashrc
```

### Usage

`virtualb` provides the `vb` command, which groups together some useful virtualenv management tasks:

```bash
vb new some_virtualenv          # defaults to system python
which python
vb which                        # show virtualenv name
 
vb new some_other_virtualenv -p python3.6  # can specify python to use
which python
vb which
 
echo ${VIRTUAL_ENV}             # path to virtualenv
echo ${VIRTUAL_ENV_NAME}        # name of virtualenv
 
vb deactivate                   # deactivates current virtualenv
which python
 
vb ls                           # lists all virtualenvs
 
vb rm some_virtualenv           # removes virtualenv
vb rm some_other_virtualenv
```

All virtualenvs are created in the location specified environment variable `VIRTUALB_HOME`. It defaults to `~/.virtualenvs`, but you can set this to whatever in your `.bashrc` file (no need to export).

Subcommands will autocomplete in the prompt, as will subcommands referencing virtualenvs, like `activate`, `freeze` and `rm`.

Currently, `virtualb` provides these commands:

|command|description|usage|
|---|---|---|
| `activate` | activate the specified virtualenv | `vb activate <virtualenv>` |
|`deactivate`| deactivate the currently activated virtualenv.|`vb deactivate`|
|`exec`|execute a command in the specified virtualenv|`vb exec [-e env] <command>`|
|`freeze`|list installed packages in currently activated or specified virtualenv| `vb freeze` or `vb freeze <virtualenv>`|
|`help`|provide help for the given command|`vb help <command>`|
|`ls`|list all virtualenvs by name|`vb ls`|
|`mv` / `rename`|rename virtualenv |`vb mv <some virtualenv> <a new name>`|
|`new`|create a new virtualenv with the specified name|`vb new <virtualenv> [options]`|
|`pwd`|show directory of active virtualenv|`vb pwd`|
|`rm` | deletes the specified virtualenv| `vb rm <virtualenv>`|
|`which`|shows the currently activated virtualenv|`vb which`|

Additionally, all arguments to the `vb new` subcommand will be passed along to the `virtualenv` command, but they must come *after* the name of the virtualenv.

### Installation

Manual installation is straightforward; just clone the repo wherever you want and source the `virtualb.plugin.bash` file in your `.bashrc`:

```bash
git clone https://github.com/tomplex/virtualb.git ~/.bash_plugins/virtualb
echo "source $HOME/.bash_plugins/virtualb/virtualb.plugin.bash" >> ~/.bashrc
```

I haven't yet figured out how integrate with a plugin manager like [bash-it](https://github.com/Bash-it/bash-it). Will update once I get that set up.

