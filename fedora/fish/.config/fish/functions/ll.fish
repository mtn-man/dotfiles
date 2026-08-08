function ll --wraps=ls --description 'List contents of directory using long format'
    eza -lh --git --group-directories-first --icons $argv
end
