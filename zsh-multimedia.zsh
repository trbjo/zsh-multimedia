
magnetizer() {
    local IFS='│'
    while read -r name seeders leechers size files uploaded category imdb id hash
    do
        printf %s "magnet:?xt=urn:btih:${hash: -40}&dn=${${name%%[[:blank:]]##}// /%20}&tr=udp%3A%2F%2Ftracker.openbittorrent.com%3A6969&tr=udp%3A%2F%2Ftracker.tiny-vps.com%3A6969&tr=udp%3A%2F%2F46.148.18.250%3A2710&tr=udp%3A%2F%2Fopentrackr.org%3A1337"
    done <<< "$@"
}

torrent() {

myQuery="$@"
local IFS=$'\n'
setopt localoptions pipefail no_aliases 2> /dev/null

local torrentList=($(curl -s "https://apibay.org/q.php?q=$myQuery&cat=100,200,300,400,600" |\
                     jq -r '.[] | select(.seeders != "0") |
                     if .imdb != "" then (. + { "hasIMDB": "✓"}) else (. + { "hasIMDB": ""}) end |
                     .size |= tonumber |
                     .name |= (
                     sub("&amp;"; "&"; "g") |
                     sub("&aelig;"; "æ"; "g") |
                     sub("Ã¦"; "æ"; "g") |
                     sub("Ã˜"; "Ø"; "g") |
                     sub("^ "; ""; "g") |
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
                     ) |
                     if .size > 1000000000 then (.size=.size/1000000000 |
                     . + { "Unit": "GB"} ) else (.size=.size/1000000 |
                     . + { "Unit": "MB"} ) end | .added |= (tonumber | todate) |
                     (.size |= tostring) | .size |= split(".") |
                     if .category == "101" then (.category = "Music") elif
                     .category == "102" then (.category = "Audio Book") elif
                     .category == "103" then (.category = "Sound Clip") elif
                     .category == "104" then (.category = "FLAC Music") elif
                     .category == "199" then (.category = "Other Audio") elif
                     .category == "201" then (.category = "Movie") elif
                     .category == "202" then (.category = "DVD Movie") elif
                     .category == "203" then (.category = "Music Video") elif
                     .category == "205" then (.category = "TV-Show") elif
                     .category == "206" then (.category = "Handheld Video") elif
                     .category == "207" then (.category = "HD Movie") elif
                     .category == "208" then (.category = "HD TV-show") elif
                     .category == "299" then (.category = "Other Video") elif
                     .category == "209" then (.category = "3D Movie") elif
                     .category == "301" then (.category = "PC Software") elif
                     .category == "302" then (.category = "Mac Software") elif
                     .category == "303" then (.category = "Linux Software") elif
                     .category == "601" then (.category = "E-book") elif
                     .category == "602" then (.category = "Comics") elif
                     .category == "603" then (.category = "Picture") elif
                     .category == "604" then (.category = "Comics") elif
                     .category == "699" then (.category = "Other") elif
                     .category[0:1] == "4" then (.category = "Game") else . end |
                     "\(.name)│\(.seeders)│\(.leechers)│\(.size[0]).\(.size[1][0:2]) \(.Unit)│\(.num_files)│\(.added[0:10])│\(.category)│\(.hasIMDB)│\(.imdb)│\(.info_hash)"' |\
                     column -s '│' -t --table-columns "Results for ${myQuery:u}",Seeders,Leechers,Size,Files,Uploaded,Category,"IMDB (C-/)" \
                     --output-separator " │     " --table-right Seeders,Leechers,Size,Files,Uploaded,Category,"IMDB (C-/)" |\
                     fzf --exit-0 --multi --reverse --inline-info --ansi --expect=alt-w --prompt="  " \
                     --bind "ctrl-_:execute-silent(if [[ {8} == "✓" ]]; then xdg-open https://www.imdb.com/title/{9}/; fi)" \
                     --color='header:bold:underline:8' --no-preview \
                     --nth=1 --with-nth=1..8 --delimiter="│" \
                     --header-lines=1))

if [[ -z $torrentList ]]; then
    printf 'Got no torrents\n'
    return 0
fi

local key="$(head -1 <<< "${torrentList[@]}")"
case "$key" in
    (alt-w)
        wl-copy -- $(magnetizer "${torrentList[@]:1}")
        [[ ${#torrentList} -gt 2 ]] && printf "Multiple magnet links selected. Only copied the first one\n"
        ;;
    (*)
        local magnets
        for file in "${torrentList[@]}"
        do
            magnets+=($(magnetizer "${file}"))
        done
        (xdg-open ${magnets} &) > /dev/null 2>&1
        # echo "$magnets"
        ;;
esac

}