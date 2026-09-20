# foot can't render config.jsonc's kitty-graphics-protocol logo (Sixel only),
# so it gets the minimalist foot.jsonc instead. Skipped if the caller already
# passed their own -c/--config.
function fastfetch --wraps fastfetch --description "fastfetch, foot-aware"
    if test "$TERM" = foot
        and not contains -- -c $argv
        and not contains -- --config $argv
        command fastfetch -c ~/.config/fastfetch/foot.jsonc $argv
    else
        command fastfetch $argv
    end
end
