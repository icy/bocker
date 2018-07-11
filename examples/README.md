## Table of contents

* [A minimal example](#a-minimal-example)
* [A non-minimal example](#a-non-minimal-example)
* [More examples](#more-examples)
  * [Base things](#base-things)
  * [Overloading](#overloading)
  * [Refine the base image](#refine-the-base-image)

## A minimal example

The file `Bockerfile.alpine` is very minimal. It just creates new image
from `alpine:3.8` and set up an environment variable. Let's generate
a `Dockerfile` from it:

```
$ ../bocker.sh Bockerfile.alpine > Dockerfile
```

A sample output is found under `output/Dockerfile.alpine`.

## A non minimal example

To get started with this example, try the following command

````
$ mkdir enabled/ -pv
$ touch enabled/test.txt

# Check if there is any problem
$ ../bocker.sh -t Bockerfile.minimal

# Generate Dockerfile with `bocker.sh`.
$ ../bocker.sh Bockerfile.minimal > Dockerfile

# See if there is any difference from author's output.
$ diff output/Dockerfile.minimal Dockerfile

# Build your image
$ docker build -t bocker/test .
````

## More examples

Some details for https://github.com/icy/docker/tree/master/bocker.

### Base things

There are lot of common definitions that can be used everywhere.
For example, maintainer information, base image, common functions
for install `Debian` packages. This can be done by defining a
`base` Bockerfile, and then `reuse` it later.

For example, a common mistake is to define a global environment
variable `DEBIAN_FRONTEND=noninteractive` in the base image.
But this may lead to confused error message when you enter your
running container and try to install some package.

A safer way is to make that environment variable `local`. And
a better way is to put them in a `bash` function, like this

````
ed_apt_install() {
  apt-get update
  DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends $@
}
````

(See https://github.com/icy/docker/blob/master/bocker/Bockerfile.base#L25.)

Now whenever you want to install a package, try `/bocker.sh ed_apt_install foo`
(from your non-interactive shell), and/or in your other functions.

### Overloading

`Overloading` can be done very simple thanks to `Bash`. To overload
a method in a base image, you only need to reuse or source the base
`Bockefile`, and redefine any function you want.

For example, the main line version of `nginx` differs from the stable
version in the `version` number. With a careful design, the whole
mainline image can be done as below

````
ed_reuse "$(dirname ${BASH_SOURCE[0]:-.})/Bockerfile.nginx"

ed_nginx_env() {
  export NGINX_VERSION=1.9.1
  export NGINX_CHECKSUM=b021d26bcefd41c8b9f9f35f263edf005e0f41dd

  export NGINX_VERSION=1.9.2
  export NGINX_CHECKSUM=814855ab98d6b0900207a6e5307252b130af61a2
}
````

This is actually done at
  https://github.com/icy/docker/blob/master/bocker/Bockerfile.nginx_mainline.

### Refine the base image

Most of my images are based on `debian:wheezy`.
But `phantomjs` requires a newer version of `Debian`, otherwise
you end up in some fonts rendering issue. We can do that simply

````
ed_from  "debian:jessie"
ed_reuse "$(dirname ${BASH_SOURCE[0]:-.})"/Bockerfile.supervisor
````

This idea is impossible in the traditional `Dockerfile` because
the (very) base image is fixed. You can only use it, or not;
you can't refine them.

See https://github.com/icy/docker/blob/master/bocker/Bockerfile.phantomjs.
