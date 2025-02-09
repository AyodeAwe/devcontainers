#! /usr/bin/env bash

make_pip_env() {

    set -euo pipefail;

    local env_name="${1}";
    local env_file_name="${env_name}.requirements.txt";

    # Remove the current virtual env if called with `-f|--force`
    if echo "${@:2}" | grep -qE '(\-f|\-\-force)'; then
        rm -rf "$HOME/.local/share/venvs/${env_name}" \
               "$HOME/.local/share/venvs/${env_file_name}";
    fi

    local cuda_version="${CUDA_VERSION:-${CUDA_VERSION_MAJOR}.${CUDA_VERSION_MINOR}}";
    cuda_version="$(echo "${cuda_version}" | cut -d'.' -f3 --complement)";

    local python_version="${PYTHON_VERSION:-}";

    if [ -z "${python_version}" ]; then
        python_version="$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f3 --complement)";
    fi

    local new_env_path="$(realpath -m /tmp/${env_file_name})";
    local old_env_path="$(realpath -m ~/.local/share/venvs/${env_file_name})";

    local pip_noinstall=();
    local pip_reqs_txts=();

    for lib in $(yq eval '.repos[].name' /opt/rapids-build-utils/manifest.yaml); do
        pip_noinstall+=("lib${lib}" "${lib}");
    done

    for lib in $(find ~ -maxdepth 1 -mindepth 1 -type d ! -name '.*' -exec basename {} \;); do
        if [ -f ~/"${lib}/dependencies.yaml" ]; then
            pip_reqs_txts+=("/tmp/${lib}.requirements.txt");

            for pkg in $(rapids-python-pkg-names "${lib}"); do
                pip_noinstall+=("${pkg}" "${pkg}-cu.*");
            done

            pip_noinstall+=($(rapids-python-conda-pkg-names "${lib}"));

            rapids-dependency-file-generator \
                --file_key py_build_${lib}   \
                --file_key py_run_${lib}     \
                --file_key py_test_${lib}    \
                --file_key py_build          \
                --file_key py_run            \
                --file_key py_test           \
                --file_key all               \
                --output requirements        \
                --config ~/"${lib}/dependencies.yaml" \
                --matrix "arch=$(uname -m);cuda=${cuda_version};py=${python_version}" \
                `# --stdout` \
          | grep -v '^#' \
          | sed -E "s/-cu([0-9]+)/-cu${CUDA_VERSION_MAJOR}/g" \
            > /tmp/${lib}.requirements.txt;
        fi
    done

    # Generate a combined requirements.txt file
    cat ${pip_reqs_txts[@]} \
      | grep -v -P "^($(rapids-join-strings "|" ${pip_noinstall[@]}))==.*$" \
    > "${new_env_path}";

    rm ${pip_reqs_txts[@]};

    # If the venv doesn't exist, make one
    if [ ! -d ~/.local/share/venvs/${env_name} ]; then
        echo -e "Creating '${env_name}' virtual environment\n" 1>&2;
        echo -e "Requirements (${env_file_name}):\n" 1>&2;
        cat "${new_env_path}";
        echo "";

        python -m venv --system-site-packages ~/.local/share/venvs/${env_name};
        . ~/.local/share/venvs/${env_name}/bin/activate;
        python -m pip install --pre -I -r "${new_env_path}";
    # If the venv does exist but it's different from the generated one,
    # print the diff between the envs and update it
    elif ! diff -BNqw "${old_env_path}" "${new_env_path}" >/dev/null 2>&1; then
        echo -e "Updating '${env_name}' virtual environment\n" 1>&2;
        echo -e "Requirements (${env_file_name}):\n" 1>&2;

        # Print the diff to the console for debugging
        [ ! -f "${old_env_path}" ]                         \
         && cat "${new_env_path}"                          \
         || diff -BNyw "${old_env_path}" "${new_env_path}" \
         || true                                           \
         && echo "";

        # Update the current venv
        . ~/.local/share/venvs/${env_name}/bin/activate;
        python -m pip install --pre -U -r "${new_env_path}";
    fi

    cp -a "${new_env_path}" "${old_env_path}";
}

(make_pip_env "${DEFAULT_VIRTUAL_ENV:-rapids}" "$@");

. ~/.local/share/venvs/${DEFAULT_VIRTUAL_ENV:-rapids}/bin/activate;
