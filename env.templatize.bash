#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/include.bash"

# Templatize environment variables

templatizeVarPrefix=${TEMPLALIZE_VAR_PREFIX:-"___SHOULD_BE_FLASHED___"}

files=( "$@" );

if [[ ${#files[@]} -eq 0 ]]; then
  echo -e "File(s) required, cant continue";
  exit 1;
fi


while read -r line; do
  if [[ ${line} == *'='* ]] && [[ ${line} != '#'* ]]; then
    variable=$(echo "${line}" | awk -F "=" '{print $1}')
    declare "${variable}"="$(echo "${templatizeVarPrefix}${variable}" | tr '[:upper:]' '[:lower:]')"
    export "${variable?}"
  fi
done <<< "$(for file in "${files[@]}"; do cat "${file}"; done)"
