# Rfam website

[![Build Status](https://jenkins.rnacentral.org/buildStatus/icon?job=update_rfam_website)](https://jenkins.rnacentral.org/job/update_rfam_website/)

Get a local installation of Rfam website using [Docker](https://www.docker.com/)
and the public Rfam MySQL database.

## Development

Clone this repository, create an .env file with Rfam DB credentials (refer to example.env) then start docker:

```
docker-compose up
```

The Rfam site should be available at *http://0.0.0.0:3000*.

By default the website connects to the public Rfam database but an alternative
database can be specified in `config/rfamweb_local.conf` (ignored by git).

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

## Testing sequence search results

Examples:

* http://127.0.0.1:3000/search/sequence/D8DFBEE8-B719-11E6-A6D1-7304307CE5B7
* http://127.0.0.1:3000/search/sequence/187279F8-2B4E-11E7-BA5A-5513307CE5B7
