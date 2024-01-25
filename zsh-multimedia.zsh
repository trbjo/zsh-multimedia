# we find out whether we are on Mac or Linux
case $OSTYPE in
     (darwin*)
        # we assume you use Transmission
        file_opener=("open" "-a" "/Applications/Transmission.app")
        clipboard="pbpaste"
        ;;
    (linux-gnu)
        file_opener="xdg-open"
        clipboard=("wl-copy" "-n")
        ;;
     (*)
    printf "Your platform is not supported. Please open an issue"
    return 1
        ;;
esac

column_separator='│'

magnetizer() {
    unset IFS
    trackers=(
              'udp%3A%2F%2Ftracker.openbittorrent.com%3A6969'
              'udp%3A%2F%2Ftracker.tiny-vps.com%3A6969'
              'udp%3A%2F%2F46.148.18.250%3A2710'
              'udp%3A%2F%2Fopentrackr.org%3A1337'
              )
    local trackerstring
    for tracker in $trackers; trackerstring+="&tr=$tracker"

    local IFS=$column_separator
    while read -r name seeders leechers size files uploaded category imdb id hash
    do
        [[ -z $hash ]] && continue
        printf %s "magnet:?xt=urn:btih:${hash: -40}&dn=${${${name%%[[:blank:]]##}// /%20}//&/%26}$trackerstring"
    done <<< "$@"
}

typeset -gA pb_categories=(
    "audio"    100
    "video"    200
    "software" 300
    "game"     400
    "other"    600
)

join_arr() {
    local repr="$1"
    shift
    print -n "${*// /${repr}}"
}

