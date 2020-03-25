#!/usr/bin/env zsh

# playz - fetch playlists from gmusicproxy

APPNAME=playz
APPVER=0.0.1

DEFAULT_CONF=$HOME/.config/playz/config
DEFAULT_HOST=0.0.0.0
DEFAULT_PORT=6600
DEFAULT_URL=http://localhost:9999
DEFAULT_DIR=$HOME/.config/mpd/playlists
DEFAULT_PFX=playz
DEFAULT_AGE=10
DEFAULT_SKIP=true

# return playlist of search results
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
    { echo "⁈ $m3ufile exists!"; [[ $(do_overwrite) != true ]] && return 1; }
  curl -sG $proxy/$cmd \
    --data-urlencode "type=${opts[type]}" \
    --data-urlencode "artist=${opts[artist]}" \
    --data-urlencode "title=${opts[title]}" \
    --data-urlencode "exact=${opts[exact]}" \
    --data-urlencode "num_tracks=${opts[tracks]}" \
    -o ${m3ufile}

  [[ -f $m3ufile ]] && { echo "↓ ${m3ufile:t}"; mpc_auto ${m3ufile:t:r} }
}

# return playlist of new station
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
    { echo "⁈ $m3ufile exists!"; [[ $(do_overwrite) != true ]] && return 1; }
  curl -sG $proxy/$cmd \
    --data-urlencode "type=${opts[type]}" \
    --data-urlencode "artist=${opts[artist]}" \
    --data-urlencode "title=${opts[title]}" \
    --data-urlencode "exact=${opts[exact]}" \
    --data-urlencode "num_tracks=${opts[tracks]}" \
    -o ${m3ufile}

  [[ -f $m3ufile ]] && { echo "↓ ${m3ufile:t}"; mpc_auto ${m3ufile:t:r} }
}

# return playlist of artist top tracks
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
    { echo "⁈ $m3ufile exists!"; [[ $(do_overwrite) != true ]] && return 1; }
  curl -sG $proxy/$cmd \
    --data-urlencode "type=${opts[type]}" \
    --data-urlencode "id=${opts[id]}" \
    --data-urlencode "num_tracks=${opts[tracks]}" \
    -o ${m3ufile}

  [[ -f $m3ufile ]] && { echo "↓ ${m3ufile:t}"; mpc_auto ${m3ufile:t:r} }
}

# return all playlists in artist discography
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
        { echo "⁈ $m3ufile exists!"; [[ $(do_overwrite) != true ]] && return 1; }

      curl $url -so ${m3ufile}
      [[ -f $m3ufile ]] && echo "↓ ${m3ufile:t}"
    done
}

# return playlist of station from current song
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
    { echo "⁈ $m3ufile exists!"; [[ $(do_overwrite) != true ]] && return 1; }
  curl -sG $proxy/$cmd \
    --data-urlencode "id=${opts[id]}" \
    --data-urlencode "type=${opts[type]}" \
    --data-urlencode "num_tracks=${opts[tracks]}" \
    -o ${m3ufile}

  [[ -f $m3ufile ]] && { echo "↓ ${m3ufile:t}"; mpc_auto ${m3ufile:t:r} }
}

# return playlist of user's collection
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
    { echo "⁈ $m3ufile exists!"; [[ $(do_overwrite) != true ]] && return 1; }
  curl -sG $proxy/$cmd \
    --data-urlencode "shuffle=${opts[shuffle]}" \
    --data-urlencode "rating=${opts[rating]}" \
    -o ${m3ufile}

  [[ -f $m3ufile ]] && { echo "↓ ${m3ufile:t}"; mpc_auto ${m3ufile:t:r} }
}

# return I'm Feeling Lucky playlist
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
    { echo "⁈ $m3ufile exists!"; [[ $(do_overwrite) != true ]] && return 1; }
  curl -sG $proxy/$cmd \
    --data-urlencode "num_tracks=${opts[tracks]}" \
    -o ${m3ufile}

  [[ -f $m3ufile ]] && { echo "↓ ${m3ufile:t}"; mpc_auto ${m3ufile:t:r} }
}

# return playlist of promoted song (thumbs up)
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
    { echo "⁈ $m3ufile exists!"; [[ $(do_overwrite) != true ]] && return 1; }
  curl -sG $proxy/$cmd \
    --data-urlencode "shuffle=${opts[shuffle]}" \
    -o ${m3ufile}

  [[ -f $m3ufile ]] && { echo "↓ ${m3ufile:t}"; mpc_auto ${m3ufile:t:r} }
}

# return all station playlists
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
      { echo "⁈ $m3ufile exists!"; [[ $(do_overwrite) != true ]] && return 1; }

    curl $url -so ${m3ufile}
    [[ -f $m3ufile ]] && echo "↓ ${m3ufile:t}"
  done
}

# return all user playlists
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
      { echo "⁈ $m3ufile exists!"; [[ $(do_overwrite) != true ]] && return 1; }

    curl $url -so ${m3ufile}
    [[ -f $m3ufile ]] && echo "↓ ${m3ufile:t}"
  done
}

# thumbs up current song
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

# thumbs down current song
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

# return artist id
function _get_artist_id() {
  curl -sG $proxy/search_id \
    --data-urlencode "artist=$@" \
    --data-urlencode "type=artist" \
    --data-urlencode "exact=no"
}

# return play id (track)
function _get_playid() {
  local -a current=(${(@ws:=:)$(mpc current -f "%file%")})
  echo ${current[2]}
}

# run mpc commands
function mpc_auto() {
  local plist=$1

  [[ $MPC_CLEAR ]] && mpc clear &>/dev/null
  [[ $MPC_LOAD ]] && mpc load $plist &>/dev/null
  [[ $MPC_START ]] && mpc play &>/dev/null
}

