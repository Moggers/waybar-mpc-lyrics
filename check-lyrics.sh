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

while [ 1 ]
do
	SONG_SLUG="$(mpc current -f '%artist% %title%')"
	ENCODED="$(urlencode "$SONG_SLUG")"
	if [ ! -z "$ENCODED" ]
	then
		REGEX='([0-9]+):([0-9]+)'
		RES="$(curl "https://api.textyl.co/api/lyrics?q=$ENCODED")"
		COUNTER=1
		LAST_LINE="\"None\""
		while [ "$LAST_LINE" != "null" ]
		do
			POSITION=$(mpc status | grep playing | sed 's/^.* \(.\+:.\+\)\/.*$/\1/')
			if [[ $POSITION =~ $REGEX ]]
			then
				SECONDS=$((10#${BASH_REMATCH[1]} * 60 + 10#${BASH_REMATCH[2]}))
			else
				break
			fi
			LYRIC_SECONDS="$(echo "$RES" | jq ".[$COUNTER].seconds")"
			if [ "$LYRIC_SECONDS" != "null" ]
			then
				if [ "$SECONDS" -gt "$LYRIC_SECONDS" ] 
				then
					COUNTER=$(($COUNTER+1))
					LAST_LINE=$(echo "$RES" | jq ".[$(($COUNTER-1))].lyrics")
				fi
			fi
			echo "{\"text\": $LAST_LINE}"
		done
	fi
	sleep 1
done
