#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/include.bash"

# Flash env into files

templatizeVarPrefix=${TEMPLALIZE_VAR_PREFIX:-"___SHOULD_BE_FLASHED___"}

# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash/14203146#14203146
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--env)
      envFile="$2"
      shift # past argument
      shift # past value
      ;;
    -p|--path)
      filesPath="$2"
      shift # past argument
      shift # past value
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      echo "Unknown positional argument $1"
      exit 1
      ;;
  esac
done

if [[ ! ${envFile} ]]; then
  echo -e "env file required, use -e ENVFILEPATH or --env ENVFILEPATH";
  exit 1;
fi
if [[ ! ${filesPath} ]]; then
  echo -e "path of files to replace required, use -p PATH or --env PATH";
  exit 1;
fi


listOfVariablesArr=() # Define array

while read -r line; do
  if [[ ${line} == *'='* ]] && [[ ${line} != '#'* ]]; then
    variable=$(echo "${line}" | awk -F "=" '{print $1}')
    eval "${line}"; # Substitute value
    eval "export ${variable}"; # Make visible to envsubst
    # TODO Maybe need to check varibales, (remove after 2023/08/01)
    # TODO VALUE=${!VARIABLE:-? Required variable ${variable}}
    listOfVariablesArr+=("${variable}");
  fi
done <<< "$(cat "${envFile}")"

if [[ ${templatizeVarPrefix} ]]; then
  for variable in "${listOfVariablesArr[@]}"; do
    export "$(echo "${templatizeVarPrefix}${variable}" | tr '[:upper:]' '[:lower:]')"="${!variable}"
  done
fi

echo -e "Variables to replace:"
for variable in "${listOfVariablesArr[@]}"; do
    echo -e "$(echo "${templatizeVarPrefix}${variable}" | tr '[:upper:]' '[:lower:]')=${!variable}"
done

filesPath="$(realpath "${filesPath}")";

echo -e "Use path to find files: ${filesPath}";

echo -n "";

shopt -s globstar nullglob
filesFlashedCounter=0;

findFilesToFlashCommand="grep -rlsF";
flashEnvCommand="sed -i";
for variable in "${listOfVariablesArr[@]}"; do
  findFilesToFlashCommand="${findFilesToFlashCommand} -e \"$(echo "${templatizeVarPrefix}${variable}" | tr '[:upper:]' '[:lower:]')\""
  flashEnvCommand="${flashEnvCommand} -e \"s#$(echo "${templatizeVarPrefix}${variable}" | tr '[:upper:]' '[:lower:]')#${!variable}#g\""
done

while read -r file ; do
  # https://stackoverflow.com/questions/4665051/check-if-passed-argument-is-file-or-directory-in-bash/4665080#4665080
  if [[ -f $file ]]; then
    ((filesFlashedCounter+=1))
    echo "Flashing file #${filesFlashedCounter}: $file";
    eval "${flashEnvCommand} ${file}"
  fi
done <<< "$(eval "${findFilesToFlashCommand} ${filesPath}")"

echo -e "Flashed ${filesFlashedCounter} file(s)";
