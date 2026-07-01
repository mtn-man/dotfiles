function fish_prompt --description 'Write out the prompt'
    set -l last_pipestatus $pipestatus

    if not set -q __prompt_git_cfg_done
        set -g __prompt_git_cfg_done 1

        set -g __fish_git_prompt_showdirtystate 1
        set -g __fish_git_prompt_showuntrackedfiles 1
        set -g __fish_git_prompt_showupstream auto
        set -g __fish_git_prompt_color_branch yellow
        set -g __fish_git_prompt_char_dirtystate '✚'
        set -g __fish_git_prompt_char_stagedstate '●'
        set -g __fish_git_prompt_char_untrackedfiles '…'
        set -g __fish_git_prompt_char_upstream_ahead '↑'
        set -g __fish_git_prompt_char_upstream_behind '↓'
    end

    set -l color_cwd
    set -l suffix
    if functions -q fish_is_root_user; and fish_is_root_user
        if set -q fish_color_cwd_root
            set color_cwd $fish_color_cwd_root
        else
            set color_cwd $fish_color_cwd
        end
        set suffix '#'
    else
        set color_cwd $fish_color_cwd
        set suffix '➤'
    end

    # PWD
    set_color $color_cwd
    echo -n (prompt_pwd)
    set_color normal

    # Cache fish_vcs_prompt to avoid expensive git calls on every render.
    # Invalidates when: PWD changes, .git/HEAD changes (commit/checkout), or TTL expires.
    set -l now (date +%s)
    set -l vcs_str
    set -l cache_stale 1
    if set -q __git_prompt_cache_pwd __git_prompt_cache_time __git_prompt_cache_gitdir
        and test "$__git_prompt_cache_pwd" = "$PWD"
        and test (math "$now - $__git_prompt_cache_time") -lt 3
        set -l head_now ''
        test -n "$__git_prompt_cache_gitdir"
            and read head_now < "$__git_prompt_cache_gitdir/HEAD" 2>/dev/null
        test "$head_now" = "$__git_prompt_cache_head"
        and set cache_stale 0
    end

    if test $cache_stale -eq 1
        set vcs_str (fish_vcs_prompt)
        set -g __git_prompt_cache_pwd $PWD
        set -g __git_prompt_cache_time $now
        set -g __git_prompt_cache_val $vcs_str
        set -g __git_prompt_cache_gitdir (git rev-parse --git-dir 2>/dev/null)
        set -g __git_prompt_cache_head ''
        test -n "$__git_prompt_cache_gitdir"
            and read -g __git_prompt_cache_head < "$__git_prompt_cache_gitdir/HEAD" 2>/dev/null
    else
        set vcs_str $__git_prompt_cache_val
    end

    printf '%s ' $vcs_str


    set -l status_color (set_color $fish_color_status)
    set -l statusb_color (set_color --bold $fish_color_status)
    set -l prompt_status (__fish_print_pipestatus "[" "]" "|" \
        "$status_color" "$statusb_color" $last_pipestatus)
    echo -n $prompt_status
    set_color normal

    echo -n "$suffix "
end
