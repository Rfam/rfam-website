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
export RFAM_CODE=/path/to/source/code

# create a symbolic link for shared static files
ln -s /$RFAM_CODE/PfamBase/root/static /$RFAM_CODE/RfamWeb/root/shared

# start docker
docker-compose up
```

The config files from the host will be accessible in the container and can be edited from the host. The Rfam site should be available at *http://0.0.0.0:3000*.

## Docker cheat sheet

```
# list running docker containers
docker ps

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
