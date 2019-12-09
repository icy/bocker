*WARNING*: I haven't had time to maintain this project. Use them at your own risk. Thank you for your understanding.

## Table of contents

* [Description](#description)
* [Getting started](#getting-started)
  * [A minimal example](#a-minimal-example)
  * [More examples](#more-examples)
* [Install and Usage](#install-and-usage)
* [Syntax of Bockerfile](#syntax-of-bockerfile)
  * [Front matter](#front-matter)
  * [Main matter](#main-matter)
  * [Main function ed_bocker](#main-function-ed_bocker)
* [Dockerfile vs. Bockerfile](#dockerfile-vs-bockerfile)
* [Bocker.sh script](#bockersh-script)
* [Important notes](#important-notes)
* [History](#history)
* [License. Author](#license-author)

## Description

`Bocker` makes your `Dockerfile` reusable.
The name is combined from `B(ash)` and `(D)ocker`.

`Dockerfile` is a mix of shell commands, run-time settings and stuff.
It looks simple at first, but in a long run, you'll have some problems:

* Have to `copy` and `paste` common codes between `Dockerfile`s;
  (Examples: `FROM`, `MAINTAINER`, `ENV`,...);
* No way to do some basic checks. For example, the `COPY /foo /bar`
  will raise an error if `/foo` doesn't exist; if that's the case,
  you have no way to tell `COPY` to continue;
* It's hard to define and call a `sub-routine` in `RUN` statement,
  because `RUN` is one-line statement. Yes, you can try to do that
  with a mess of unreadable and un-maintainable codes;
* No way to include some useful parts from other `Dockerfile`;
* No way to create the full `Dockerfile` of an image and its ancestors.

This project is to solve these problems. It will read some `Bash`
source files, and write new `Dockerfile` to `STDOUT`. The output
is cacheable, and can be executed by `docker build` command.

## Getting started

### A minimal example

Take a look at a quite minimal example in `examples/Bockerfile.alpine`.

```
#!/usr/bin/env bash

# The default Alpine shell /bin/sh

ed_shell  /bin/sh
ed_from   alpine:3.8
ed_env    --later Hello World

ed_bocker() {
  :
}
```

To use this file, type the following commands

````
$ cd examples/
$ ../bocker.sh Bockerfile.alpine > Dockerfile.alpine
````

New contents are exactly a `Dockerfile` for your build.

### More examples

Overloading? Improve caching with `--later`?
Use `ship` instead of `ADD / COPY` commands?

See more from `examples/README.md` at
  https://github.com/icy/bocker/blob/master/examples/README.md
or a collection of `Bockerfile` at
  https://github.com/icy/docker/tree/master/bocker.

## Install and Usage

### Requirements

`Bocker` requires the popular tools:

* On local machine where you run `bocker` script:
    `Bash`, `base64`, `grep`, `sed`, `gawk`;
* On base image:
    `bash` or `sh`, `base64`.

`base64` is a basic tool from `coreutils` package.

### Installation

There is only one `Bash` script `bocker.sh`. Put this script in
one of your binary directories, and start it with `Bockerfile`

````
$ bocker.sh MyBockerfile >/dev/null # to see if there is any error
$ bocker.sh MyBockerfile            # to see Dockerfile output
````

The output is written to `STDOUT`. You should check if there is anything
wrong from `STDERR`, because `Bocker` is unable to check if your source
file has problem.

### Command line options

* `-v` (`--version`): Print the script version;
* `-t` (`--test`): Check if there is any problem with input.

## Syntax of `Bockerfile`

All `Bockerfile`s are `Bash` source files. That means you can write
your source in some small files, and include them in other files.

The first rule is that every method is started with `ed_`.

### Front matter

There are some basic methods to define your meta information.
For your overview, let's see:

````
ed_from        YOUR_BASE_IMAGE
ed_maintainer  "YOUR INFORMATION"

ed_env         FOO /bar/
ed_expose      80
ed_volume      /example.net/
ed_cmd         '["/supervisor.sh", "foo", "bar"]'
ed_ship        foobar
....
````

Think of `FROM`, `MAINTAINER`, `EXPOSE`. They are:

* `ed_from`: Define your `FROM` information;
* `ed_maintainer`: Define your `MAINTAINER` information;
* `ed_env`: Define new `ENV` instruction; Use `--later` option if
   your environment is only needed at the run-time;
* `ed_expose`: Specify a list of exposed ports;
* `ed_volume`: Specify a list of volumes;
* `ed_onbuild`: Specify trigger on the descendant image build;
* `ed_cmd`: Define your `CMD` statement;
* `ed_user`: Define your `USER` statement; Must use with `--later` option;
* `ed_copy`: Define your `COPY` statement; If you want to have `ADD`,
    use `--add` option. Must use with the option `--later`;
* `ed_entrypoint`: Define your `ENTRYPOINT` statement;
* `ed_ship`: Define a list of methods to be shipped to the image;
  That means, you can define a function `ed_foobar`, and call `ed_ship ed_foobar`
  to make this function available to `Docker` at build time and run time.
  Actually, functions' definitions are written to the file `/bocker.sh`
  in the result image, and that will be included at every `RUN`;
* `ed_ship --later`: Like `ed_ship`, but the contents are shipped at
  the very end of `Dockerfile`. This is very useful when the functions
  are only needed at the run-time, because that really speeds up
  your build process. See example in `examples/lib/debian.sh`.)
* `ed_reuse`: Load the `Bockerfile`(s) specified in argument,
  and re-use `ed_docker` from that source if any.
  All `ed_docker` definitions are additive in order provided.

All these commands can be used multiple times, and/or be put in
your base libraries. (See `examples/lib/core.sh`.)

The last statement of `ed_from` (`ed_maintainer`, `ed_cmd`, `ed_entrypoint`)
will win; other functions have additive effect.

### Main matter

You can define your set of methods as `Bash` functions, each of them
has a name started by `ed_`. For example, in `examples/lib/debian.sh`,
you will see `ed_apt_clean` that removes unused `apt-get` variable data
to minimize the size of your result image.

### Main function: `ed_bocker`

This is a must-have function. `Bocker` will raise error if you
don't define it.

This function should not contain any function from `PREAMBLE` section.

It can have some special functions

* `ed_copy`: Define your `COPY` statement;
* `ed_add`: Define your `ADD` statement;
* `ed_user`: Define your `USER` statement;
* `ed_workdir`: Define your `WORKDIR` statement;
* `ed_run`: Define your `RUN` statement;
* `ed_group`: Group multiple methods into a single `RUN` statement.

`Bocker` will read the contents of this `ed_bocker` function,
replace every appearance of `ed_*` by `__ed_ship_method ed_*`.
That means, if you type `ed_apt_clean`, `Bocker` will invoke
`__ed_ship_method ed_apt_clean` for you.

Because this is actually a replace-execute trick,
it's your duty to make your definition of `ed_bocker` as simple
as possible. Don't use complex stuff like expansion and (`WHO KNOWS`?)
If you have to do that, put your stuff under some functions,
ship them to the image with `ed_ship`, and that's just enough.

## Dockerfile vs. Bockerfile

Facts

* `Dockerfile` statements are ordered. First declared first run.
  In `Bockerfile`, most stuff in `PREAMBLE` are un-ordered;
* `Dockerfile` supports array form of `ENV`, `EXPOSE`, `VOLUME`;
  but `Bockerfile` doesn't. This way helps `Bockerfile` to glue
  declarations from multiple library files into a single statement;
* To group `RUN` commands in `Dockerfile`, you have to use `&&` and
  remove `RUN` from the later statements. In `Bockerfile`, you simply
  use `ed_group`. See [this example][Bockerfile.nginx];
* To declare a `Bash` function and use them in every `RUN` statement,
  you may put that definition in a file, use `COPY` to transfer the file
  to the container and load it, e.g, `RUN source /mylib.sh; ...`;
  You can love this way or not. In `Bockerfile`, you simply use `ed_ship`
  for build-time methods, and `ed_ship --later` for run-time methods
  with a minimum number of layers.

Here is a table for quick reference.

Purpose       | Dockerfile | Bockerfile (Preamble) | `ed_bocker`
:--           | :--        | :--                   | :--
Base image    | FROM       | ed_from               |
Base script   |            | ed_reuse              |
Base script   |            | ed_source, source     |
Maintainer    | MAINTAINER | ed_maintainer         |
Volume expose | VOLUME     | ed_volume             |
Port expose   | EXPOSE     | ed_expose             |
Init script   | ENTRYPOINT | ed_entrypoint         |
Init command  | CMD        | ed_cmd                |
Int command   | ONBUILD    | ed_onbuild            |
Variable      | ENV        | ed_env [--later]      |
Build command | RUN        | `ed_bocker`           | `ed_foo`, ed_run
Build command | ADD        | ed_copy --add --later | ed_add
Build command | COPY       | ed_copy --later       | ed_copy
Build command | USER       | ed_user --later       | ed_user
Build command | WORKDIR    | TODO                  | ed_workdir
Declare method| N/A        | ed_ship [--later]     |
Grouping      | &&         |                       | ed_group
Label         | LABEL      | ed_label              | echo "LABEL foo=bar"
Raw statement |            |                       | echo "# Something"

## `/bocker.sh` script

The result image has `/bocker.sh` script that contains (almost) all
your functions.

When you use `ed_ship` or invoke some command inside your `ed_bocker`,
your function definitions are saved originally _(except the comments,
of course)_ to the `/bocker.sh` script in the result image.

This script only contains functions, and if you provide any arguments
to it, they are considered as command in the environment where your
functions are defined. For example

    # ed_ship --later my_method
    /bocker.sh ed_my_method
    # /bocker.sh find

will invoke `ed_my_method` (or `find` command) that you have shipped.

Because of this, you can simply define a `start-up` function, and
use `/bocker.sh` to call them. That exactly means, `bocker.sh` can
be used as your `ENTRYPOINT`.

## Important notes

* `ed_bocker` is executed locally at run time, on your local machine.
  This is dangerous. Please don't add too much codes inside `ed_bocker`.
  That function should only contain `ed_*` methods.
* Any `RUN` generated by `Bocker` has option `-xeu` set by default;
  That means any error will stop. If you want to have something else,
  you can always do that in you `ed_*` definition.

## History

When the project is started, its name is `EDocker`, that's why you see
`ed_` prefixes. `EDocker` isn't a good name, hence you see `Bocker` now.

## License. Author

This work is released the terms of `MIT` license.
The author is Anh K. Huynh.

[Bockerfile.nginx]: https://github.com/icy/docker/blob/master/bocker/Bockerfile.nginx
