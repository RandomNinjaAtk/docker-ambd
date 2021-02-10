# AMBD - Automated MusicBrainz Downloader
[![Docker Build](https://img.shields.io/docker/cloud/automated/randomninjaatk/ambd?style=flat-square)](https://hub.docker.com/r/randomninjaatk/ambd)
[![Docker Pulls](https://img.shields.io/docker/pulls/randomninjaatk/ambd?style=flat-square)](https://hub.docker.com/r/randomninjaatk/ambd)
[![Docker Stars](https://img.shields.io/docker/stars/randomninjaatk/ambd?style=flat-square)](https://hub.docker.com/r/randomninjaatk/ambd)
[![Docker Hub](https://img.shields.io/badge/Open%20On-DockerHub-blue?style=flat-square)](https://hub.docker.com/r/randomninjaatk/ambd)
[![Discord](https://img.shields.io/discord/747100476775858276.svg?style=flat-square&label=Discord&logo=discord)](https://discord.gg/JumQXDc "realtime support / chat with the community." )

[RandomNinjaAtk/ambd](https://github.com/RandomNinjaAtk/docker-ambd) is a script to automatically download and tag music using musicbrainz for use in other audio applications (plex/kodi/jellyfin/emby) 

[![RandomNinjaAtk/ama](https://raw.githubusercontent.com/RandomNinjaAtk/unraid-templates/master/randomninjaatk/img/ama.png)](https://github.com/RandomNinjaAtk/docker-ambd)

## Supported Architectures

The architectures supported by this image are:

| Architecture | Tag |
| :----: | --- |
| x86-64 | latest |

## Version Tags

| Tag | Description |
| :----: | --- |
| latest | Newest release code |


## Parameters

Container images are configured using parameters passed at runtime (such as those above). These parameters are separated by a colon and indicate `<external>:<internal>` respectively. For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container.

| Parameter | Function |
| --- | --- |
| `-e PUID=1000` | for UserID - see below for explanation |
| `-e PGID=1000` | for GroupID - see below for explanation |
| `-v /config` | Configuration files for AMBD |
| `-v /downloads-ambd` | Downloaded location |
| `-v /library-ambd` | Completed library location |
| `-e AUTOSTART=true` | true = Enabled :: Runs script automatically on startup |
| `-e SCRIPTINTERVAL=15m` | #s or #m or #h or #d :: s = seconds, m = minutes, h = hours, d = days :: Amount of time between each script run, when AUTOSTART is enabled|
| `-e QUALITY=FLAC` | SET TO: FLAC or 320 or 128 |
| `-e CONCURRENT_DOWNLOADS=1` | Controls download concurrency |
| `-e EMBEDDED_COVER_QUALITY=80` | Controls the quality of the cover image compression in percentage, 100 = no compression |
| `-e FILE_PERMISSIONS=644` | Based on chmod linux permissions |
| `-e FOLDER_PERMISSIONS=755` | Based on chmod linux permissions |
| `-e ARL_TOKEN=ARLTOKEN` | User token for dl client, for instructions to obtain token: https://notabug.org/RemixDevs/DeezloaderRemix/wiki/Login+via+userToken |
| `-e NOTIFYPLEX=true` | true = enabled :: Plex must have a library added and be configured to use the exact same mount point (/downloads-ama) |
| `-e PLEXLIBRARYNAME=Music` | This must exactly match the name of the Plex Library that contains the Lidarr Media Folder data |
| `-e PLEXURL=http://x.x.x.x:32400` | ONLY used if NOTIFYPLEX is enabled... |
| `-e PLEXTOKEN=plextoken` | ONLY used if NOTIFYPLEX is enabled... |

## Usage

Here are some example snippets to help you get started creating a container.

### docker

```
docker create \
  --name=ambd \
  -v /path/to/config/files:/config \
  -v /path/to/downloads:/downloads-ambd \
  -v /path/to/library:/library-ambd \
  -e PUID=1000 \
  -e PGID=1000 \
  -e AUTOSTART=true \
  -e SCRIPTINTERVAL=1h \
  -e CONCURRENT_DOWNLOADS=1 \
  -e EMBEDDED_COVER_QUALITY=95 \
  -e QUALITY=FLAC \
  -e FILE_PERMISSIONS=644 \
  -e FOLDER_PERMISSIONS=755 \
  -e ARL_TOKEN=ARLTOKEN	\
  -e NOTIFYPLEX=false \
  -e PLEXLIBRARYNAME=Music \
  -e PLEXURL=http://x.x.x.x:8686 \
  -e PLEXTOKEN=plextoken \
  --restart unless-stopped \
  randomninjaatk/ambd 
```

### docker-compose

Compatible with docker-compose v2 schemas.

```
version: "2.1"
services:
  amd:
    image: randomninjaatk/ambd 
    container_name: ambd
    volumes:
      - /path/to/config/files:/config
      - /path/to/downloads:/downloads-ambd
      - /path/to/downloads:/library-ambd
    environment:
      - PUID=1000
      - PGID=1000
      - AUTOSTART=true
      - SCRIPTINTERVAL=1h
      - CONCURRENT_DOWNLOADS=1
      - EMBEDDED_COVER_QUALITY=95
      - QUALITY=FLAC
      - FOLDER_PERMISSIONS=755
      - FILE_PERMISSIONS=644
      - ARL_TOKEN=ARLTOKEN
      - NOTIFYPLEX=false
      - PLEXLIBRARYNAME=Music
      - PLEXURL=http://x.x.x.x:8686
      - PLEXTOKEN=plextoken
    restart: unless-stopped
```

# Script Information
* Script will automatically run when enabled, if disabled, you will need to manually execute with the following command:
  * From Host CLI: `docker exec -it ambd /bin/bash -c 'bash /config/scripts/download.sh'`
  * From Docker CLI: `bash /config/scripts/download.sh`
  
## Directories:
* <strong>/config/scripts</strong>
  * Contains the scripts that are run
* <strong>/config/logs</strong>
  * Contains the log output from the script
* <strong>/config/cache</strong>
  * Contains the artist data cache to speed up processes
* <strong>/config/list/deemix</strong>
  * Contains the artist id file's named `deezerid` for processing
* <strong>/config/deemix</strong>
  * Contains deemix app data
  
<br />
<br />
<br />
<br /> 


# Credits
- [Original Idea based on lidarr-download-automation by Migz93](https://github.com/Migz93/lidarr-download-automation)
- [Deemix download client](https://deemix.app/)
- [Lidarr](https://lidarr.audio/)
- [r128gain](https://github.com/desbma/r128gain)
- [Algorithm Implementation/Strings/Levenshtein distance](https://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Levenshtein_distance)
- Icons made by <a href="http://www.freepik.com/" title="Freepik">Freepik</a> from <a href="https://www.flaticon.com/" title="Flaticon"> www.flaticon.com</a>