alias torrent='noglob _torrent'
_torrent() {
    setopt localoptions pipefail no_aliases 2> /dev/null
    local __jq_filter='
    map(
        if .seeders then .seeders |= tonumber end |
        select(.seeders > 0)) |
    map(
        if .size then .size |= tonumber end |
        if .size > 1000000000 then
            (. + { "prettySize": (.size/1000000000)} | .prettySize=.prettySize*100 | .prettySize|=round/100 | .prettySize |= tostring + " GB" )
        else
           (. + { "prettySize": (.size/1000000)} | .prettySize=.prettySize*100 | .prettySize|=round/100 | .prettySize |= tostring + " MB" )
        end |
        if .leechers then .leechers |= tonumber else . end |
        if .num_files then .num_files |= tonumber else . end |
        if .imdb != "" then (. + { "hasIMDB": "✓"}) else (. + { "hasIMDB": ""}) end |
        if .added then .added |= (tonumber | todate) | .added = .added[0:10] else . end |
        if .name then .name |= (
            sub("&amp;"; "&"; "g") |
            sub("&aelig;"; "æ"; "g") |
            sub("Ã¦"; "æ"; "g") |
            sub("Ã˜"; "Ø"; "g") |
            sub("^ "; ""; "g") |
            sub("Ã©"; "é"; "g") |
            sub("\t"; ""; "g") |
            sub("&Atilde;&cedil;"; "ø"; "g") |
            sub("&hellip;"; "…"; "g") |
            sub("&oslash;"; "ø"; "g") |
            sub("Ã¸"; "ø"; "g") |
            sub("Ã¶"; "ö"; "g") |
            sub("&ouml;"; "ö"; "g") |
            sub("Ã–"; "Ö"; "g") |
            sub("&auml;"; "ä"; "g") |
            sub("&ndash;"; "–"; "g") |
            sub("&mdash;"; "—"; "g") |
            sub("ï¿½"; "ä"; "g") |
            sub("Ã¤"; "ä"; "g") |
            sub("&Auml;"; "Ä"; "g") |
            sub("&Ouml;"; "Ö"; "g") |
            sub("Ã„"; "Ä"; "g") |
            sub("Ã¥"; "å"; "g") |
            sub("&aring;"; "å"; "g") |
            sub("&Aring;"; "Å"; "g") |
            sub("Ã…"; "Å"; "g") |
            sub("&frac12;"; "½"; "g") |
            sub("&ntilde;"; "ñ"; "g") |
            sub("Ã±"; "ñ"; "g") |
            sub("&eacute;"; "é"; "g") |
            sub("\\\\"; ""; "g") |
            sub("Ã†"; "Æ"; "g") |
            sub("&uuml;"; "ü"; "g") |
            sub("&quot;"; "\""; "g")
            ) end |
        if .category == "101" then (.category = "Music")
        elif .category == "102" then (.category = "Audio Book")
        elif .category == "103" then (.category = "Sound Clip")
        elif .category == "104" then (.category = "FLAC Music")
        elif .category == "199" then (.category = "Other Audio")
        elif .category == "201" then (.category = "Movie")
        elif .category == "202" then (.category = "DVD Movie")
        elif .category == "203" then (.category = "Music Video")
        elif .category == "205" then (.category = "TV-Show")
        elif .category == "206" then (.category = "Handheld Video")
        elif .category == "207" then (.category = "HD Movie")
        elif .category == "208" then (.category = "HD TV-show")
        elif .category == "299" then (.category = "Other Video")
        elif .category == "209" then (.category = "3D Movie")
        elif .category == "301" then (.category = "PC Software")
        elif .category == "302" then (.category = "Mac Software")
        elif .category == "303" then (.category = "Linux Software")
        elif .category == "601" then (.category = "E-book")
        elif .category == "602" then (.category = "Comics")
        elif .category == "603" then (.category = "Picture")
        elif .category == "604" then (.category = "Comics")
        elif .category == "699" then (.category = "Other")
        elif .category[0:1] == "4" then (.category = "Game") else . end
        ) |'


    typeset -A selected_cats
    typeset -a query
    local sort_order
    local arg
    for arg in "$@"; do
        case "${arg}" in
            (--sort=*)
                sort_order="${arg##*=}"
                case $sort_order in
                    (date|added)
                        __jq_filter+=" . | sort_by(.added) | reverse | "
                        ;;
                    (size)
                        __jq_filter+=" . | sort_by(.size) | reverse | "
                        ;;
                    (leechers)
                        __jq_filter+=" . | sort_by(.leechers) | reverse | "
                        ;;
                    (files|num_files)
                        __jq_filter+=" . | sort_by(.num_files) | reverse | "
                        ;;
                    (*)
                        ;;
                esac
                ;;
            (--cat=*|--category=*)
                local stripped="${arg##*=}"
                local cat=${pb_categories[${stripped}]}
                [[ -n "$cat" ]] && selected_cats[$stripped]=$cat
                ;;
            (*)
                query+="$arg"
                ;;
        esac
    done
    [[ -z $selected_cats ]] && selected_cats=(${(@kv)pb_categories})
    local commacategories=$(join_arr ',' ${selected_cats})
    local commacategories_pretty=$(join_arr ', ' ${(@k)selected_cats})
    local server_resp=$(curl -s --get \
                        --data-urlencode "q=$query" \
                        --data-urlencode "cat=$commacategories" \
                        https://apibay.org/q.php)

    if [[ -z $server_resp ]]; then
        print 'Server seems to be down'
        return 1
    fi
   __jq_filter+=' .[] |
         "\(.name)│\(.seeders)│\(.leechers)│\(.prettySize)│\(.num_files)│\(.added)│\(.category)│\(.hasIMDB)│\(.imdb)│\(.info_hash)"'

    local parsed=$(jq -r "$__jq_filter" <<< $server_resp)
    if [[ -z $parsed ]]; then
        print "Got zero results for \"${query[*]}\" in the categories ${commacategories_pretty}"
        return 0
    fi
    cyan=$'\x1b[36m'
    reset=$'\x1b[0m'
    bold=$'\x1b[1m'
    italic=$'\x1b[3m'
    white=$'\x1b[37m'
    colorcolumn="${white}${column_separator}${reset}"

    local columns=$(column -s "$column_separator" -t --table-columns "Results for $italic${query[*]}$reset in categories: $(join_arr ' ' ${(@k)selected_cats})",Seeders,Leechers,Size,Files,Uploaded,Category,"IMDB (C-/)"  --output-separator " $colorcolumn     "  --table-right Seeders,Leechers,Size,Files,Uploaded,Category,"IMDB (C-/)" <<< $parsed)

    local IFS=$'\n'

    typeset -a selected_torrents=($(fzf \
                                    --no-sort \
                                    --exit-0 \
                                    --multi \
                                    --inline-info \
                                    --expect=alt-w \
                                    --bind "ctrl-_:execute-silent([[ {8} != "✓" ]] || $file_opener https://www.imdb.com/title/{9}/)" \
                                    --color='header:bold:underline:7' \
                                    --no-preview \
                                    --nth=1 \
                                    --with-nth=1..8 \
                                    --delimiter="$colorcolumn" \
                                    --header-lines=1 <<< $columns))


    if [[ -z $selected_torrents ]]; then
        return 0
    fi

    typeset -a magnets=()
    for raw in $selected_torrents; magnets+=($(magnetizer "${raw}"))

    local key="$(head -1 <<< "${selected_torrents[@]}")"
    case "$key" in
        (alt-w)
            $clipboard <<< $magnets
            ;;
        (*)
            ($file_opener ${magnets} &) > /dev/null 2>&1
            ;;
    esac
    return 0
}
