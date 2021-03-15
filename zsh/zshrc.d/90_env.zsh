### Env ###
# renv
if command -v rbenv 1>/dev/null 2>&1; then
    eval "$(rbenv init -)"
fi

# SDKMAN
export SDKMAN_DIR="/Users/developer/.sdkman"
[[ -s "/Users/developer/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/developer/.sdkman/bin/sdkman-init.sh"

# z
[ -d /usr/local/share/z ] && . /usr/local/share/z/z.sh

# MKL
[ -d /opt/intel/mkl/bin ] && source /opt/intel/mkl/bin/mklvars.sh intel64
