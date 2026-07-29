function devbox --description 'Attach to the persistent host-side tmux session, entering the devbox container on first use'
    tmux new-session -A -s devbox 'podman exec -it -w /home/dev/dev devbox fish'
end
