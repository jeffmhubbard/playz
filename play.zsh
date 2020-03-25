#!/usr/bin/env zsh


MPD_HOST=127.0.0.1
MPD_PORT=6600
PROXY_URL=http://localhost:9999
PLIST_DIR=$HOME/.cache/mpd/playlists
PLIST_PFX=play
CACHE_AGE=3
AUTO_SKIP=true

DEFAULT_HOST=0.0.0.0
DEFAULT_PORT=6600
DEFAULT_URL=http://localhost:9999
DEFAULT_DIR=$HOME/.config/mpd/playlists
DEFAULT_PFX=playz
DEFAULT_AGE=10
DEFAULT_SKIP=true

[[ ! -d $PLIST_DIR ]] && mkdir $PLIST_DIR 2>/dev/null

function get_search() {
  local action=search
  local cmd=get_by_search
  local proxy=${PROXY_URL:-$DEFAULT_URL}
  local cache=${PLIST_DIR:-$DEFAULT_DIR}
  local prefix=${PLIST_PFX:-$DEFAULT_PFX}

  local -a query=(${(@ws: - :)REQ_STRING})
  if (( $+query ))
  then
    local -A opts
    opts[type]=matches
    opts[exact]=no
    opts[tracks]=20

    local artist=$query[1]
    opts[artist]=$artist
  else
    return 1
  fi

  if [[ $#query -gt 1 ]]
  then
    local title=$query[2]
    opts[title]=$title
  fi

  if [[ -n $OPT_TRACKS ]]
  then
    opts[tracks]=$OPT_TRACKS
  fi

  if [[ $OPT_EXACT == true ]]
  then
    opts[exact]=yes
  fi

  if [[ $OPT_ALBUM == true ]]
  then
    opts[type]=album
  fi

  local m3ufile=$cache/$prefix-$action-${artist// /_}-${title// /_}.m3u
  [[ $OPT_FORCE != true && -f $m3ufile ]] && \
    { [[ $(do_overwrite) != true ]] && return 1; }
  curl -sG $proxy/$cmd \
    --data-urlencode "type=${opts[type]}" \
    --data-urlencode "artist=${opts[artist]}" \
    --data-urlencode "title=${opts[title]}" \
    --data-urlencode "exact=${opts[exact]}" \
    --data-urlencode "num_tracks=${opts[tracks]}" \
    -o ${m3ufile}

  [[ -f $m3ufile ]] && { echo "↓ ${m3ufile:t}"; mpc_auto ${m3ufile:t:r} }
}

function get_radio() {
  local action=radio
  local cmd=get_new_station_by_search
  local proxy=${PROXY_URL:-$DEFAULT_URL}
  local cache=${PLIST_DIR:-$DEFAULT_DIR}
  local prefix=${PLIST_PFX:-$DEFAULT_PFX}

  local -a query=(${(@ws: - :)REQ_STRING})
  if (( $+query ))
  then
    local -A opts
    opts[type]=artist
    opts[exact]=no
    opts[tracks]=20

    local artist=$query[1]
    opts[artist]=$artist
  else
    return 1
  fi

  if [[ $#query -gt 1 ]]
  then
    local title=$query[2]
    opts[title]=$title
  fi

  if [[ -n $OPT_TRACKS ]]
  then
    opts[tracks]=$OPT_TRACKS
  fi

  if [[ $OPT_EXACT == true ]]
  then
    opts[exact]=yes
  fi

  local m3ufile=$cache/$prefix-$action-${artist// /_}-${title// /_}.m3u
  [[ $OPT_FORCE != true && -f $m3ufile ]] && \
    { [[ $(do_overwrite) != true ]] && return 1; }
  curl -sG $proxy/$cmd \
    --data-urlencode "type=${opts[type]}" \
    --data-urlencode "artist=${opts[artist]}" \
    --data-urlencode "title=${opts[title]}" \
    --data-urlencode "exact=${opts[exact]}" \
    --data-urlencode "num_tracks=${opts[tracks]}" \
    -o ${m3ufile}

  [[ -f $m3ufile ]] && { echo "↓ ${m3ufile:t}"; mpc_auto ${m3ufile:t:r} }
}

function get_top() {
  local action=toptracks
  local cmd=get_top_tracks_artist
  local proxy=${PROXY_URL:-$DEFAULT_URL}
  local cache=${PLIST_DIR:-$DEFAULT_DIR}
  local prefix=${PLIST_PFX:-$DEFAULT_PFX}

  local -a query=(${(@ws: - :)REQ_STRING})
  if (( $+query ))
  then
    local artist=$query[1]
    local artistid=$(_get_artist_id $artist)

    local -A opts
    opts[id]=$artistid
    opts[type]=artist
    opts[tracks]=20
  else
    return 1
  fi

  if [[ -n $OPT_TRACKS ]]
  then
    opts[tracks]=$OPT_TRACKS
  fi

  local m3ufile=$cache/$prefix-$action-${artist// /_}.m3u
  [[ $OPT_FORCE != true && -f $m3ufile ]] && \
    { [[ $(do_overwrite) != true ]] && return 1; }
  curl -sG $proxy/$cmd \
    --data-urlencode "type=${opts[type]}" \
    --data-urlencode "id=${opts[id]}" \
    --data-urlencode "num_tracks=${opts[tracks]}" \
    -o ${m3ufile}

  [[ -f $m3ufile ]] && { echo "↓ ${m3ufile:t}"; mpc_auto ${m3ufile:t:r} }
}

function get_discog() {
  local action=album
  local cmd=get_discography_artist
  local proxy=${PROXY_URL:-$DEFAULT_URL}
  local cache=${PLIST_DIR:-$DEFAULT_DIR}
  local prefix=${PLIST_PFX:-$DEFAULT_PFX}

  local -a query=(${(@ws: - :)REQ_STRING})
  if (( $+query ))
  then
    local artist=${query[1]:l}
    local artistid=$(_get_artist_id $artist)

    local -A opts
    opts[id]=$artistid
    opts[format]=text
  else
    return 1
  fi

  IFS=$'\n' output=($(curl -sG $proxy/$cmd \
    --data-urlencode "id=${opts[id]}" \
    --data-urlencode "format=${opts[format]}"))

    for line in $output
    do
      local -a str=(${(@ws:|:)line})
      local album=${str[1]:l}
      local year=$str[2]
      local url=$str[3]
      local m3ufile=$cache/$prefix-$action-${artist// /_}-$year-${album// /_}.m3u
      [[ $OPT_FORCE != true && -f $m3ufile ]] && \
        { [[ $(do_overwrite) != true ]] && return 1; }

      curl $url -so ${m3ufile}
      [[ -f $m3ufile ]] && echo "↓ ${m3ufile:t}"
    done
}

function get_current() {
  local action=current
  local cmd=get_new_station_by_id
  local proxy=${PROXY_URL:-$DEFAULT_URL}
  local cache=${PLIST_DIR:-$DEFAULT_DIR}
  local prefix=${PLIST_PFX:-$DEFAULT_PFX}

  local -A opts
  opts[id]=$(_get_playid)
  opts[type]=song
  opts[tracks]=20

  if [[ -n $OPT_TRACKS ]]
  then
    opts[tracks]=$OPT_TRACKS
  fi

  local m3ufile=$cache/$prefix-$action.m3u
  [[ $OPT_FORCE != true && -f $m3ufile ]] && \
    { [[ $(do_overwrite) != true ]] && return 1; }
  curl -sG $proxy/$cmd \
    --data-urlencode "id=${opts[id]}" \
    --data-urlencode "type=${opts[type]}" \
    --data-urlencode "num_tracks=${opts[tracks]}" \
    -o ${m3ufile}

  [[ -f $m3ufile ]] && { echo "↓ ${m3ufile:t}"; mpc_auto ${m3ufile:t:r} }
}

function get_collection() {
  local action=collection
  local cmd=get_collection
  local proxy=${PROXY_URL:-$DEFAULT_URL}
  local cache=${PLIST_DIR:-$DEFAULT_DIR}
  local prefix=${PLIST_PFX:-$DEFAULT_PFX}

  local -A opts
  opts[shuffle]=yes
  opts[rating]=2

  local m3ufile=$cache/$prefix-$action.m3u
  [[ $OPT_FORCE != true && -f $m3ufile ]] && \
    { [[ $(do_overwrite) != true ]] && return 1; }
  curl -sG $proxy/$cmd \
    --data-urlencode "shuffle=${opts[shuffle]}" \
    --data-urlencode "rating=${opts[rating]}" \
    -o ${m3ufile}

  [[ -f $m3ufile ]] && { echo "↓ ${m3ufile:t}"; mpc_auto ${m3ufile:t:r} }
}

function get_lucky() {
  local action=lucky
  local cmd=get_ifl_station
  local proxy=${PROXY_URL:-$DEFAULT_URL}
  local cache=${PLIST_DIR:-$DEFAULT_DIR}
  local prefix=${PLIST_PFX:-$DEFAULT_PFX}

  local -A opts
  opts[tracks]=20

  if [[ -n $OPT_TRACKS ]]
  then
    opts[tracks]=$OPT_TRACKS
  fi

  local m3ufile=$cache/$prefix-$action.m3u
  [[ $OPT_FORCE != true && -f $m3ufile ]] && \
    { [[ $(do_overwrite) != true ]] && return 1; }
  curl -sG $proxy/$cmd \
    --data-urlencode "num_tracks=${opts[tracks]}" \
    -o ${m3ufile}

  [[ -f $m3ufile ]] && { echo "↓ ${m3ufile:t}"; mpc_auto ${m3ufile:t:r} }
}

function get_thumbsup() {
  local action=promoted
  local cmd=get_promoted
  local proxy=${PROXY_URL:-$DEFAULT_URL}
  local cache=${PLIST_DIR:-$DEFAULT_DIR}
  local prefix=${PLIST_PFX:-$DEFAULT_PFX}

  local -A opts
  opts[shuffle]=yes

  local m3ufile=$cache/$prefix-$action.m3u
  [[ $OPT_FORCE != true && -f $m3ufile ]] && \
    { [[ $(do_overwrite) != true ]] && return 1; }
  curl -sG $proxy/$cmd \
    --data-urlencode "shuffle=${opts[shuffle]}" \
    -o ${m3ufile}

  [[ -f $m3ufile ]] && { echo "↓ ${m3ufile:t}"; mpc_auto ${m3ufile:t:r} }
}

function get_stations() {
  local action=radio
  local cmd=get_all_stations

  local proxy=${PROXY_URL:-$DEFAULT_URL}
  local cache=${PLIST_DIR:-$DEFAULT_DIR}
  local prefix=${PLIST_PFX:-$DEFAULT_PFX}

  local -A opts
  opts[format]=text

  IFS=$'\n' output=($(curl -sG $proxy/$cmd \
    --data-urlencode "format=${opts[format]}"))

  for line in $output
  do
    local -a str=(${(@ws:|:)line})
    local station=${str[1]:l}
    local url=$str[2]
    local m3ufile=$cache/$prefix-$action-${station// /_}.m3u
    [[ $OPT_FORCE != true && -f $m3ufile ]] && \
      { [[ $(do_overwrite) != true ]] && return 1; }

    curl $url -so ${m3ufile}
    [[ -f $m3ufile ]] && echo "↓ ${m3ufile:t}"
  done
}

function get_playlists() {
  local action=playlists
  local cmd=get_all_playlists

  local proxy=${PROXY_URL:-$DEFAULT_URL}
  local cache=${PLIST_DIR:-$DEFAULT_DIR}
  local prefix=${PLIST_PFX:-$DEFAULT_PFX}

  local -A opts
  opts[format]=text

  IFS=$'\n' output=($(curl -sG $proxy/$cmd \
    --data-urlencode "format=${opts[format]}"))

  for line in $output
  do
    local -a str=(${(@ws:|:)line})
    local station=${str[1]:l}
    local url=$str[2]
    local m3ufile=$cache/$prefix-$action-${station// /_}.m3u
    [[ $OPT_FORCE != true && -f $m3ufile ]] && \
      { [[ $(do_overwrite) != true ]] && return 1; }

    curl $url -so ${m3ufile}
    [[ -f $m3ufile ]] && echo "↓ ${m3ufile:t}"
  done
}

#function get_moods() { return }
#function get_artists() { return }
#function get_albums() { return }

function thumb_up() {
  local cmd=like_song
  local proxy=${PROXY_URL:-$DEFAULT_URL}
  local cache=${PLIST_DIR:-$DEFAULT_DIR}
  local prefix=${PLIST_PFX:-$DEFAULT_PFX}

  local -A opts
  opts[id]=$(_get_playid)

  curl -sfG $proxy/$cmd \
    --data-urlencode "id=${opts[id]}"
  echo "Thumbs up!"
}

function thumb_down() {
  local cmd=dislike_song
  local proxy=${PROXY_URL:-$DEFAULT_URL}
  local cache=${PLIST_DIR:-$DEFAULT_DIR}
  local prefix=${PLIST_PFX:-$DEFAULT_PFX}

  local -A opts
  opts[id]=$(_get_playid)

  curl -sfG $proxy/$cmd \
    --data-urlencode "id=${opts[id]}"
  echo "Thumbs down!"
  [[ ${AUTO_SKIP:-$DEFAULT_SKIP} == true ]] && { echo "Skipping..."; mpc_next; }
}

function _get_artist_id() {
  curl -sG $proxy/search_id \
    --data-urlencode "artist=$@" \
    --data-urlencode "type=artist" \
    --data-urlencode "exact=no"
}

function _get_playid() {
  local -a current=(${(@ws:=:)$(mpc current -f "%file%")})
  echo ${current[2]}
}

function mpc_auto() {
  local plist=$1

  [[ $MPC_CLEAR ]] && mpc clear &>/dev/null
  [[ $MPC_LOAD ]] && mpc load $plist &>/dev/null
  [[ $MPC_START ]] && mpc play &>/dev/null
}

function do_overwrite() {
  vared -cp "Overwrite existing (y/n)? " ans
  [[ "$ans" =~ ^[Yy]$ ]] && echo true
}

function mpc_playpause() { mpc toggle &>/dev/null }
function mpc_next() { mpc next &>/dev/null }
function mpc_prev() { mpc prev &>/dev/null }
function mpc_stop() { mpc stop &>/dev/null }

function usage() { echo "don't"; exit 1; }

for arg in $@
do
  case $arg in
    -S | --search) REQ_TYPE=get_search; REQ_STRING=$2; shift 2;;
    -Sr | --search-radio) REQ_TYPE=get_radio; REQ_STRING=$2; shift 2;;
    -St | --search-top) REQ_TYPE=get_top; REQ_STRING=$2; shift 2;;
    -Sd | --search-discog) REQ_TYPE=get_discog; REQ_STRING=$2; shift 2;;
    -Sc | --search-current) REQ_TYPE=get_current; shift;;
    -F | --fetch-collection) REQ_TYPE=get_collection; shift;;
    -Fl | --fetch-lucky) REQ_TYPE=get_lucky; shift;;
    -Ft | --fetch-thumbs) REQ_TYPE=get_thumbsup; shift;;
    -Fs | --fetch-stations) REQ_TYPE=get_stations; shift;;
    -Fp | --fetch-playlists) REQ_TYPE=get_playlists; shift;;
