function docker() {
  if [[ -z $DOCKER_API_VERSION && -S /var/run/docker.sock ]]; then
    export DOCKER_API_VERSION=$(curl -s -o /dev/null -w "%header{api-version}" --unix-socket /var/run/docker.sock http://d/_ping)
    [[ -n $DOCKER_API_VERSION ]] || unset DOCKER_API_VERSION
  fi
  command docker "$@"
}

function review() {
  local script=~/.local/share/review-tour/plain.sh
  [[ -x $script ]] || { echo "review: $script not found" >&2; return 1; }
  "$script" "${1:-.}" "${@:2}"
}
