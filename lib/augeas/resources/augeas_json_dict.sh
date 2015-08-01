# == Name
#
# augeas.json_dict
#
# === Description
#
# Manages a dictionary entry in a JSON file
#
# === Parameters
#
# * state: The state of the resource. Required. Default: present.
# * path: The path to the setting in the json tree for non-k/v settings.
# * key: The key portion of the dictionary. Required.
# * value: The value portion of the dictionary. Required.
# * type: The type of the value. Optional.
# * file: The file to add the variable to. Required.
#
# === Example
#
# ```shell
# augeas.json_dict --file /root/web.json --path / --key "foo" --value _dict
# augeas.json_dict --file /root/web.json --path / --key "foo" --value _array
# augeas.json_dict --file /root/web.json --path / --key "foo" --value "bar"
# ```
#
function augeas.json_dict {
  stdlib.subtitle "augeas.json_dict"

  if ! stdlib.command_exists augtool ; then
    stdlib.error "Cannot find augtool."
    if [[ -n "$WAFFLES_EXIT_ON_ERROR" ]]; then
      exit 1
    else
      return 1
    fi
  fi

  # Resource Options
  local -A options
  stdlib.options.create_option state "present"
  stdlib.options.create_option path
  stdlib.options.create_option key   "__required__"
  stdlib.options.create_option value "__required__"
  stdlib.options.create_option type
  stdlib.options.create_option file  "__required__"
  stdlib.options.parse_options "$@"

  # Local Variables
  local _path=$(echo "${options[file]}/${options[path]}/" | sed -e 's@/\+@/@g')
  local _name="${_path}${options[key]}"

  # Internal Resource Configuration
  # Determine the type of the value
  local _type
  if [[ -n ${options[type]} ]]; then
    _type="${options[type]}"
  elif [[ ${options[value]} =~ ^-?[0-9]+$ ]]; then
    _type="number"
  elif [[ ${options[value]} == "true" || ${options[value]} == "false" ]]; then
    _type="const"
  else
    _type="string"
  fi

  # Process the resource
  stdlib.resource.process "augeas.json_dict" "$_name"
}

function augeas.json_dict.read {
  local _result

  if [[ ! -f ${options[file]} ]]; then
    stdlib_current_state="absent"
    return
  fi

  # Check if the path exists
  stdlib_current_state=$(augeas.get --lens Json --file "${options[file]}" --path "${options[path]}")
  if [[ "$stdlib_current_state" == "absent" ]]; then
    return
  fi

  # Check if the key matches
  _result=$(augeas.get --lens Json --file "${options[file]}" --path "${options[path]}/dict/entry[. = '${options[key]}']")
  if [[ $_result == "absent" ]]; then
    stdlib_current_state="update"
    return
  fi

  # Check if the value matches
  case "${options[value]}" in
    _dict)
      _result=$(augeas.get --lens Json --file "${options[file]}" --path "${options[path]}/dict/entry[. = '${options[key]}']/dict")
      ;;
    _array)
      _result=$(augeas.get --lens Json --file "${options[file]}" --path "${options[path]}/dict/entry[. = '${options[key]}']/array")
      ;;
    *)
      _result=$(augeas.get --lens Json --file "${options[file]}" --path "${options[path]}/dict/entry[. = '${options[key]}']/${_type}[. = '${options[value]}']")
      ;;
  esac

  if [[ $_result == "absent" ]]; then
    stdlib_current_state="update"
    return
  fi

  stdlib_current_state="present"
}

function augeas.json_dict.create {
  local -a _augeas_commands=()
  if [[ ! -f ${options[file]} ]]; then
    stdlib.debug "Creating empty JSON file."
    stdlib.mute "echo '{}' > ${options[file]}"
    _augeas_commands+=("rm /files${options[file]}/dict")
  fi

  _augeas_commands+=("set /files${_path}dict/entry[. = '${options[key]}'] '${options[key]}'")

  case "${options[value]}" in
    _dict)
      _augeas_commands+=("touch /files${_path}dict/entry[. = '${options[key]}']/dict")
      ;;
    _array)
      _augeas_commands+=("touch /files${_path}dict/entry[. = '${options[key]}']/array")
      ;;
    *)
      _augeas_commands+=("set /files${_path}dict/entry[. = '${options[key]}']/${_type} '${options[value]}'")
      ;;
  esac

  local _result=$(augeas.run --lens Json --file "${options[file]}" "${_augeas_commands[@]}")

  if [[ $_result =~ ^error ]]; then
    stdlib.error "Error adding json ${options[name]} with augeas: $_result"
    return
  fi
}

function augeas.json_dict.update {
  augeas.json_dict.create
}

function augeas.json_dict.delete {
  local -a _augeas_commands=()
  _augeas_commands+=("rm /files${_path}dict/entry[. = '${options[key]}'")
  local _result=$(augeas.run --lens Json --file ${options[file]} "${_augeas_commands[@]}")

  if [[ $_result =~ ^error ]]; then
    stdlib.error "Error deleting json ${options[name]} with augeas: $_result"
    return
  fi
}