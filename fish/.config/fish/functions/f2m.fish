function f2m --description 'Convert all .flac files in the current directory to 320k MP3'
    set -l files *.flac
    if test "$files[1]" = "*.flac"
        echo "No .flac files found in "(pwd)
        return 1
    end

    for f in $files
        set -l out (string replace -r '\.flac$' '.mp3' -- "$f")
        ffmpeg -hide_banner -nostdin -n \
            -i "$f" \
            -c:a libmp3lame -b:a 320k \
            -map_metadata 0 -id3v2_version 3 \
            "$out"
    end
end