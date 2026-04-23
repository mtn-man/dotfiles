function writeiso --description 'Write an ISO image to a USB drive using dd'
    if not command -q fzf
        echo "writeiso: fzf not found" >&2
        return 127
    end

    set -l usage "Usage: writeiso [-n] [-h] <image.iso>"

    argparse -n writeiso 'n/dry-run' 'h/help' -- $argv
    or return 1

    if set -q _flag_help
        echo $usage
        echo
        echo "Options:"
        echo "  -n  Dry run: complete all steps but skip the actual write"
        echo "  -h  Show this help"
        return
    end

    if test (count $argv) -ne 1
        echo $usage >&2
        return 1
    end

    set -l iso_path $argv[1]

    if not test -f "$iso_path" -a -r "$iso_path"
        echo "writeiso: not a readable file: $iso_path" >&2
        return 1
    end

    if not string match -q '*.iso' -- "$iso_path"
        echo "writeiso: file does not have .iso extension: $iso_path" >&2
        return 1
    end

    set -l iso_abs (realpath "$iso_path")

    # disk discovery -- external physical disks only
    # single pass: extract disk IDs and partition counts together
    set -l disk_ids
    set -l disk_part_counts
    set -l cur_disk ""
    set -l cur_parts 0

    for line in (diskutil list external physical 2>/dev/null)
        if string match -qr '^/dev/disk\d+ \(external, physical\)' $line
            if test -n "$cur_disk"
                set disk_ids $disk_ids $cur_disk
                set disk_part_counts $disk_part_counts $cur_parts
            end
            set cur_disk (string replace -r '^/dev/(disk\d+).*' '$1' $line)
            set cur_parts 0
        else if string match -qr '^\s+[1-9][0-9]*:' $line
            set cur_parts (math $cur_parts + 1)
        end
    end
    if test -n "$cur_disk"
        set disk_ids $disk_ids $cur_disk
        set disk_part_counts $disk_part_counts $cur_parts
    end

    if test (count $disk_ids) -eq 0
        echo "writeiso: no external disks found" >&2
        return 1
    end

    set -l menu
    for i in (seq (count $disk_ids))
        set -l disk $disk_ids[$i]
        set -l part_count $disk_part_counts[$i]
        set -l name Unknown
        set -l size ""

        for line in (diskutil info /dev/$disk 2>/dev/null)
            if string match -qr 'Device / Media Name:' $line
                set name (string replace -r '.*Device / Media Name:\s+' '' $line)
            else if string match -qr 'Disk Size:' $line
                set size (string replace -r '.*Disk Size:\s+' '' $line | string replace -r '\s+\(.*' '')
            end
        end

        set -l part_str "$part_count partitions"
        test $part_count -eq 1; and set part_str "1 partition"

        set menu $menu "$disk -- $name [$size, $part_str]"
    end

    set -l choice (
        printf '%s\n' $menu | fzf \
            --prompt='Select target disk > ' \
            --height=~6 \
            --reverse \
            --no-sort
    )
    if test -z "$choice"
        echo "writeiso: aborted -- no disk selected" >&2
        return 1
    end

    set -l disk_id     (string replace -r ' -- .*' '' $choice)
    set -l disk_dev    /dev/$disk_id
    set -l rdisk_dev   /dev/r$disk_id
    set -l disk_name   (string replace -r '^[^ ]+ -- (.+) \[.*' '$1' $choice)
    set -l disk_detail (string replace -r '.*\[(.+)\].*' '$1' $choice)

    set -l iso_size_bytes (stat -f %z "$iso_abs")
    set -l iso_size_gb (math --scale=1 "$iso_size_bytes / 1000000000")

    echo
    echo "  ISO:   $iso_abs  ($iso_size_gb GB)"
    echo "  Disk:  $disk_dev"
    echo "         $disk_name -- $disk_detail"
    echo
    echo "  WARNING: All data on $disk_dev will be destroyed."

    read -P "  Type the disk identifier to confirm ($disk_id): " confirm
    if test "$confirm" != "$disk_id"
        echo "writeiso: confirmation did not match -- aborted" >&2
        return 1
    end

    if set -q _flag_dry_run
        echo "[dry-run] Skipping write"
        return 0
    end

    if not diskutil unmountDisk $disk_dev
        echo "writeiso: unmount failed" >&2
        return 1
    end

    set -l t_start (date +%s)
    sudo dd if="$iso_abs" of="$rdisk_dev" bs=1m status=progress
    set -l dd_exit $status
    set -l t_end (date +%s)

    diskutil eject $disk_dev 2>/dev/null

    if test $dd_exit -ne 0
        echo "writeiso: dd exited with status $dd_exit" >&2
        return 1
    end

    set -l elapsed (math "$t_end - $t_start")
    set -l elapsed_min (math --scale=0 "$elapsed / 60")
    set -l elapsed_sec (math --scale=0 "$elapsed % 60")

    echo "Done. $iso_size_gb GB written in "$elapsed_min"m"$elapsed_sec"s."
end
