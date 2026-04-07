function mp3sort --description "Organize MP3s from 'Artist - Album - Track.mp3' into Artist/Album/Track.mp3"
    set -l dir ~/Downloads

    set -l files (fd -e mp3 --max-depth 1 . $dir)
    if test (count $files) -eq 0
        echo "No .mp3 files found in $dir"
        return 1
    end

    for f in $files
        set -l base (basename $f .mp3)
        set -l parts (string split " - " $base)

        if test (count $parts) -ne 3
            echo "Skipping (expected 3 parts): $base.mp3"
            continue
        end

        set -l artist $parts[1]
        set -l album $parts[2]
        set -l track $parts[3]
        set -l dest $dir/$artist/$album

        mkdir -p $dest
        mv $f $dest/$track.mp3
        echo "Moved: $base.mp3 → $artist/$album/$track.mp3"
    end
end
