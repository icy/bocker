## A minimal example

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

See also https://github.com/icy/docker/tree/master/bocker.
