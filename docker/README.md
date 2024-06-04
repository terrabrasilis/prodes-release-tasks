# Docker image

Used to create a new image based on the GDAL image with more CLI tools used by the tasks in this repository.

## Build image

To change the image tag version, edit the "build-docker-image.sh" file and change the TAG_VERSION with the version number before creating it.

To build, use the following script.
```sh
./build-docker-image.sh
```