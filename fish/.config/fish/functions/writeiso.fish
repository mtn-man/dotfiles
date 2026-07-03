function writeiso --description 'Write an ISO image to a USB drive using dd'
    set -l usage "writeiso: usage: writeiso [-n] [-h] <image.iso>"

    argparse -n writeiso 'n/dry-run' 'h/help' -- $argv
    or return 1

    if set -q _flag_help
        echo $usage
        echo "writeiso: options:"
        echo "writeiso:   -n  dry run: complete all steps but skip the actual write"
        echo "writeiso:   -h  show this help"
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

    if not string match -qi '*.iso' -- "$iso_path" && not string match -qi '*.img' -- "$iso_path"
        echo "writeiso: file does not have .iso or .img extension: $iso_path" >&2
        return 1
    end

    set -l iso_abs (realpath "$iso_path")

    # disk discovery -- external physical disks only
    # single pass: extract disk IDs and partition counts together
    set -l disk_ids
    set -l disk_part_counts
    set -l disk_byte_counts
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
        else if string match -qr '^\s+[1-9]\d*:\s' $line
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
        set -l bytes 0

        for line in (diskutil info /dev/$disk 2>/dev/null)
            if string match -qr 'Device / Media Name:' $line
                set name (string replace -r '.*Device / Media Name:\s+' '' $line)
            else if string match -qr 'Disk Size:' $line
                set size (string replace -r '.*Disk Size:\s+' '' $line | string replace -r '\s+\(.*' '')
                set bytes (string replace -r '.*\((\d+) Bytes\).*' '$1' $line)
            end
        end

        set disk_byte_counts $disk_byte_counts $bytes

        set -l part_str "$part_count partitions"
        test $part_count -eq 1; and set part_str "1 partition"

        set menu $menu "$disk -- $name [$size, $part_str]"
    end

    if test (count $menu) -eq 1
        set choice $menu[1]
    else
        echo "writeiso: available disks:"
        for i in (seq (count $menu))
            printf "  [%d] %s\n" $i $menu[$i]
        end
        echo

        read -P "writeiso: select disk [1-"(count $menu)"]: " pick
        if not string match -qr '^\d+$' -- $pick
            or test $pick -lt 1; or test $pick -gt (count $menu)
            echo "writeiso: invalid selection -- aborted" >&2
            return 1
        end
        set choice $menu[$pick]
    end

    set -l disk_id     (string replace -r ' -- .*' '' $choice)
    set -l disk_dev    /dev/$disk_id
    set -l rdisk_dev   /dev/r$disk_id
    set -l disk_name   (string replace -r '^[^ ]+ -- (.+) \[.*' '$1' $choice)
    set -l disk_detail (string replace -r '.*\[(.+)\].*' '$1' $choice)

    if diskutil info $disk_dev | string match -q "*Internal: Yes*"
        echo "writeiso: refusing to operate on internal disk: $disk_dev" >&2
        return 1
    end

    set -l iso_size_bytes (stat -f %z "$iso_abs")
    set -l iso_size_gb (math --scale=1 "$iso_size_bytes / 1000000000")

    set -l disk_idx (contains -i -- $disk_id $disk_ids)
    set -l disk_bytes $disk_byte_counts[$disk_idx]
    if test "$disk_bytes" -gt 0 -a "$iso_size_bytes" -gt "$disk_bytes"
        set -l disk_size_gb (math --scale=1 "$disk_bytes / 1000000000")
        echo "writeiso: ISO ($iso_size_gb GB) exceeds disk capacity ($disk_size_gb GB) -- aborted" >&2
        return 1
    end

    echo
    echo "writeiso: ISO:   $iso_abs  ($iso_size_gb GB)"
    echo "writeiso: Disk:  $disk_dev"
    echo "writeiso:        $disk_name -- $disk_detail"
    echo "writeiso: WARNING: all data on $disk_dev will be destroyed."
    echo
    read -P "writeiso: type the disk identifier to confirm ($disk_id): " confirm
    if test "$confirm" != "$disk_id"
        echo "writeiso: confirmation did not match -- aborted" >&2
        return 1
    end

    if set -q _flag_dry_run
        echo "writeiso: dry-run -- skipping write"
        return 0
    end

    if not diskutil info $disk_dev >/dev/null 2>&1
        echo "writeiso: $disk_id is no longer present" >&2
        return 1
    end

    sudo -v
    or return 1

    if not diskutil unmountDisk $disk_dev >/dev/null
        echo "writeiso: unmount failed" >&2
        return 1
    end

    set -l t_start (date +%s)
    # status=progress is supported by macOS dd as of modern releases; not a compatibility issue
    sudo dd if="$iso_abs" of="$rdisk_dev" bs=4m status=progress
    set -l dd_exit $status
    set -l t_end (date +%s)

    if test $dd_exit -ne 0
        echo "writeiso: dd exited with status $dd_exit" >&2
        return 1
    end

    set -l elapsed (math "$t_end - $t_start")
    set -l elapsed_min (math --scale=0 "$elapsed / 60")
    set -l elapsed_sec (math --scale=0 "$elapsed % 60")

    if not diskutil eject $disk_dev >/dev/null
        echo "writeiso: eject failed -- you may need to eject $disk_dev manually" >&2
    else
        echo "writeiso: $disk_dev is safe to remove."
    end

    printf "writeiso: done. %s GB written in %sm%ss.\n" $iso_size_gb $elapsed_min $elapsed_sec
end
