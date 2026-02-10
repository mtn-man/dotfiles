function gcp --description "Stage all changes, commit in editor, push"
    # Ensure we are inside a git repository
    git rev-parse --is-inside-work-tree >/dev/null 2>&1; or begin
        echo "gcp: not inside a git repository" >&2
        return 1
    end

    # Stage all changes (including new files and deletions)
    git add -u; or return 1

    # Abort cleanly if nothing is staged
    git diff --cached --quiet; and begin
        echo "gcp: nothing staged to commit"
        return 0
    end

    # Open commit editor (micro via core.editor)
    git commit; or return 1

    # Push to upstream
    git push
end
