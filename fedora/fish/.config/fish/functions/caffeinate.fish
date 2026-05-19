function caffeinate
    systemd-inhibit --what=idle --who=fish --why=caffeinate sleep infinity 2>/dev/null
end
