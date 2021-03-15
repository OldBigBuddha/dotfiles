### Powerlevel10k ###

# Custom Segments
prompt_lang_segment() {
    # Looks up the folder path + name
    dir="$( cd "$(dirname "$0")" ; pwd -P )"
    # Checks if it is the desired language/framework folder, in this case, python
    if [[ $dir == *"projects/python"* ]] ; then
        content="\uf81f Python%f"
        "$1_prompt_segment" "$0" "$2" "blue" "yellow" "$content" "#"
    fi
    if [[ $dir == *"projects/nodejs"* ]] ; then
        content="\ue781 NodeJS%f"
        "$1_prompt_segment" "$0" "$2" "yellow" "black" "$content" "#"
    fi
}

POWERLEVEL9K_MODE="nerdfont-complete"

POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX=""

# VIRTUAL_ENV_DISABLE_PROMPT=1

POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context ip dir dir_writable newline ssh root_indicator status)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(virtualenv vi_mode date newline background_jobs vcs time)

# [ -d /usr/local/share/powerlevel9k ] && source /usr/local/share/powerlevel9k/powerlevel9k.zsh-theme
[ -d /usr/local/share/powerlevel10k ] && source /usr/local/share/powerlevel10k/powerlevel10k.zsh-theme

