# dunenv shell hook - source it, do not execute it.
#
# 1) Defines the "dunenv" command as a bash function. Commands that must change
#    the current shell (setup, justin, the menu inside a container) make the
#    Python program write a bash script to a temporary file; the function
#    sources that file here and deletes it. Every other command just runs.
# 2) When "dunenv start" opens a container, bash reads this file as its
#    --rcfile and DUNENV_AUTORUN holds the setup script (base64): it is
#    decoded and run once, then the variable is removed.
#
# Optional, to have "dunenv" in every host shell, add to ~/.bash_profile:
#     source /nashome/j/jairorod/dunenv/dunenv.sh

DUNENV_HOME="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
export DUNENV_HOME

# Prompt like the host's, plus the running OS read from /etc/os-release:
#     [jairorod@dunegpvm01:AL9 jairorod]$   on the host       (AL9 in green)
#     [jairorod@dunegpvm01:SL7 jairorod]$   in the SL7 container (SL7 in green)
# The same function serves both: it reads whichever OS it runs on.
# Without /etc/os-release the tag is dropped: [user@host dir]$
_dunenv_prompt() {
    local tag
    tag="$( . /etc/os-release 2>/dev/null
            case "$ID" in
                scientific) s=sl ;;  almalinux) s=al ;;
                centos)     s=c  ;;  rhel)      s=el ;;
                *)          s=$ID ;;
            esac
            echo "${s}${VERSION_ID%%.*}" )"
    # Tag in uppercase and green (\[ \] keep the color codes out of the
    # line-length count, so long commands still wrap correctly).
    tag="${tag^^}"
    PS1="[\u@\h${tag:+:\[\e[1;32m\]$tag\[\e[0m\]} \W]\\$ "
}
# Apptainer does not set PS1 directly: it sets
#     PROMPT_COMMAND='PS1="Apptainer> "; unset PROMPT_COMMAND'
# which would overwrite the prompt above just before the first prompt is shown
# (and ~/.bash_profile appends it to its own PROMPT_COMMAND). Drop it here,
# before the profile is read.
if [[ "${PROMPT_COMMAND:-}" == *'PS1="'*'unset PROMPT_COMMAND'* ]]; then
    unset PROMPT_COMMAND
fi
_dunenv_prompt

dunenv() {
    local emit status
    emit="$(mktemp "${TMPDIR:-/tmp}/dunenv_XXXXXX.sh")" || return 1
    # -E -s: ignore PYTHONPATH/PYTHONHOME and user site packages set by UPS products
    DUNENV_EMIT="$emit" /usr/bin/python3 -E -s "$DUNENV_HOME/dunenv" "$@"
    status=$?
    if [[ -s "$emit" ]]; then
        source "$emit"
        status=$?
    fi
    rm -f "$emit"
    return "$status"
}

if [[ -n "${DUNENV_AUTORUN:-}" ]]; then
    _dunenv_autorun="$DUNENV_AUTORUN"
    unset DUNENV_AUTORUN
    eval "$(printf '%s' "$_dunenv_autorun" | base64 -d)"
    unset _dunenv_autorun
fi
