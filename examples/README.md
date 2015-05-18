## A minimal example

To get started with this example, try the following command

````
$ mkdir enabled/ -pv
$ touch enabled/test.txt

# Generate Dockerfile with `bocker.sh`.
$ ../bocker.sh Bockerfile.minimal Dockerfile

# See if there is any difference from author's output.
$ diff output/Dockerfile.minimal Dockerfile

# Build your image
$ docker build -t bocker/test .
````
