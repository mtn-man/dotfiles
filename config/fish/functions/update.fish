function update --description 'Update App Store apps, Homebrew, and optionally macOS system'
    argparse 's/sys' -- $argv
    or return

    set -l failed 0

    # 1. Mac App Store
    if command -q mas
        echo (set_color blue)"==>" \
             (set_color normal --bold)" Checking App Store updates..." \
             (set_color normal)
        mas upgrade
        or set failed 1
    end

    # 2. Homebrew
    if command -q brew
        echo (set_color blue)"==>" \
             (set_color normal --bold)" Checking Homebrew updates..." \
             (set_color normal)
        
        if not brew update
            set failed 1
        else
            set -l outdated (brew outdated --quiet)
            if test -n "$outdated"
                brew upgrade
                and brew cleanup
                or set failed 1
            else
                echo "Homebrew packages are up to date."
            end
        end
    else
        echo "update: brew not found; cannot continue" >&2
        return 127
    end

    # 3. macOS System Updates
    if set -q _flag_sys
        echo (set_color blue)"==>" \
             (set_color normal --bold)" Checking for macOS system updates..." \
             (set_color normal)

        set -l sys_updates (softwareupdate -l 2>&1)
        if string match -q "*No new software available*" "$sys_updates"
            echo "macOS is up to date."
        else
            echo "System updates found. Authorizing installation..."
            sudo softwareupdate -ia
            or set failed 1
        end
    end

    if test $failed -eq 0
        echo (set_color normal --bold)"Update complete 🎉"(set_color normal)
    else
        echo "Update finished with errors." >&2
        return 1
    end
end
