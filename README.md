# Rfam website

Get a local installation of Rfam website using [Docker](https://www.docker.com/).

* data is loaded from the public Rfam MySQL database
* code is installed from the public Rfam SVN repository

## Building Docker container

```
docker build -t rfamweb .
```

This might take a while when executed for the first time.

## Development

```
docker run --name=rfamweb --rm -it -p 3000:3000 -v /local/path/to/config:/src/RfamWeb/config rfamweb
```

The config files from the host will be accessible in the container and can be edited from the host. The Rfam site should be available at *http://your_container_ip:3000*.

## Docker cheat sheet

```
# create default virtualbox
docker-machine create --driver virtualbox default

# connect terminal to the docker machine
eval "$(docker-machine env default)"

# get container IP address
docker-machine ls

# list running docker containers
docker ps

# stop running docker container
docker stop rfamweb

# login to running container from another terminal
docker exec -it rfamweb bash
```

## To do

* get Rfam code from GitHub instead of SVN
* better handling of configs
