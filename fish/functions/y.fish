# yazi's own recommended wrapper: `cd`s the shell to wherever you ended up
# browsing, since exiting yazi normally doesn't affect the parent shell.
function y --description "yazi, cd to wherever you end up"
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set cwd (command cat -- "$tmp"); and test -n "$cwd"; and test "$cwd" != "$PWD"
        cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
