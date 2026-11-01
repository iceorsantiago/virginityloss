fish_add_path -g ~/.local/bin ~/.cargo/bin

if status is-interactive
    set -g fish_greeting ""

    alias pls sudo
    alias cat 'batcat --paging=never'
    if type -q eza
        alias ls 'eza --icons=auto --group-directories-first'
        alias ll 'eza -l --icons=auto --group-directories-first --header --git'
    end

    # Catppuccin Mocha para el resaltado de la línea de comandos
    set -g fish_color_command 89b4fa
    set -g fish_color_param cdd6f4
    set -g fish_color_quote a6e3a1
    set -g fish_color_error f38ba8
    set -g fish_color_autosuggestion 6c7086
    set -g fish_color_comment 6c7086
    set -g fish_color_operator f5c2e7
    set -g fish_color_redirection f5c2e7
    set -g fish_pager_color_prefix 89b4fa

    type -q starship; and starship init fish | source
    type -q zoxide; and zoxide init fish | source
    fzf --fish 2>/dev/null | source

    type -q fastfetch; and fastfetch
end
