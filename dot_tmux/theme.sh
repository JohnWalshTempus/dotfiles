tm_icon="♟"
tm_color_active=colour213
tm_color_inactive=colour241
tm_color_blue=colour4
tm_color_red=colour203

set -g status-left-length 32
set -g status-right-length 150
set -g status-interval 5

set-option -g status-style fg=$tm_color_active
set-window-option -g window-status-style fg=$tm_color_inactive
set -g window-status-format "#I #W"
set-window-option -g window-status-current-style fg=$tm_color_active
set-window-option -g  window-status-current-format "#[bold]#I #W"
set-option -g pane-border-style fg=$tm_color_inactive
set-option -g pane-active-border-style fg=$tm_color_active
set-option -g message-style fg=$tm_color_active
set-option -g display-panes-active-colour $tm_color_active
set-option -g display-panes-colour $tm_color_inactive
set-window-option -g clock-mode-colour $tm_color_active

battery_percent="#(~/.tmux/bin/bash/battery_indicator.sh)"
tm_date="#[fg=$tm_color_red] %a %h-%d %H:%M"
tm_session_name="#[fg=$tm_color_blue,bold]$tm_icon #S"

set -g status-left $tm_session_name' '
set -g status-right $tm_date' '$battery_percent' '
