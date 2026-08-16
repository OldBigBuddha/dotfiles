#!/usr/bin/env zsh
set -euo pipefail

install_zsh_plugin() {
    local name="$1"
    local repository="$2"
    local commit="$3"
    local plugin_root="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
    local plugin_dir="$plugin_root/$name"
    local current_origin

    mkdir -p "$plugin_root"

    if [[ -e "$plugin_dir" && ! -d "$plugin_dir/.git" ]]; then
        echo "❌ Cannot manage $plugin_dir because it is not a Git checkout." >&2
        exit 1
    fi

    if [[ ! -d "$plugin_dir/.git" ]]; then
        echo "📦 Installing zsh plugin: $name"
        git clone --quiet "$repository" "$plugin_dir"
    fi

    current_origin="$(git -C "$plugin_dir" remote get-url origin 2>/dev/null || true)"
    if [[ "$current_origin" != "$repository" ]]; then
        echo "❌ Unexpected origin for $plugin_dir: ${current_origin:-missing}" >&2
        echo "   Expected: $repository" >&2
        exit 1
    fi

    if [[ -n "$(git -C "$plugin_dir" status --porcelain)" ]]; then
        echo "❌ Refusing to update modified zsh plugin checkout: $plugin_dir" >&2
        exit 1
    fi

    if ! git -C "$plugin_dir" cat-file -e "${commit}^{commit}" 2>/dev/null; then
        git -C "$plugin_dir" fetch --quiet --depth 1 origin "$commit"
    fi
    git -C "$plugin_dir" checkout --quiet --detach "$commit"
}

install_zsh_plugin_entry() {
    local manifest="$1"
    local name="$2"
    local repository="$3"
    local commit="$4"

    if [[ -z "$name" || -z "$repository" || -z "$commit" ]]; then
        echo "❌ Each [[plugins]] entry in $manifest requires name, repository, and commit." >&2
        exit 1
    fi
    if [[ "$name" == *[^A-Za-z0-9._-]* ]]; then
        echo "❌ Invalid zsh plugin name in $manifest: $name" >&2
        exit 1
    fi
    if (( ${#commit} != 40 )) || [[ "$commit" == *[^0-9a-f]* ]]; then
        echo "❌ Invalid zsh plugin commit in $manifest: $commit" >&2
        exit 1
    fi

    install_zsh_plugin "$name" "$repository" "$commit"
}

install_zsh_plugins_from_manifest() {
    local manifest="$1"
    local line=""
    local line_number=0
    local in_plugin=0
    local plugin_count=0
    local name=""
    local repository=""
    local commit=""
    local key
    local value

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_number += 1))

        [[ -z "$line" || "$line" == \#* ]] && continue

        if [[ "$line" == '[[plugins]]' ]]; then
            if (( in_plugin )); then
                install_zsh_plugin_entry "$manifest" "$name" "$repository" "$commit"
                ((plugin_count += 1))
            fi
            in_plugin=1
            name=""
            repository=""
            commit=""
            continue
        fi

        if (( ! in_plugin )); then
            echo "❌ Invalid zsh plugin manifest entry at $manifest:$line_number" >&2
            exit 1
        fi

        case "$line" in
            'name = "'*'"')
                key="name"
                value="${line#*\"}"
                value="${value%\"}"
                ;;
            'repository = "'*'"')
                key="repository"
                value="${line#*\"}"
                value="${value%\"}"
                ;;
            'commit = "'*'"')
                key="commit"
                value="${line#*\"}"
                value="${value%\"}"
                ;;
            *)
                echo "❌ Unsupported zsh plugin manifest syntax at $manifest:$line_number" >&2
                exit 1
                ;;
        esac

        case "$key" in
            name)
                [[ -z "$name" ]] || {
                    echo "❌ Duplicate name at $manifest:$line_number" >&2
                    exit 1
                }
                name="$value"
                ;;
            repository)
                [[ -z "$repository" ]] || {
                    echo "❌ Duplicate repository at $manifest:$line_number" >&2
                    exit 1
                }
                repository="$value"
                ;;
            commit)
                [[ -z "$commit" ]] || {
                    echo "❌ Duplicate commit at $manifest:$line_number" >&2
                    exit 1
                }
                commit="$value"
                ;;
        esac
    done < "$manifest"

    if (( in_plugin )); then
        install_zsh_plugin_entry "$manifest" "$name" "$repository" "$commit"
        ((plugin_count += 1))
    fi

    if (( plugin_count == 0 )); then
        echo "❌ No plugins are defined in $manifest." >&2
        exit 1
    fi
}

if (( $# != 1 )); then
    echo "Usage: $0 <plugins.toml>" >&2
    exit 2
fi
if ! command -v git >/dev/null 2>&1; then
    echo "❌ Git is required to install zsh plugins." >&2
    exit 1
fi
if [[ ! -r "$1" ]]; then
    echo "❌ Zsh plugin manifest is not readable: $1" >&2
    exit 1
fi

install_zsh_plugins_from_manifest "$1"
