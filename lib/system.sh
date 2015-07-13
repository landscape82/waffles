# Some global variable declarations

## stdlib_current_state holds the state of the last run command
declare -g stdlib_current_state

## stdlib_change reports if changes were made in the current title
declare -g stdlib_state_change
declare -g stdlib_resource_change

## stdlib_resource_changes keeps track of how many changes were made
declare -g stdlib_resource_changes=0

## stdlib_remote_copy is a list of data and profiles that need copied to a remote node
declare -Ag stdlib_remote_copy


# Colors
declare stdlib_color_blue='\e[0;34m'
declare stdlib_color_green='\e[1;32m'
declare stdlib_color_red='\e[0;31m'
declare stdlib_color_yellow='\e[1;33m'
declare stdlib_color_reset='\e[0m'

# These functions print colored lines
function stdlib.debug {
  if stdlib.debug? ; then
    echo -e "${stdlib_color_blue} ===> (debug) ${stdlib_title} ${stdlib_subtitle}${stdlib_color_reset} ${@}" >&2
  fi
}

function stdlib.info {
  echo -e "${stdlib_color_green} ===> (info)  ${stdlib_title} ${stdlib_subtitle}${stdlib_color_reset} ${@}"
}

function stdlib.warn {
  echo -e "${stdlib_color_yellow} ===> (warn)  ${stdlib_title} ${stdlib_subtitle}${stdlib_color_reset} ${@}"
}

function stdlib.error {
  echo -e "${stdlib_color_red} ===> (error) ${stdlib_title} ${stdlib_subtitle}${stdlib_color_reset} ${@}" >&2
}


# These commands are simple helpers to detect how Waffles was run.
function stdlib.noop? {
  [[ -n "$WAFFLES_NOOP" ]]
}

function stdlib.debug? {
  [[ -n "$WAFFLES_DEBUG" ]]
}


# stdlib.title is a section/subsection currently being run
function stdlib.title {
  stdlib_title=""
  stdlib_title="$@"
  stdlib_state_change="false"
  stdlib_resource_change="false"
}

function stdlib.subtitle {
  stdlib_subtitle=""
  stdlib_subtitle="$@"
  stdlib_resource_change="false"
}


# stdlib.mute turns off command output
# and prints the command being run.
function stdlib.mute {
  if stdlib.noop? ; then
    stdlib.info "(noop) $@"
  else
    stdlib.info "Running \"$@\""
    eval $@ &>/dev/null
    return $?
  fi
}

# stdlib.debug_mute turns off command output
# and prints the command being run at debug level
function stdlib.debug_mute {
  if stdlib.noop? ; then
    stdlib.debug "(noop) $@"
  else
    stdlib.debug "Running \"$@\""
    eval $@ &>/dev/null
    return $?
  fi
}


# stdlib.exec just runs the command
function stdlib.exec {
  if stdlib.noop? ; then
    stdlib.info "(noop) $@"
  else
    stdlib.info "Running \"$@\""
    eval $@
    return $?
  fi
}


# stdlib.capture_error will report back anything on fd 2.
# unfortunately a lot of noise usually ends up on fd 2,
# so this could be a little buggy.
function stdlib.capture_error {
  if stdlib.noop? ; then
    stdlib.info "(noop) $@"
  else
    local _err
    stdlib.info "Running \"$@\""
    _err=$(eval "$@" 2>&1 >/dev/null)
    if [[ $? != 0 ]]; then
      stdlib.error "Errors occurred:"
      stdlib.error "$_err"
      if [[ "$WAFFLES_EXIT_ON_ERROR" == true ]]; then
        stdlib.error "Halting run."
        exit 1
      fi
    fi
  fi
}


