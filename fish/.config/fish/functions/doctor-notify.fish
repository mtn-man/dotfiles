function doctor-notify --description 'Run doctor and notify via Notification Center on warnings or criticals'
    doctor --remote
    set -l code $status
    switch $code
        case 1
            osascript -e 'display notification "Run doctor for details." with title "Health check: warnings" sound name "Funk"'
        case 2
            osascript -e 'display notification "Run doctor for details." with title "Health check: critical issues" sound name "Basso"'
    end
    return $code
end