# confirm overwrite
function do_overwrite() {
  vared -cp "Overwrite existing (y/n)? " ans
  [[ "$ans" =~ ^[Yy]$ ]] && echo true
}

# confirm delete
function do_delete() {
  vared -cp "Confirm delete (y/n)? " ans
  [[ "$ans" =~ ^[Yy]$ ]] && echo true
}

# mpc controls
function mpc_show() { mpc status }
function mpc_list() { mpc playlist | less }
function mpc_playpause() { mpc toggle &>/dev/null }
function mpc_next() { mpc next &>/dev/null }
function mpc_prev() { mpc prev &>/dev/null }
function mpc_stop() { mpc stop &>/dev/null }

# purge playlists
function purge_cache() {
  local cache=${PLIST_DIR:-$DEFAULT_DIR}
  local prefix=${PLIST_PFX:-$DEFAULT_PFX}
  local match=$PURGE_TYPE:l
  local -a actions=(radio search album playlist promoted current lucky)
  local pattern

  if [ -d $cache ]
  then
    [[ -n $prefix ]] && pattern+="$prefix-"
    for action in $actions
    do
      if [[ $action == $match ]]
      then
        pattern+="$action-"
      fi
    done

    [[ $OPT_FORCE != true ]] && \
      { echo "⁈ Matching playlists: $pattern"; [[ $(do_delete) != true ]] && return 1; }
    if find $cache -name "$pattern*" -type f -exec rm -f {} \;
    then
      echo "Done"
    fi
  fi
}

# no help message
function usage() {
  echo "$APPNAME ($APPVER)"
  echo " fetch playlists from gmusicproxy"
  echo
  echo "Usage:"
  echo " $APPNAME -S 'the worst band - terrible song about nothing' --tracks 10 --auto"
  echo
  echo "Search:"
  echo " -S,  --search          return results from search"
  echo " -Sr, --search-radio    return new station from search "
  echo " -St, --search-top      return artist's top tracks"
  echo " -Sd, --search-discog   return artist's discography"
  echo " -Sc, --search-current  return new station from current song"
  echo
  echo "Fetch:"
  echo " -F,  --fetch           fetch collection playlist"
  echo " -Fl, --fetch-lucky     fetch IFL playlist"
  echo " -Ft, --fetch-thumbs    fetch promoted playlist"
  echo " -Fd, --fetch-stations  fetch all station playlists"
  echo " -Fc, --fetch-playlists fetch all user playlists"
  echo
  echo "Rating:"
  echo " -Tu, --thumb-up        like song"
  echo " -Td, --thumb-down      dislike song"
  echo
  echo "Purge:"
  echo " -P,  --purge           purge playlists"
  echo
  echo "Mpc:"
  echo " -M,  --mpc-show        show mpc status"
  echo " -Ml, --mpc-list        show current playlist"
  echo " -Mt, --mpc-toggle      toggle play - pause"
  echo " -Mn, --mpc-next        next track"
  echo " -Mp, --mpc-prev        previous track"
  echo " -Ms, --mpc-stop        stop playback"
  echo
  echo "Global:"
  echo " -t,  --tracks          number of tracks to return"
  echo " -e,  --exact           return exact match"
  echo " -a,  --album           return album match"
  echo " -f,  --force           do not prompt for confirmation"
  echo " -c,  --clear           clear mpd playlist"
  echo " -l,  --load            load playlist"
  echo " -s,  --start           start playlist"
  echo " -A,  --auto            verbose output"
  echo " -h,  --help            show this help message and exit"
  echo
}

##################################################

for arg in $@
do
  case $arg in
    # search
    -S | --search) RUN_CMD=get_search; REQ_STRING=$2; shift 2;;
    -Sr | --search-radio) RUN_CMD=get_radio; REQ_STRING=$2; shift 2;;
    -St | --search-top) RUN_CMD=get_top; REQ_STRING=$2; shift 2;;
    -Sd | --search-discog) RUN_CMD=get_discog; REQ_STRING=$2; shift 2;;
    -Sc | --search-current) RUN_CMD=get_current; shift;;
    # fetch
    -F | --fetch-collection) RUN_CMD=get_collection; shift;;
    -Fl | --fetch-lucky) RUN_CMD=get_lucky; shift;;
    -Ft | --fetch-thumbs) RUN_CMD=get_thumbsup; shift;;
    -Fs | --fetch-stations) RUN_CMD=get_stations; shift;;
    -Fp | --fetch-playlists) RUN_CMD=get_playlists; shift;;
    # thumbs up/down
    -Tu | --thumb-up) RUN_CMD=thumb_up; shift;;
    -Td | --thumb-down) RUN_CMD=thumb_down; shift;;
    # purge playlists
    -P | --purge) RUN_CMD=purge_cache; PURGE_TYPE=$2; shift 2;;
    # mpc controls
    -M | --mpc-show) RUN_CMD=mpc_show; shift;;
    -Ml | --mpc-list) RUN_CMD=mpc_list; shift;;
    -Mt | --mpc-toggle) RUN_CMD=mpc_playpause; shift;;
    -Mn | --mpc-next) RUN_CMD=mpc_next; shift;;
    -Mp | --mpc-prev) RUN_CMD=mpc_prev; shift;;
    -Ms | --mpc-stop) RUN_CMD=mpc_stop; shift;;
    # common arguments
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

[[ -f $DEFAULT_CONF ]] && source $DEFAULT_CONF
[[ ! -d $PLIST_DIR ]] && mkdir -p $PLIST_DIR 2>/dev/null

$RUN_CMD

exit 0

# vim: ft=zsh ts=2 sw=0 et:
