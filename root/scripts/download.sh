#!/usr/bin/with-contenv bash
export XDG_CONFIG_HOME="/config/deemix/xdg"
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
agent="automated-musicbrainz-downloaderr ( https://github.com/RandomNinjaAtk/docker-ambd )"
DOWNLOADLOCATION=/downloads-ambd
LIBRARYLOCATION=/library-ambd
LIDARR_API_KEY=""
LIDARR_URL=""
LIDARR_ROOT_FOLDER=""
export CONCURRENT_DOWNLOADS
export EMBEDDED_COVER_QUALITY

log () {
    m_time=`date "+%F %T"`
    echo $m_time" "$1
}

Configuration () {
	processstartid="$(ps -A -o pid,cmd|grep "start.bash" | grep -v grep | head -n 1 | awk '{print $1}')"
	processdownloadid="$(ps -A -o pid,cmd|grep "download.bash" | grep -v grep | head -n 1 | awk '{print $1}')"
	log "To kill script, use the following command:"
	log "kill -9 $processstartid"
	log "kill -9 $processdownloadid"
	log ""
	log ""
	sleep 2
	log "######################### $TITLE"
	log "######################### SCRIPT VERSION 0.0.1"
	log "######################### DOCKER VERSION $VERSION"
	log "######################### CONFIGURATION VERIFICATION"
	error=0

	if [ ! -z "$ARL_TOKEN" ]; then
		if [ ! -d "/config/deemix/xdg/deemix" ]; then
			mkdir -p "/config/deemix/xdg/deemix"
		fi
		if [ -f "$XDG_CONFIG_HOME/deemix/.arl" ]; then
			rm "$XDG_CONFIG_HOME/deemix/.arl"
		fi
		 if [ ! -f "$XDG_CONFIG_HOME/deemix/.arl" ]; then
			echo -n "$ARL_TOKEN" > "$XDG_CONFIG_HOME/deemix/.arl"
			log "$TITLESHORT: ARL Token: Configured"
		fi
	else
		log "ERROR: ARL_TOKEN setting invalid, currently set to: $ARL_TOKEN"
		error=1
	fi
	
	if [ -f /config/beets-config.yaml ]; then
		log "$TITLESHORT: Custom Beets Config detected, using \"/config/beets-config.yaml\""
		beetconfig=/config/beets-config.yaml
	else
		log "$TITLESHORT: Using Default Beets Config. \"/config/scripts/beets-config.yaml\""
		beetconfig=/config/scripts/beets-config.yaml
	fi

	if [ "$NOTIFYPLEX" == "true" ]; then
		log "$TITLESHORT: Plex Library Notification: ENABLED"
		plexlibraries="$(curl -s "$PLEXURL/library/sections?X-Plex-Token=$PLEXTOKEN" | xq .)"
		if echo "$plexlibraries" | grep "$LIBRARYLOCATION" | read; then
			plexlibrarykey="$(echo "$plexlibraries" | jq -r ".MediaContainer.Directory[] | select(.\"@title\"==\"$PLEXLIBRARYNAME\") | .\"@key\"" | head -n 1)"
			if [ -z "$plexlibrarykey" ]; then
				log "ERROR: No Plex Library found named \"$PLEXLIBRARYNAME\""
				error=1
			fi
		else
			log "ERROR: No Plex Library found containg path \"/downloads-ama\""
			log "ERROR: Add \"$LIBRARYLOCATION\" as a folder to a Plex Music Library or Disable NOTIFYPLEX"
			error=1
		fi
	else
		log "$TITLESHORT: Plex Library Notification: DISABLED"
	fi

	if [ $error = 1 ]; then
		log "Please correct errors before attempting to run script again..."
		log "Exiting..."
		exit 1
	fi
	sleep 2.5
}

ArtistInfo () {
	
	if [ -f /config/cache/artists/$1/$1-info.json ]; then
		touch -d "168 hours ago" /config/cache/cache-info-check
		if find /config/cache/artists/$1 -type f -iname "$1-info.json" -not -newer "/config/cache/cache-info-check" | read; then
			updatedartistdata=$(curl -sL --fail "https://api.deezer.com/artist/$1")
			newalbumcount=$(echo "$updatedartistdata" | jq -r ".nb_album")
			existingalbumcount=$(cat /config/cache/artists/$1/$1-info.json | jq -r ".nb_album")
			if [ $newalbumcount != $existingalbumcount ]; then
				rm /config/cache/artists/$1/$1-info.json
				echo "$updatedartistdata" > /config/cache/artists/$1/$1-info.json
			fi
		else
			touch /config/cache/artists/$1/$1-info.json
		fi
		rm /config/cache/cache-info-check
	fi

	if [ ! -f /config/cache/artists/$1/$1-info.json ]; then
		if curl -sL --fail "https://api.deezer.com/artist/$1" -o /config/cache/$1-info.json; then
			if [ ! -d /config/cache/artists/$1 ]; then
				mkdir -p /config/cache/artists/$1
			fi
			mv /config/cache/$1-info.json /config/cache/artists/$1/$1-info.json
		else
			log "Processing Artist ID :: $artistid :: ERROR :: getting artist information"
		fi
	fi
	
	if [ -f /config/cache/artists/$1/$1-related.json ]; then
		touch -d "730 hours ago" /config/cache/cache-related-check
		find /config/cache/artists/$1 -type f -iname "$1-related.json" -not -newer "/config/cache/cache-related-check" -delete
		rm /config/cache/cache-related-check
	fi
	
	if ! [ -f /config/cache/artists/$1/$1-related.json ]; then
		if curl -sL --fail "https://api.deezer.com/artist/$1/related" -o /config/cache/$1-temp-related.json ; then
			jq "." /config/cache/$1-temp-related.json > /config/cache/$1-related.json
			if [ ! -d /config/cache/artists/$1 ]; then
				mkdir -p /config/cache/artists/$1
			fi
			mv  /config/cache/$1-related.json /config/cache/artists/$1/$1-related.json
			rm /config/cache/$1-temp-related.json
		else
			log "Processing Artist ID :: $artistid :: ERROR :: getting artist related information"
		fi
	fi

	if [ ! -f /config/cache/artists/$1/folder.jpg ]; then
		artistpictureurl=$(cat "/config/cache/artists/$1/$1-info.json" | jq -r ".picture_xl" | sed 's%80-0-0.jpg%100-0-0.jpg%g')
		curl -s "$artistpictureurl" -o /config/cache/artists/$1/folder.jpg
	fi
}

ArtistDeemixAlbumList () {

	albumcount="$(python3 /config/scripts/artist_discograpy.py "$1" | sort -u | wc -l)"
	if [ -d /config/cache/artists/$1/albums/deezer ]; then
		cachecount=$(ls /config/cache/artists/$1/albums/deezer/* | wc -l)
	else
		cachecount=0
	fi
	albumids=($(python3 /config/scripts/artist_discograpy.py "$1" | sort -u))
	log "Processing Artist ID :: $artistid :: Searching for All Albums...."
	log "Processing Artist ID :: $artistid :: $albumcount Albums found!"
	
	if [ $albumcount != $cachecount ]; then
		if [ ! -d "/config/temp" ]; then
			mkdir "/config/temp"
		fi
		for id in ${!albumids[@]}; do
			currentprocess=$(( $id + 1 ))
			albumid="${albumids[$id]}"
			if [ ! -d /config/cache/artists/$artistid/albums/deezer ]; then
				mkdir -p /config/cache/artists/$artistid/albums/deezer
			fi
			if [ ! -f /config/cache/artists/$artistid/albums/deezer/${albumid}.json ]; then
				if curl -sL --fail "https://api.deezer.com/album/${albumid}" -o "/config/temp/${albumid}.json"; then
					log "Processing Artist ID :: $artistid :: $currentprocess of $albumcount :: Downloading Album info..."
					mv /config/temp/${albumid}.json /config/cache/artists/$artistid/albums/deezer/${albumid}.json
				else
					log "Processing Artist ID :: $artistid :: $currentprocess of $albumcount :: Error getting album information"
				fi
			else
				log "Processing Artist ID :: $artistid :: $currentprocess of $albumcount :: Album info already downloaded"
			fi
		done
		chown -R abc:abc /config/cache/artists/$artistid
		if [ -d "/config/temp" ]; then
			rm -rf "/config/temp"
		fi
	fi
	
#	if [ $albumcount != $cachecount ]; then
#		for id in ${!albumids[@]}; do
#			currentprocess=$(( $id + 1 ))
#			albumid="${albumids[$id]}"
#			if [ ! -d /config/cache/artists/$1/albums/deezer/ ]; then
#				mkdir -p /config/cache/artists/$1/albums/deezer
#				chmod $FOLDERPERM /config/cache/artists/$1
#				chmod $FOLDERPERM /config/cache/artists/$1/albums/deezer
#				chown -R abc:abc /config/cache/artists/$1
#			fi
#			if [ ! -f /config/cache/artists/$1/albums/deezer/${albumid} ]; then
#				touch /config/cache/artists/$1/albums/deezer/${albumid}
#			fi
#		done
#	fi
}



DownloadDeemix () {
	python3 /config/scripts/dlclient.py -b $QUALITY "$1"
}

DownloadTDL () {
	tidal-dl -o "$DOWNLOADLOCATION/temp"
    tidal-dl -r P1080
	tidal-dl -l "$1"
}


TagFilesWithBeets () {	
	if find "$DOWNLOADLOCATION/temp" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | read; then
		if [ -f /config/library.blb ]; then
			rm /config/library.blb
		fi
		if [ -f /config/beets-match ]; then
			rm /config/beets-match
		fi
		if [ -f /config/beets.log ]; then
			rm /config/beets.log
		fi
		touch /config/beets-match
		sleep 0.5
		beet -c $beetconfig -l /config/library.blb -d "$DOWNLOADLOCATION/temp" import -q "$DOWNLOADLOCATION/temp"		
		if find $DOWNLOADLOCATION/temp -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -newer "/config/beets-match" | read; then
			log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: SUCCESS: Matched with beets!"
			find $DOWNLOADLOCATION/temp -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -not -newer "/config/beets-match" -delete
			if ! [ -d /config/logs/downloads/deemix ]; then
				mkdir -p /config/logs/downloads/deemix
			fi
			touch /config/logs/downloads/deemix/matched-$albumid
		else
			touch $DOWNLOADLOCATION/temp/beet-error
			sleep 0.5
			rm -rf $DOWNLOADLOCATION/temp/*
			sleep 0.5
			rm -rf $DOWNLOADLOCATION/temp
			log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: ERROR: Unable to match using beets to a musicbrainz release, marking download as failed..."
			if ! [ -d /config/logs/downloads/deemix ]; then
				mkdir -p /config/logs/downloads/deemix
			fi
			touch /config/logs/downloads/deemix/skipped-$albumid
		fi
		rm /config/beets-match
	fi
}


PlexNotification () {

	if [ "$NOTIFYPLEX" == "true" ]; then
		plexfolder="$1"
		plexfolderencoded="$(jq -R -r @uri <<<"${plexfolder}")"
		curl -s "$PLEXURL/library/sections/$plexlibrarykey/refresh?path=$plexfolderencoded&X-Plex-Token=$PLEXTOKEN"
		log "$logheader :: Plex Scan notification sent! ($plexfolder)"
	fi
}

CreateDownloadLocation () {
	if ! [ -d "$DOWNLOADLOCATION/temp" ]; then
		mkdir -p "$DOWNLOADLOCATION/temp"
	else
		rm -rf "$DOWNLOADLOCATION/temp"/*
	fi
}

DownloadDAlbums () {
	trackartistids=""
	albumlistdata=$(jq -s '.' /config/cache/artists/$1/albums/deezer/*.json)
	albumids=($(echo "$albumlistdata" | jq -r "sort_by(.nb_tracks) | sort_by(.explicit_lyrics and .nb_tracks) | reverse | .[].id"))
	albumidscount=$(echo "$albumlistdata" | jq -r "sort_by(.nb_tracks) | sort_by(.explicit_lyrics and .nb_tracks) | reverse | .[].id" | wc -l)
	for id in ${!albumids[@]}; do
		albumprocess=$(( $id + 1 ))
		albumid="${albumids[$id]}"
		albumurl="https://deezer.com/album/$albumid"
		trackartistids=($(cat /config/cache/artists/$1/albums/deezer/$albumid.json | jq -r '.tracks.data | .[].artist.id' | sort -u))
		if [ ! -f /config/logs/downloads/deemix/matched-$albumid ] && [ ! -f /config/logs/downloads/deemix/skipped-$albumid ]; then
			log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: Sending \"$albumurl\" to deemix..."
			DownloadDeemix "$albumurl" "$2"
			if find "$DOWNLOADLOCATION/temp"  -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | read; then
				log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: Download Complete"
				file=$(find "$DOWNLOADLOCATION/temp" -regex ".*/.*\.\(flac\|mp3\)" | head -n 1)
				if [ ! -z "$file" ]; then
					artwork="$(dirname "$file")/folder.jpg"
					if ffmpeg -y -i "$file" -c:v copy "$artwork" 2>/dev/null; then
						log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: Artwork Extracted"
					else
						log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: ERROR :: No artwork found"
					fi
				fi
				ConsolidateDwownloadedFiles
				TagFilesWithBeets
				MoveDownloadedFilesToImportFolder
			fi
		else
			log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: Already downloaded $albumid, skipping..."
		fi
	done
}

DownloadTAlbums () {
	for fname in /config/cache/artists/$1/albums/tidal-dl/*; do
		albumid=$(basename "$fname")
]		DownloadTDL "$albumid"
		if find "$DOWNLOADLOCATION/temp"  -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | read; then
			if ! [ -d /config/logs/downloads/tidal-dl ]; then
				mkdir -p /config/logs/downloads/tidal-dl
			fi
			touch /config/logs/downloads/tidal-dl/$albumid
		fi
	done
}

ConsolidateDwownloadedFiles () {
	find "$DOWNLOADLOCATION/temp" -type f -print0 | while IFS= read -r -d '' file; do
		filename="$(basename "$file")"
		if find "$DOWNLOADLOCATION/temp" -type d  -mindepth 1 | read; then
			log "$albumprocess of $albumidscount :: Consolidating Files..."
			if [ ! -f "$DOWNLOADLOCATION/temp/$filename" ]; then 
				mv "$file" "$DOWNLOADLOCATION/temp/$filename"
			else
				rm "$file"
			fi
			log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: Complete"
		fi
	done
}

AlbumArtistTagFix () {
	if find /downloads-ambd/temp -iname "*.flac" | read; then
		if ! [ -x "$(command -v metaflac)" ]; then
			echo "ERROR: FLAC verification utility not installed (ubuntu: apt-get install -y flac)"
		else
			for fname in /downloads-ambd/temp/*.flac; do
				filename="$(basename "$fname")"
				metaflac "$fname" --remove-tag=ALBUMARTIST
				metaflac "$fname" --remove-tag=ARTISTSORT
				metaflac "$fname" --remove-tag=ALBUMARTISTSORT
				metaflac "$fname" --remove-tag=COMPOSERSORT
				metaflac "$fname" --set-tag=ALBUMARTIST="$1"
				log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount ::  Correcting Album Artist :: $filename fixed..."
			done
		fi
	fi
	if find /downloads-ambd/temp -iname "*.mp3" | read; then
		if ! [ -x "$(command -v eyeD3)" ]; then
			echo "eyed3 verification utility not installed (ubuntu: apt-get install -y eyed3)"
		else
			for fname in /downloads-ambd/temp/*.mp3; do
				filename="$(basename "$fname")"
				eyeD3 "$fname" -b "$1" &> /dev/null
				eyeD3 "$fname" --user-text-frame='ALBUMARTISTSORT:' &> /dev/null
				eyeD3 "$fname" --text-frame="TSOP:" &> /dev/null
				log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: Correcting Album Artist :: $filename fixed..."
			done
		fi
	fi
}

MoveDownloadedFilesToImportFolder () {
	if [ -d "$DOWNLOADLOCATION/temp" ] && [ ! -f "$DOWNLOADLOCATION/temp/beet-error" ]; then
		file=$(find "$DOWNLOADLOCATION/temp"  -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | head -n 1)
		filetags=$(ffprobe -v quiet -print_format json -show_format "$file" | jq -r '.[] | .tags')
		#echo "$filetags"
		if echo "$file" | grep ".flac" | read; then
			mbrainzreleasegroupid=$(echo $filetags | jq -r '.MUSICBRAINZ_RELEASEGROUPID')
			mbrainzalbumid=$(echo $filetags | jq -r '.MUSICBRAINZ_ALBUMID')
			mbrainzalbumartistid=$(echo $filetags | jq -r '.MUSICBRAINZ_ALBUMARTISTID')
			mbrainzalbumtype=$(echo $filetags | jq -r '.MUSICBRAINZ_ALBUMTYPE')
			mbrainzalbumyear=$(echo $filetags | jq -r '.DATE')
			mbrainzalbumname=$(echo $filetags | jq -r '.ALBUM')
		fi
		if echo "$file" | grep ".mp3" | read; then
			mbrainzreleasegroupid=$(echo $filetags | jq -r '."MusicBrainz Release Group Id"')
			mbrainzalbumid=$(echo $filetags | jq -r '."MusicBrainz Album Id"')
			mbrainzalbumartistid=$(echo $filetags | jq -r '."MusicBrainz Album Artist Id"')
			mbrainzalbumtype=$(echo $filetags | jq -r '."MusicBrainz Album Type"')
			mbrainzalbumyear=$(echo $filetags | jq -r '.date')
			mbrainzalbumname=$(echo $filetags | jq -r '.album')
		fi
		#echo "$mbrainzreleasegroupid"
		#echo "$mbrainzalbumartistid"
		
		if [ ! -d /config/cache/musicbrainz/releasegroupid ]; then
			mkdir -p /config/cache/musicbrainz/releasegroupid
		fi
		if [ ! -f /config/cache/musicbrainz/releasegroupid/$mbrainzalbumartistid ]; then
			curl -s -A "$agent" "https://musicbrainz.org/ws/2/release-group/$mbrainzreleasegroupid?fmt=json" -o /config/cache/musicbrainz/releasegroupid/$mbrainzreleasegroupid
			sleep 1.5
		fi

		albumdata=$(cat /config/cache/musicbrainz/releasegroupid/$mbrainzreleasegroupid)
		if [ ! -d /config/cache/musicbrainz/artistid ]; then
			mkdir -p /config/cache/musicbrainz/artistid
		fi
		if [ ! -f /config/cache/musicbrainz/artistid/$mbrainzalbumartistid ]; then
			curl -s -A "$agent" "https://musicbrainz.org/ws/2/artist/$mbrainzalbumartistid?inc=url-rels&fmt=json" -o /config/cache/musicbrainz/artistid/$mbrainzalbumartistid
			sleep 1.5
		fi
		artistdata=$(cat /config/cache/musicbrainz/artistid/$mbrainzalbumartistid)
		wantitalbumartistdeezerid=($(echo "$artistdata" | jq -r '.relations | .[] | .url | select(.resource | contains("deezer")) | .resource'))
		for url in ${!wantitalbumartistdeezerid[@]}; do
			deemixurl="${wantitalbumartistdeezerid[$url]}"
			deemixid=$(echo "${deemixurl}" | grep -o '[[:digit:]]*')
			mkdir -p /config/list/deemix
			if [ ! -f /config/list/deemix/$deemixid ]; then
				touch /config/list/deemix/$deemixid
				log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: Adding Missing Artist ID ($deemixid) to list..."
			fi
		done
		for id in ${!trackartistids[@]}; do
			trackartistidprocess=$(( $id + 1 ))
			trackartistid="${trackartistids[$id]}"
			if [ ! -f /config/list/deemix/$trackartistid ]; then
				touch /config/list/deemix/$trackartistid
				log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: Adding Missing Artist ID ($trackartistid) to list..."
			fi
		done
		#echo "$albumdata"
		#echo "$artistdata"
		albumname="$(echo "$albumdata" | jq -r ".title")"
		albumartistname="$(echo "$artistdata" | jq -r ".name")"
		sanatizedalbumartistname="$(echo "$albumartistname" | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g")"
		sanatizedalbumname="$(echo "$mbrainzalbumname" | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g")"
		AlbumArtistTagFix "$albumartistname"
		if [ ! -d /config/logs/imported/musicbrainz/releasegroup-id ]; then
			mkdir -p /config/logs/imported/musicbrainz/releasegroup-id
		fi
		if [ ! -f "/config/logs/imported/musicbrainz/releasegroup-id/$sanatizedalbumartistname-$sanatizedalbumname-$mbrainzreleasegroupid-$mbrainzalbumid" ]; then
			touch "/config/logs/imported/musicbrainz/releasegroup-id/$sanatizedalbumartistname-$sanatizedalbumname-$mbrainzreleasegroupid-$mbrainzalbumid"
			mkdir -p "$LIBRARYLOCATION/$sanatizedalbumartistname ($mbrainzalbumartistid)/$sanatizedalbumartistname - ${mbrainzalbumtype^^} - ${mbrainzalbumyear:0:4} - $sanatizedalbumname ($mbrainzalbumid)"
			log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: $sanatizedalbumartistname - $sanatizedalbumname :: Adding Album to Lidarr..."
			#AddAlbumToLidarr "$mbrainzalbumartistid" "$mbrainzreleasegroupid"
			log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: $sanatizedalbumartistname - $sanatizedalbumname :: Moving to import folder..."
			find "$DOWNLOADLOCATION/temp" -type f -print0 | while IFS= read -r -d '' file; do
				mv "$file" "$LIBRARYLOCATION/$sanatizedalbumartistname ($mbrainzalbumartistid)/$sanatizedalbumartistname - ${mbrainzalbumtype^^} - ${mbrainzalbumyear:0:4} - $sanatizedalbumname ($mbrainzalbumid)"/
			done
			sleep 2
			log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: $sanatizedalbumartistname - $sanatizedalbumname :: Notifying Lidarr to Import..."
			#NotifyLidarrToImport "$LIBRARYLOCATION/$sanatizedalbumartistname - $sanatizedalbumname (WEB)"
			PlexNotification "$LIBRARYLOCATION/$sanatizedalbumartistname ($mbrainzalbumartistid)/$sanatizedalbumartistname - ${mbrainzalbumtype^^} - ${mbrainzalbumyear:0:4} - $sanatizedalbumname ($mbrainzalbumid)"
		else
			if find "$DOWNLOADLOCATION/temp" -type f -iname "* (Explicit).*" | read; then
				if find "$LIBRARYLOCATION/$sanatizedalbumartistname ($mbrainzalbumartistid)/$sanatizedalbumartistname - ${mbrainzalbumtype^^} - ${mbrainzalbumyear:0:4} - $sanatizedalbumname ($mbrainzalbumid)" -type f -iname "* (Explicit).*" | read; then
					log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: Already Imported :: $sanatizedalbumartistname - $sanatizedalbumname (WEB) :: Skipping..."
				else
					if [ ! -d "$LIBRARYLOCATION/$sanatizedalbumartistname ($mbrainzalbumartistid)/$sanatizedalbumartistname - ${mbrainzalbumtype^^} - ${mbrainzalbumyear:0:4} - $sanatizedalbumname ($mbrainzalbumid)" ]; then
						mkdir -p "$LIBRARYLOCATION/$sanatizedalbumartistname ($mbrainzalbumartistid)/$sanatizedalbumartistname - ${mbrainzalbumtype^^} - ${mbrainzalbumyear:0:4} - $sanatizedalbumname ($mbrainzalbumid)"
					else
						rm -rf "$LIBRARYLOCATION/$sanatizedalbumartistname ($mbrainzalbumartistid)/$sanatizedalbumartistname - ${mbrainzalbumtype^^} - ${mbrainzalbumyear:0:4} - $sanatizedalbumname ($mbrainzalbumid)"/*
						find "$DOWNLOADLOCATION/temp" -type f -print0 | while IFS= read -r -d '' file; do
							mv "$file" "$LIBRARYLOCATION/$sanatizedalbumartistname ($mbrainzalbumartistid)/$sanatizedalbumartistname - ${mbrainzalbumtype^^} - ${mbrainzalbumyear:0:4} - $sanatizedalbumname ($mbrainzalbumid)"/
						done
						sleep 2
						log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: $sanatizedalbumartistname - $sanatizedalbumname :: Notifying Lidarr to Import..."
						# NotifyLidarrToImport "$LIBRARYLOCATION/$sanatizedalbumartistname - $sanatizedalbumname (WEB)"
						PlexNotification "$LIBRARYLOCATION/$sanatizedalbumartistname ($mbrainzalbumartistid)/$sanatizedalbumartistname - ${mbrainzalbumtype^^} - ${mbrainzalbumyear:0:4} - $sanatizedalbumname ($mbrainzalbumid)"
					fi
				fi
			else
				log "Processing Artist ID :: $artistid :: $albumprocess of $albumidscount :: Already Imported :: $sanatizedalbumartistname - $sanatizedalbumname (WEB) :: Skipping..."
			fi
		fi
	fi

}

AddAlbumToLidarr () {
	curl --request POST --url $LIDARR_URL/api/v1/album --header "application/x-www-form-urlencoded; charset=UTF-8" -d "{
		\"title\": \"\",
		\"disambiguation\": \"\",
		\"overview\": \"\",
		\"artistId\": 0,
		\"foreignAlbumId\": \"$2\",
		\"monitored\": true,
		\"anyReleaseOk\": true,
		\"profileId\": 0,
		\"duration\": 0,
		\"albumType\": \"\",
		\"secondaryTypes\": [],
		\"mediumCount\": 1,
		\"ratings\": {
		\"votes\": 0,
		\"value\": 0
		},
		\"releaseDate\": \"0001-01-01T00:00:00Z\",
		\"releases\": [],
		\"genres\": [],
		\"media\": [],
		\"artist\": {
		\"status\": \"continuing\",
		\"ended\": false,
		\"artistName\": \"\",
		\"foreignArtistId\": \"$1\",
		\"tadbId\": 0,
		\"discogsId\": 0,
		\"overview\": \"\",
		\"disambiguation\": \"\",
		\"links\": [],
		\"images\": [],
		\"qualityProfileId\": 1,
		\"metadataProfileId\": 1,
		\"albumFolder\": true,
		\"monitored\": true,
		\"genres\": [],
		\"tags\": [],
		\"added\": \"0001-01-01T00:00:00Z\",
		\"ratings\": {
			\"votes\": 0,
			\"value\": 0
		},
		\"statistics\": {
			\"albumCount\": 0,
			\"trackFileCount\": 0,
			\"trackCount\": 0,
			\"totalTrackCount\": 0,
			\"sizeOnDisk\": 0,
			\"percentOfTracks\": 0
		},
		\"addOptions\": {
			\"monitor\": \"all\",
			\"searchForMissingAlbums\": false
		},
		\"rootFolderPath\": \"$LIDARR_ROOT_FOLDER\"
		},
		\"images\": [],
		\"links\": [],
		\"remoteCover\": \"\",
		\"addOptions\": {
		\"searchForNewAlbum\": false
		}
	}" --header "X-Api-Key:${LIDARR_API_KEY}"
}

NotifyLidarrToImport () {
	curl "$LIDARR_URL/api/v1/command" --header "X-Api-Key:"${LIDARR_API_KEY} --data "{\"name\":\"DownloadedAlbumsScan\", \"path\":\"${1}\"}"
}

Configuration
if find /config/list/deemix/ -type f | read; then
	for fname in /config/list/deemix/*; do
		artistid=$(basename "$fname")
		if [ $artistid == 5080 ]; then
			continue
		fi
		log "Processing Artist ID :: $artistid"
		ArtistInfo "$artistid"
		ArtistDeemixAlbumList "$artistid"
		CreateDownloadLocation
		DownloadDAlbums "$artistid" "$QUALITY'"
	done
else
	log "ERROR :: No Artists to process..."
fi
