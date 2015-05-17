## Description

`Bocker` makes your `Dockerfile` resuable.
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
* No way to include some useful parts from other `Dockerfile`.

This project is to solve these problems. It will read some `Bash`
source files, and write new `Dockerfile` to `STDOUT`. The output
is cacheable, and can be executed by `docker build` command.

## Getting started

Take a look at a quite minimal example in `examples/Bockerfile.minimal`.
To use this file, type the following commands

````
$ cd examples/
$ ../bocker.sh Bockerfile.minimal
````

You will get an error. No worry, you just need to create a directory
to continue

````
$ mkdir enabled/
$ touch enabled/test.txt
$ ../bocker.sh Bockerfile.minimal
````

New contents are exactly a `Dockerfile` for your build.
FYI, that will create an image with some basic packages installed
(`cron`, `exim`, `curl`, ...)

The sample `Dockerfile` output is found under
  `examples/output/Dockerfile.minimal`.

## Requirements

`Bocker` requires `Bash` on your local machine,
and that the base image has `Bash` for `/bin/sh`.

On `Debian`-based system, `/bin/sh` is often `/bin/dash`,
but `Bocker` will fix that automatically for you.

For other distributions that doesn't have `Bash` feature for `/bin/sh`,
please report the problem and it would be solved in the next `Bocker` release.

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
````

Think of `FROM`, `MAINTAINER`, `EXPOSE`. They are:

* `ed_from`: Define your `FROM` information;
* `ed_maintainer`: Define your `MAINTAINER` information;
* `ed_env`: Define new `ENV` instruction;
* `ed_expose`: Specify a list of exposed ports;
* `ed_volume`: Specify a list of volumes;
* `ed_cmd`: Define your `CMD` statement;
* `ed_ship`: Define a list of methods to be shipped to the image;
  That means, you can define a function `ed_foobar`, and call `ed_ship foobar`
  to make this function available to `Docker` at build time and run time.
  Actually, functions' definitions are written to the file `/bocker.sh`
  in the result image, and that will be included at every `RUN`.

All these commands can be used multiple times, and/or be put in
your base libraries. (See `examples/lib/core.sh`.)

The last statement of `ed_from` (`ed_maintainer`, `ed_cmd`) will win;
other functions have additive effect.

### Main matter

You can define your set of methods as `Bash` functions, each of them
has a name started by `ed_`. For example, in `examples/lib/debian.sh`,
you will see `ed_apt_clean` that removes unused `apt-get` variable data
to minimize the size of your result image.

### ed_bocker

This is a must-have function. `Bocker` will raise error if you
don't define it.

This function should not contain any function from `PREAMBLE` section.

It can have two special functions

* `ed_copy`: Define your `COPY` statement
* `ed_add`: Define your `ADD` statement

`Bocker` will read the contents of this `ed_bocker` function,
replace every appearance of `ed_*` by `__ed_ship_method ed_*`.
That means, if you type `ed_apt_clean`, `Bocker` will invoke
`__ed_ship_method ed_apt_clean` for you.

Because this is actually a replace-execute trick,
it's your duty to make your definition of `ed_bocker` as simple
as possible. Don't use complex stuff like expansion and (`WHO KNOWS`?)
If you have to do that, put your stuff under some functions,
ship them to the image with `ed_ship`, and that's just enough.

## WTF. No `ENTRY_POINT` support!

No, at the moment. But you will see it very soon.

## History

When the project is started, its name is `EDocker`, that's why you see
`ed_` prefixes. `EDocker` isn't a good name, hence you see `Bocker` now.

## License. Author

This work is released the terms of `MIT` license.
The author is Anh K. Huynh.
