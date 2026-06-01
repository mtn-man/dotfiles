function caffeinate
    if not command -q systemd-inhibit
        echo "caffeinate: systemd-inhibit not found" >&2
        return 127
    end
    systemd-inhibit --what=idle --who=fish --why=caffeinate sleep infinity
end
