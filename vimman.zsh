# -----------------------------------------------------------------------------
#
#  vimman
#
#  View vim plugin manuals (help) like man in zsh
#
# -----------------------------------------------------------------------------
#
#  Version     : 0.1.0
#  Author      : Yonchu <yuyuchu3333@gmail.com>
#  License     : MIT License
#  Repository  : https://github.com/yonchu/vimman
#  Last Change : 19 Aug 2014.
#
#  Copyright (c) 2013 Yonchu.
#
# -----------------------------------------------------------------------------
#
# Usage:
#
#  $ vimman [-e] <help-file>
#
#  Options:
#    -e : Edit the vim plugin help (not use :help command)
#
# Settings:
#
#  - Custom plugin directories:
#      zstyle ':vimman:' dir ~/.vim/bundle ~/hoge
#
#  - Display verbose (print the path to the help file):
#      zstyle ':vimman:' verbose yes
#
#  - Cache expiration days (default: 7):
#      zstyle ':vimman:' expire 1
#
#
#  Note that if you change the zstyle settings,
#  you should delete the cache file and restart zsh.
#
#    $ rm ~/.zcompcache/vimman
#    $ exec zsh
#
# -----------------------------------------------------------------------------

case $- in
 *i*) ;;
   *)
       echo 'ERROR: vimman.zsh is meant to be sourced, not directly executed.' 1>&2
       exit 1
esac

function vimman() {
    typeset -aU help_dir
    local -a targets
    local param dir f
    local editor="$EDITOR"

    if [[ $# -lt 1 ]]; then
        echo 'ERROR: not enough arguments' 1>&2
        return 1
    fi

    if [[ ! ${(L)editor} =~ vim ]]; then
        editor=vim
    fi

    ## Open help file with :help command.
    if [[ $1 != '-e' ]]; then
        echo ":help $1"
        "$editor" -c ":help $1 | only"
        return 0
    fi

    ## Edit help file with editor.
    shift
    if [[ $# -lt 1 ]]; then
        echo 'ERROR: not enough arguments (-e)' 1>&2
        return 1
    fi

    # Target directories where search help file.
    zstyle -a ':vimman:' dir help_dir
    help_dir+=(~/.vim/doc(N-/))

    # Setup doc directories.
    targets=()
    for dir in "${help_dir[@]}"; do
        if [[ ! -d $dir ]]; then
            continue
        fi
        targets+=(${(f)"$(find -L "$dir" -type d -name '.neobundle' -prune -o -type f -name "$1" -print)"})
    done

    if [[ ${#targets} -eq 0 ]]; then
        echo "No manual entry for $1"
        return 1
    fi

    echo "${(j:\n:)${targets[@]/#$HOME/~}}"
    "$editor" "${targets[@]}"
}

function _vimman() {
    local curcontext="$curcontext" update_policy state update_msg

    # Setup cache-policy.
    zstyle -s ":completion:${curcontext}:" cache-policy update_policy
    if [[ -z $update_policy ]]; then
        zstyle ":completion:${curcontext}:" cache-policy _vimman_caching_policy
    fi

    # Retrieve cache.
    #   The cache file name: vimman
    #   The cache variable name: _vimman_help_files
    if ( ! (( $+_vimman_help_files )) \
        || _cache_invalid 'vimman' ) \
        && ! _retrieve_cache 'vimman'; then
        update_msg=' (cache updated)'
        _vimman_help_files=(${(f)"$(_vimman_get_help_files)"})
        _store_cache 'vimman' _vimman_help_files
    fi

    _arguments -C \
        '(-e)-e[edit vim plugin help command (:help xxxx)]' \
        '*: :->help_files' \
        && return

    case $state in
        help_files)
            _describe -t helpfile "help file$update_msg" _vimman_help_files || return 1
        ;;
    esac
    return 0
}

function _vimman_get_help_files() {
    typeset -aU help_dir
    local -a doc
    local -a help_files
    local dir files f
    local verbose

    # Target directories to search help file.
    zstyle -a ':vimman:' dir help_dir
    help_dir+=(~/.vim/doc(N-/))

    # Check verbose option.
    zstyle -b ':vimman:' verbose verbose

    # Setup doc directories.
    for dir in "${help_dir[@]}"; do
        if [[ ! -d $dir ]]; then
            continue
        fi
        doc+=(${(f)"$(find -L "$dir" -type d -name 'doc')"})
    done

    # Get help files.
    help_files=()
    for dir in "$doc[@]"; do
        if [[ $dir =~ '/\.neobundle/' ]]; then
            continue
        fi
        files=(${(f)"$(ls -1 "$dir")"})
        for f in "$files[@]"; do
            if [[ $f =~ '.*\.(txt|jax)' ]]; then
                if [[ $verbose == 'yes' ]]; then
                    dir="${${dir/#$HOME/\~}%/}"
                    help_files+=("$f:$dir")
                else
                    help_files+=("$f")
                fi
            fi
        done
    done
    echo "${(j:\n:)help_files}"
}

function _vimman_caching_policy() {
    # Returns status zero if the completions cache needs rebuilding.
    local -a oldp
    local expire
    zstyle -s ':vimman:' expire expire || expire=7
    # Rebuild if cache is more than $expire days.
    oldp=( "$1"(Nm+$expire) )
    (( $#oldp ))
}

compdef _vimman vimman