# stdlib.dir is a clean way of getting the current dir of the script being run.
function stdlib.dir {
  if [[ $# -gt 0 ]]; then
    echo $(readlink -f "${1%/*}")
  fi
}


# stdlib.include is a more intelligent "source".
# It will warn if the file does not exist, rather than erroring.
function stdlib.include {
  if [[ $# -gt 0 ]]; then
    if [[ -f "$1" ]]; then
      source -- "$1"
    else
      stdlib.warn "File not found: $1"
    fi
  fi
}


# stdlib.profile is a shortcut to run scripts in "$WAFFLES_SITE_DIR/profiles"
# If running in REMOTE mode, a list of profiles to copy is built
function stdlib.profile {
  if [[ $# -gt 0 ]]; then
    local _script_path
    local _profile
    if [[ "$1" =~ [/] ]]; then
      stdlib.split $1 '/'
      _profile="${__split[0]}"
      local _file="${__split[1]}"
      _script_path="$WAFFLES_SITE_DIR/profiles/$_profile/scripts/$_file.sh"
    else
      _profile="$1"
      if [[ -f "$WAFFLES_SITE_DIR/profiles/$_profile/scripts/init.sh" ]]; then
        _script_path="$WAFFLES_SITE_DIR/profiles/$_profile/scripts/init.sh"
      fi
    fi

    if [[ -n "$_profile" && -n "$_script_path" ]]; then
      if [[ -n "$WAFFLES_REMOTE" ]]; then
        stdlib_remote_copy["profiles/$_profile"]=1
      else
        stdlib.include "$_script_path"
      fi
    else
      stdlib.warn "Profile not found: $1"
    fi

  fi
}

# stdlib.data is a shortcut to source data in "$WAFFLES_SITE_DIR/data"
function stdlib.data {
  if [[ $# -gt 0 ]]; then
    local _script_path
    local _data
    if [[ "$1" =~ [/] ]]; then
      stdlib.split $1 '/'
      _data="${__split[0]}"
      local _file="${__split[1]}"
      _script_path="$WAFFLES_SITE_DIR/data/$data/$_file.sh"
    else
      if [[ -f "$WAFFLES_SITE_DIR/data/${1}.sh" ]]; then
        _data="data/${1}.sh"
        _script_path="$WAFFLES_SITE_DIR/data/${1}.sh"
      elif [[ -f "$WAFFLES_SITE_DIR/data/${1}/init.sh" ]]; then
        _data="data/${1}"
        _script_path="$WAFFLES_SITE_DIR/data/${1}/init.sh"
      fi
    fi

    if [[ -n "$_data" && -n "$_script_path" ]]; then
      if [[ -n "$WAFFLES_REMOTE" ]]; then
        stdlib_remote_copy[$_data]=1
      else
        stdlib.include "$_script_path"
      fi
    else
      stdlib.warn "Data not found: $1"
    fi

  fi
}


# stdlib.command_exists is a simple alias for `which`
function stdlib.command_exists {
  which $1 &>/dev/null
}


# String functions

# stdlib.split splits a string
# $1 = string
# $2 = delimiter
declare -ax __split
function stdlib.split {
  if [[ -z "$2" ]]; then
    echo "$1"
  fi

  __split=()
  local _string="$1"
  local _delim="$2"

  while [[ "$_string" != "" ]]; do
    __split+=("${_string%%$_delim*}")
    _string="${_string#*$_delim}"
    if [[ "${__split[-1]}" == $_string ]]; then
      break
    fi
  done
}


# stdlib.trim trims whitespace from a string
# $1 = string
function stdlib.trim {
  if [[ $# -gt 0 ]]; then
    shopt -s extglob
    local _trim="$1"
    _trim="${_trim##*( )}"
    _trim="${_trim%%*( )}"
    shopt -u extglob
    echo "$_trim"
  else
    echo ""
  fi
}


# Array functions

# stdlib.array_length returns the length of an array
# $1 = array
function stdlib.array_length {
  local _arr="$1"
  if [[ -n "$_arr" ]]; then
    eval "echo \${#$_arr[@]}"
  fi
}

# stdlib.array_push adds elements to the end of an array
# $1 = array
# $2+ = elements to push
function stdlib.array_push {
  local _arr="$1"
  shift

  if [[ -n "$_arr" ]]; then
    eval "$_arr=(\"\${$_arr[@]}\" \"\$@\")"
  fi
}

# stdlib.array_pop pops the last element from an array
# $1 = array
function stdlib.array_pop {
  local _arr="$1"
  local _arr_length=$(stdlib.array_length $_arr)
  local _arr_element
  local _pop

  if [[ -n "$_arr" ]] && (( $_arr_length >= 1 )); then
    _arr_element=$(( $_arr_length - 1 ))
    eval "_pop=\"\$(echo \"\${$_arr[$_arr_element]}\")\""
    eval "unset $_arr[$_arr_element]"

    echo "$_pop"
  fi
}

# stdlib.array_shift pops the first element from an array
# $1 = array
function stdlib.array_shift {
  local _arr="$1"
  local _arr_length=$(stdlib.array_length $_arr)
  local _pop

  if [[ -n "$_arr" ]] && (( $_arr_length >= 1 )); then
    eval "_pop=\"\$(echo \"\${$_arr[0]}\")\""
    eval "unset $_arr[0]"
    eval "$_arr=(\"\${$_arr[@]}\")"

    echo "$_pop"
  fi
}

# stdlib.array_unshift adds elements to the beginning of an array
# $1 = array
# $2+ = elements
function stdlib.array_unshift {
  local _arr="$1"
  shift

  if [[ -n "$_arr" ]]; then
    while [[ $# -gt 0 ]]; do
      eval "$_arr=(\"\$1\" \"\${$_arr[@]}\")"
      shift
    done
  fi
}

# stdlib.array_join joins an array into a string
# $1 = array
# $2 = delimiter
function stdlib.array_join {
  if [[ $# -eq 2 ]]; then
    local _arr="$1"
    local _delim="$2"
    local _arr_length
    local _string _pop

    _arr_length=$(stdlib.array_length $_arr)
    while [[ "$_arr_length" -gt 0 ]]; do
      eval "_pop=\"\$(echo \"\${$_arr[0]}\")\""
      eval "unset $_arr[0]"
      eval "$_arr=(\"\${$_arr[@]}\")"

      if [[ -z "$_string" ]]; then
        _string="${_pop}"
      else
        _string="${_string}${_delim}${_pop}"
      fi
      _arr_length=$(stdlib.array_length $_arr)
    done

    echo "$_string"
  fi
}