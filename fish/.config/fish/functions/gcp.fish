function gcp --description "Review changes, stage all, commit (message or editor), push"
    # 1. Pre-flight: Ensure we are inside a git repository
    git rev-parse --is-inside-work-tree >/dev/null 2>&1; or begin
        echo "gcp: not inside a git repository" >&2
        return 1
    end

    # 2. Observability: Show what will be staged
    echo (set_color yellow)"==> Pending Changes (git status -sb):"(set_color normal)
    git status -sb

    echo
    echo (set_color yellow)"==> Impact Analysis (git diff --stat):"(set_color normal)
    git diff --stat

    # Also show untracked files (diff --stat won't include them)
    set -l untracked (git ls-files --others --exclude-standard)
    if set -q untracked[1]
        echo
        echo (set_color yellow)"==> Untracked Files (will be added):"(set_color normal)
        printf '%s\n' $untracked
    end

    # 3. Guardrail: Pause for awareness (abort only on explicit 'n')
    if status is-interactive
        echo
        read -n 1 -P "Proceed with stage, commit, and push? [Y/n] " confirm
        echo

        # Abort ONLY if user presses n or N
        if string match -qr '^[Nn]$' -- "$confirm"
            echo "gcp: aborted" >&2
            return 1
        end
    end

    # 4. Execution: Stage all changes (repo-wide)
    git add -A; or return 1

    # 5. Verification: Abort cleanly if nothing resulted from the add
    if git diff --cached --quiet
        echo "gcp: nothing staged to commit"
        return
    end

    # 6. Commit: Use message if provided, otherwise open editor
    if test (count $argv) -gt 0
        git commit -m (string join " " -- $argv); or return 1
    else
        git commit; or return 1
    end

    # 7. Push: Send to upstream
    git push; or return 1
end
