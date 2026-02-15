function gcp --description "Stage all changes, commit (message or editor), push"
    # Ensure we are inside a git repository
    git rev-parse --is-inside-work-tree >/dev/null 2>&1; or begin
        echo "gcp: not inside a git repository" >&2
        return 1
    end

    # Stage all changes (including new files and deletions)
    git add -A; or return 1

    # Abort cleanly if nothing is staged
    git diff --cached --quiet; and begin
        echo "gcp: nothing staged to commit"
        return 0
    end

    # Commit: use message if provided, otherwise open editor
    if test (count $argv) -gt 0
        git commit -m (string join " " -- $argv); or return 1
    else
        git commit; or return 1
    end

    # Push to upstream
    git push
end
