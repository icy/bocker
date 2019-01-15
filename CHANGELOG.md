## v1.3.2

* Enforce LANG=en_US.UTF-8 (#12, @bmocm)
* Update examples
* Fix problem with `ARG` position (#11, @bmocm)

## v1.3.1

* Fix default `BOCKER_SHELL` (Default to `/usr/bin/env bash`)

## v1.3.0

* Output Dockerfile generally has new internals. That results in
  rebuilding your Docker image.

* Add `ed_label`
* Add new internal `__ed_before_ship`
* New environment `BOCKER_SHELL` allows developer to specify the shell
  to execute result scripts when building images. This is useful for
  `Alpine` users. Default to `bash`.
* New primitive `ed_shell` to modify `BOCKER_SHELL`.

## v1.2.1

* Add `ed_source` (an alias of `source`)

## v1.2.0

* Update documentation (`README.md`);
* Avoid duplicate of `ed_bocker`s when `Bockerfile` is
  included multiple times thanks to `ed_reuse`;
* Add `-t` (`--test`) option to test `Bockerfile` file.

## v1.1.1

* Reduce number of layers by joining VOLUME and EXPOSE statements;
* Add `ed_user` in Preamble. Only `--later` option is supported;
* Add `ed_copy`. Only support `--later` in Preamble. Has `--add` option;
* `ed_env` has new option `--later`;
* Add `ed_reuse` to load and reuse `ed_bocker` from a `Bockerfile`;
* Wrap `base64` output in `RUN` statement;
* Add `ed_group` to group multiple stuff into a group  (Idea from `axit`).

## v1.0.1

* New option `-v` (or `--version`) to print `Bocker` version information

## v1.0.0

* The first public version.
