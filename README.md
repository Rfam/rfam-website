# Rfam website

Get a local installation of Rfam website using [Docker](https://www.docker.com/)
and the public Rfam MySQL database.

## Development

Clone this repository, then start docker:

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
