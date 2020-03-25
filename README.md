# playz

Fetch playlists from GMusicProxy

### Usage
```
 playz -S 'the worst band - terrible song about nothing' --tracks 10 --auto

Search:
 -S,  --search          return playlist from search
 -Sr, --search-radio    return new station from search
 -St, --search-top      return artist's top tracks
 -Sd, --search-discog   return artist's discography
 -Sc, --search-current  return new station from current song

Fetch:
 -F,  --fetch           fetch collection playlist
 -Fl, --fetch-lucky     fetch IFL playlist
 -Ft, --fetch-thumbs    fetch promoted playlist
 -Fd, --fetch-stations  fetch all station playlists
 -Fc, --fetch-playlists fetch all user playlists

Rating:
 -Tu, --thumb-up        like song
 -Td, --thumb-down      dislike song

Purge:
 -P,  --purge           purge playlists

Mpc:
 -M,  --mpc-show        show mpc status
 -Ml, --mpc-list        show current playlist
 -Mt, --mpc-toggle      toggle play - pause
 -Mn, --mpc-next        next track
 -Mp, --mpc-prev        previous track
 -Ms, --mpc-stop        stop playback

Global:
 -t,  --tracks          number of tracks to return
 -e,  --exact           return exact match
 -a,  --album           return album match
 -f,  --force           do not prompt for confirmation
 -c,  --clear           clear mpd playlist
 -l,  --load            load playlist
 -s,  --start           start playlist
 -A,  --auto            verbose output
 -h,  --help            show this help message and exit
```
