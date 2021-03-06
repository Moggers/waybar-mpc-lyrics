#!/bin/bash -e
urlencode() {
    # urlencode <string>

    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C

    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:$i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done

    LC_COLLATE=$old_lc_collate
}

urldecode() {
    # urldecode <string>

    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

BAD_TRACK=""
while [ 1 ]
do
	SONG_SLUG="$(mpc current -f '%artist% %title%')"
	ENCODED="$(urlencode "$SONG_SLUG")"
	if [[ ! -z "$ENCODED" ]] && [[ "$ENCODED" != "$BAD_TRACK" ]]; then
		REGEX='([0-9]+):([0-9]+)'
		RES="$(curl "https://api.textyl.co/api/lyrics?q=$ENCODED")"
		if [ "$RES" == "No lyrics available" ]; then
			BAD_TRACK="$ENCODED"
			continue
		fi
		COUNTER=0
		LAST_LINE="\"...\""
		while [ "$LAST_LINE" != "null" ]
		do
			SONG_SLUG="$(mpc current -f '%artist% %title%')"
			NEW_ENCODED="$(urlencode "$SONG_SLUG")"
			if [ $NEW_ENCODED != $ENCODED ]; then
				break
			fi
			POSITION=$(mpc status | grep playing | sed 's/^.* \(.\+:.\+\)\/.*$/\1/')
			if [[ $POSITION =~ $REGEX ]]; then
				SECONDS=$((10#${BASH_REMATCH[1]} * 60 + 10#${BASH_REMATCH[2]}))
			else
				break
			fi
			LYRIC_SECONDS="$(echo "$RES" | jq ".[$COUNTER].seconds")"
			if [ "$LYRIC_SECONDS" != "null" ]; then
				if [ "$SECONDS" -gt "$LYRIC_SECONDS" ]; then
					LAST_LINE=$(echo "$RES" | jq ".[$(($COUNTER))].lyrics")
					COUNTER=$(($COUNTER+1))
				fi
			fi
			echo "{\"text\": $LAST_LINE}"
		done
	fi
	sleep 1
done
