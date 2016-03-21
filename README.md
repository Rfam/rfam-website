# Rfam website

Get a local installation of Rfam website using [Docker](https://www.docker.com/).

* data is loaded from the public Rfam MySQL database
* code is installed from the public Rfam SVN repository

## Development

```
# checkout source code
svn checkout https://xfamsvn.ebi.ac.uk/svn/code/trunk/RfamWeb
svn checkout https://xfamsvn.ebi.ac.uk/svn/code/trunk/PfamBase
svn checkout https://xfamsvn.ebi.ac.uk/svn/code/trunk/PfamLib
svn checkout https://xfamsvn.ebi.ac.uk/svn/code/trunk/PfamSchemata
svn checkout https://xfamsvn.ebi.ac.uk/svn/code/trunk/PfamScripts
svn checkout https://xfamsvn.ebi.ac.uk/svn/code/trunk/Rfam

# specify source code location
export $RFAM_CODE=/path/to/source/code

# start docker
docker-compose up
```

The config files from the host will be accessible in the container and can be edited from the host. The Rfam site should be available at *http://your_container_ip:3000*.

## Docker cheat sheet

```
# create default virtualbox
docker-machine create --driver virtualbox default

# connect terminal to the docker machine
eval "$(docker-machine env default)"

# build container
docker build -t rfamweb .

# get container IP address
docker-machine ls

# list running docker containers
docker ps

# stop running docker container
docker stop rfamweb

# login to running container from another terminal
docker exec -it rfamweb bash
```

## Testing wiki updates

```
# login to running container
perl PfamScripts/wiki/sync_articles_cron.pl -c RfamWeb/config/wiki.conf
perl PfamScripts/wiki/update_cron.pl        -c RfamWeb/config/wiki.conf
perl PfamScripts/wiki/scrape_cron.pl        -c RfamWeb/config/wiki.conf
```

## To do

* get Rfam code from GitHub instead of SVN
* better handling of configs