#    -L | --listen-moods) REQ_TYPE=get_moods; shift;;
#    -Lr | --listen-artist) REQ_TYPE=get_artists; shift;;
#    -La | --listen-album) REQ_TYPE=get_albums; shift;;
    -Tu | --thumb-up) REQ_TYPE=thumb_up; shift;;
    -Td | --thumb-down) REQ_TYPE=thumb_down; shift;;
    -Mt | --mpc-toggle) REQ_TYPE=mpc_playpause; shift;;
    -Mn | --mpc-next) REQ_TYPE=mpc_next; shift;;
    -Mp | --mpc-prev) REQ_TYPE=mpc_prev; shift;;
    -Ms | --mpc-stop) REQ_TYPE=mpc_stop; shift;;
    -t | --tracks) OPT_TRACKS=$2; shift 2;;
    -e | --exact) OPT_EXACT=true; shift;;
    -a | --album) OPT_ALBUM=true; shift;;
    -f | --force) OPT_FORCE=true; shift;;
    -c | --clear) MPC_CLEAR=true; shift;;
    -l | --load) MPC_LOAD=true; shift;;
    -s | --start) MPC_START=true; shift;;
    -A | --auto) OPT_FORCE=true; MPC_CLEAR=true; MPC_LOAD=true; MPC_START=true; shift;;
    -h | --help) usage;;
  esac
done

$REQ_TYPE

exit 0

# vim: ft=zsh ts=2 sw=0 et:
