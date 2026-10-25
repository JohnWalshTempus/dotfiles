function cm() {
    command claude --agent coordinator "$@"
}

function topic() {
    if [[ $# -eq 0 ]]; then
        echo "usage: topic <words describing the topic>"
        return 1
    fi
    local name="${(j:-:)@}"
    tmux new-window -d -n "$name" -c "$HOME" "${commands[claude]}" --agent coordinator \
        "Topic: $*. Run /bearings with it if an effort matches; otherwise create a new topic effort around it. Then wait for my first question."
}

function claude() {
    if [[ $# -eq 0 && "$PWD" == "$HOME" ]]; then
        local reply
        read -k 1 "reply?Coordinator (c) or other work (o)? [o] "
        echo
        if [[ "$reply" == [cC] ]]; then
            command claude --agent coordinator
            return
        fi
    fi
    command claude "$@"
}
