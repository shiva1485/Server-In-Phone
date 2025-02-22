#!/data/data/com.termux/files/usr/bin/bash

#########################################################################
#
# Call First
#
#########################################################################
R="$(printf '\033[1;31m')"
G="$(printf '\033[1;32m')"
Y="$(printf '\033[1;33m')"
B="$(printf '\033[1;34m')"
C="$(printf '\033[1;36m')"
W="$(printf '\033[0m')"
BOLD="$(printf '\033[1m')"

cd "$HOME" || exit
termux_desktop_path="/data/data/com.termux/files/usr/etc/termux-desktop"
config_file="$termux_desktop_path/configuration.conf"
log_file="/data/data/com.termux/files/home/termux-desktop.log"

read -p "what's your device gpu model: " device_gpu_model

# create log
function debug() {
	exec > >(tee -a "$log_file") 2>&1
}

function banner() {
clear
printf "%s############################################################\n" "$C"
printf "%s#                                                          #\n" "$C"
printf "%s#  ▀█▀ █▀▀ █▀█ █▀▄▀█ █ █ ▀▄▀   █▀▄ █▀▀ █▀ █▄▀ ▀█▀ █▀█ █▀█  #\n" "$C"
printf "%s#   █  ██▄ █▀▄ █   █ █▄█ █ █   █▄▀ ██▄ ▄█ █ █  █  █▄█ █▀▀  #\n" "$C"
printf "%s#                                                          #\n" "$C"
printf "%s######################### Termux Gui #######################%s\n" "$C" "$W"

echo " "
}

# check if the script is running on termux or not
function check_termux() {
	if [[ $HOME != *termux* ]]; then
	echo "${R}[${R}☓${R}]${R}${BOLD}Please run it inside termux${W}"
	exit 0
	fi
}

#########################################################################
#
# Shortcut Functions
#
#########################################################################

function print_log() {
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_level="${2:-INFO}"  # Default log level is INFO if not specified
    local message="$1"
    
    echo "[${timestamp}] ${log_level}: ${message}" >> "$log_file"
}

function log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$1"
    echo "[${timestamp}] INFO: ${message}" >> "$log_file"
}

function log_warn() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$1"
    echo "[${timestamp}] WARN: ${message}" >> "$log_file"
}

function log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$1"
    echo "[${timestamp}] ERROR: ${message}" >> "$log_file"
}

function log_debug() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$1"
    echo "[${timestamp}] DEBUG: ${message}" >> "$log_file"
}

function print_success() {
	local msg
	msg="$1"
	echo "${R}[${G}✓${R}]${G} $msg${W}"
	print_log "$msg"
}

function print_failed() {
	local msg
	msg="$1"
	echo "${R}[${R}☓${R}]${R} $msg${W}"
	print_log "$msg"
}

function print_warn() {
	local msg
	msg="$1"
	echo "${R}[${Y}!${R}]${Y} $msg${W}"
	print_log "$msg"
}

function wait_for_keypress() {
	read -n1 -s -r -p "${R}[${C}-${R}]${G} Press any key to continue, CTRL+c to cancle...${W}"
	echo
}

function check_and_create_directory() {
    if [[ ! -d "$1" ]]; then
        mkdir -p "$1"
		print_log "$1"
    fi
}

# first check then delete
function check_and_delete() {
    local file
	local files_folders
    for files_folders in "$@"; do
        for file in $files_folders; do
            if [[ -e "$file" ]]; then
                if [[ -d "$file" ]]; then
                    rm -rf "$file" >/dev/null 2>&1
                elif [[ -f "$file" ]]; then
                    rm "$file" >/dev/null 2>&1
                fi
            fi
		print_log "$file"
        done
    done
}

# first check then backup
function check_and_backup() {
	local file
	local files_folders
    for files_folders in "$@"; do
        for file in $files_folders; do
            if [[ -e "$file" ]]; then
            local date_str
			date_str=$(date +"%d-%m-%Y")
			local backup="${file}-${date_str}.bak"
			    if [[ -e "$backup" ]]; then
				echo "${R}[${C}-${R}]${G}Backup file ${C}${backup} ${G}already exists${W}"
				echo
				fi
		    echo "${R}[${C}-${R}]${G}backing up file ${C}$file${W}"
			mv "$1" "$backup"
			print_log "$1 $backup"
            fi
        done
    done
}

function download_file() {
    local dest
    local url
    dest="$1"
    url="$2"
	print_log "$dest"
	print_log "$url"
    if [[ -z "$dest" ]]; then
        wget --tries=5 --timeout=15 --retry-connrefused "$url"
    else
        wget --tries=5 --timeout=15 --retry-connrefused -O "$dest" "$url"
    fi

    # Check if the file was downloaded successfully
    if [[ -f "$dest" || -f "$(basename "$url")" ]]; then
        print_success "Successfully downloaded the file"
    else
        print_failed "Failed to download the file, retrying..."
        if [[ -z "$dest" ]]; then
            wget --tries=5 --timeout=15 --retry-connrefused "$url"
        else
            wget --tries=5 --timeout=15 --retry-connrefused -O "$dest" "$url"
        fi

        # Final check
        if [[ -f "$dest" || -f "$(basename "$url")" ]]; then
            print_success "Successfully downloaded the file after retry"
        else
            print_failed "Failed to download the file after retry"
            exit 0
        fi
    fi
}

# find a backup file which end with a number pattern and restore it
function check_and_restore() {
    local target_path="$1"
    local dir
    local base_name

    dir=$(dirname "$target_path")
    base_name=$(basename "$target_path")

    local latest_backup
   latest_backup=$(find "$dir" -maxdepth 1 -type f -name "$base_name-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9].bak" 2>/dev/null | sort | tail -n 1)

    if [[ -z "$latest_backup" ]]; then
        print_failed "No backup file found for ${target_path}."
		echo
        return 1
    fi

    if [[ -e "$target_path" ]]; then
        print_failed "${C}Original file or directory ${target_path} already exists.${W}"
		echo
    else
        mv "$latest_backup" "$target_path"
        print_success "Restored ${latest_backup} to ${target_path}"
		echo
    fi
	print_log "$target_path $dir $base_name $latest_backup"
}

function detact_package_manager() {
	source "/data/data/com.termux/files/usr/bin/termux-setup-package-manager"
	if [[ "$TERMUX_APP_PACKAGE_MANAGER" == "apt" ]]; then
	PACKAGE_MANAGER="apt"
	elif [[ "$TERMUX_APP_PACKAGE_MANAGER" == "pacman" ]]; then
	PACKAGE_MANAGER="pacman"
	else
	print_failed "${C} Could not detact your package manager, Switching To ${C}pkg ${W}" 
	fi
	print_log "$PACKAGE_MANAGER"
}

# will check if the package is already installed or not, if it installed then it will reinstall it and at the end it will print success/failed message
function package_install_and_check() {
    print_log "Starting package installation for: $*" "INFO"
    
    packs_list=($@)
    for package_name in "${packs_list[@]}"; do
        print_log "Processing package: $package_name" "DEBUG"
        
        echo "${R}[${C}-${R}]${G}${BOLD} Processing package: ${C}$package_name ${W}"

        if [[ "$PACKAGE_MANAGER" == "pacman" ]]; then
            if pacman -Qi "$package_name" >/dev/null 2>&1; then
                print_log "Package already installed: $package_name" "INFO"
                continue
            fi
            
            if [[ $package_name == *"*"* ]]; then
                print_log "Processing wildcard pattern: $package_name" "DEBUG"
                echo "${R}[${C}-${R}]${C} Processing wildcard pattern: $package_name ${W}"
                packages=$(pacman -Ssq "${package_name%*}" 2>/dev/null)
                for pkgs in $packages; do
                    echo "${R}[${C}-${R}]${G}${BOLD} Installing matched package: ${C}$pkgs ${W}"
                    pacman -Sy --noconfirm --overwrite '*' "$pkgs"
                    if [ $? -eq 0 ]; then
                        print_log "Successfully installed package: $pkgs" "INFO"
                    else
                        print_log "Failed to install package: $pkgs" "ERROR"
                    fi
                done
            else
                pacman -Sy --noconfirm --overwrite '*' "$package_name"
                if [ $? -eq 0 ]; then
                    print_log "Successfully installed package: $package_name" "INFO"
                else
                    print_log "Failed to install package: $package_name" "ERROR"
                fi
            fi
        else
            if [[ $package_name == *"*"* ]]; then
                log_debug "Processing wildcard pattern" "Pattern: $package_name"
                echo "${R}[${C}-${R}]${C} Processing wildcard pattern: $package_name ${W}"
                packages_by_name=$(apt-cache search "${package_name%*}" | awk "/^${package_name}/ {print \$1}")
                packages_by_description=$(apt-cache search "${package_name%*}" | grep -Ei "\b${package_name%*}\b" | awk '{print $1}')
                packages=$(echo -e "${packages_by_name}\n${packages_by_description}" | sort -u)
                for pkgs in $packages; do
                    echo "${R}[${C}-${R}]${G}${BOLD} Installing matched package: ${C}$pkgs ${W}"
                    if dpkg -s "$pkgs" >/dev/null 2>&1; then
                        log_info "Package already installed" "Package: $pkgs"
                        pkg reinstall "$pkgs" -y
                    else
                        pkg install "$pkgs" -y
                    fi
                done
            else
                if dpkg -s "$package_name" >/dev/null 2>&1; then
                    log_info "Package already installed" "Package: $package_name"
                    pkg reinstall "$package_name" -y
                else
                    pkg install "$package_name" -y
                fi
            fi
        fi

        # Check installation success
        if [ $? -ne 0 ]; then
            log_error "Installation failed" "Package: $package_name" "Exit code: $?"
        else
            log_info "Installation successful" "Package: $package_name"
        fi
    done
    
    print_log "Package installation completed for: ${packs_list[*]}" "INFO"
}

# will check the package is installed or not then remove it
function package_check_and_remove() {
    packs_list=($@)
    for package_name in "${packs_list[@]}"; do
        echo "${R}[${C}-${R}]${G}${BOLD} Processing package: ${C}$package_name ${W}"

        if [[ $package_name == *"*"* ]]; then
            echo "${R}[${C}-${R}]${C} Processing wildcard pattern: $package_name ${W}"
			print_log "Processing wildcard pattern: $package_name"
            if [[ "$PACKAGE_MANAGER" == "pacman" ]]; then
                packages=$(pacman -Qq | grep -E "${package_name//\*/.*}")
            else
                packages=$(dpkg --get-selections | awk '{print $1}' | grep -E "${package_name//\*/.*}")
            fi

            for pkg in $packages; do
                echo "${R}[${C}-${R}]${G}${BOLD} Removing matched package: ${C}$pkg ${W}"
                if [[ "$PACKAGE_MANAGER" == "pacman" ]]; then
                    if pacman -Qi "$pkg" >/dev/null 2>&1; then
                        pacman -Rnds --noconfirm "$pkg"
                        if [ $? -eq 0 ]; then
                            print_success "$pkg removed successfully"
							print_log "Processing wildcard pattern: $package_name"
                        else
                            print_failed "Failed to remove $pkg ${W}"
                        fi
                    fi
                else
                    if dpkg -s "$pkg" >/dev/null 2>&1; then
                        apt autoremove "$pkg" -y
                        if [ $? -eq 0 ]; then
                            print_success "$pkg removed successfully"
                        else
                            print_failed "Failed to remove $pkg ${W}"
                        fi
                    fi
                fi
            done
        else
            if [[ "$PACKAGE_MANAGER" == "pacman" ]]; then
                if pacman -Qi "$package_name" >/dev/null 2>&1; then
                    echo "${R}[${C}-${R}]${G}${BOLD} Removing package: ${C}$package_name ${W}"
                    pacman -Rnds --noconfirm "$package_name"
                    if [ $? -eq 0 ]; then
                        print_success "$package_name removed successfully"
                    else
                        print_failed "Failed to remove $package_name ${W}"
                    fi
                fi
            else
                if dpkg -s "$package_name" >/dev/null 2>&1; then
                    echo "${R}[${C}-${R}]${G}${BOLD} Removing package: ${C}$package_name ${W}"
                    apt autoremove "$package_name" -y
                    if [ $? -eq 0 ]; then
                        print_success "$package_name removed successfully"
                    else
                        print_failed "Failed to remove $package_name ${W}"
                    fi
                fi
            fi
        fi
    done
    echo ""
	print_log "$package_name"
}

function get_file_name_number() {
    current_file=$(basename "$0")
    folder_name="${current_file%.sh}"
    theme_number=$(echo "$folder_name" | grep -oE '[1-9][0-9]*')
	print_log "$theme_number"
}

function extract_zip_with_progress() {
    local archive="$1"
    local target_dir="$2"

    # Check if the archive file exists
    if [[ ! -f "$archive" ]]; then
        print_failed "$archive doesn't exist"
        return 1
    fi

    local total_files
    total_files=$(unzip -l "$archive" | grep -c -E '^\s+[0-9]+')

    if [[ "$total_files" -eq 0 ]]; then
        print_failed "No files found in the archive"
        return 1
    fi

    echo "Total files to extract: $total_files"
    local extracted_files=0
    unzip -o "$archive" -d "$target_dir" | while read -r line; do
        if [[ "$line" =~ inflating: ]]; then
            ((extracted_files++))
            progress=$((extracted_files * 100 / total_files))
            echo -ne "${G}Extracting: ${C}$progress% ($extracted_files/$total_files) \r${W}"
        fi
    done
    print_success "${archive} Extraction complete!"
}

function extract_archive() {
    local archive="$1"
    if [[ ! -f "$archive" ]]; then
        print_failed "$archive doesn't exist"
        return 1
    fi

    local total_size
    total_size=$(stat -c '%s' "$archive")

    case "$archive" in
        *.tar.gz|*.tgz)
            print_success "Extracting ${C}$archive"
            pv -s "$total_size" -p -r "$archive" | tar xzf - || { print_failed "Failed to extract ${C}$archive"; return 1; }
            ;;
        *.tar.xz)
            print_success "Extracting ${C}$archive"
            pv -s "$total_size" -p -r "$archive" | tar xJf - || { print_failed "Failed to extract ${C}$archive"; return 1; }
            ;;
        *.tar.bz2|*.tbz2)
            print_success "Extracting ${C}$archive"
            pv -s "$total_size" -p -r "$archive" | tar xjf - || { print_failed "Failed to extract ${C}$archive"; return 1; }
            ;;
        *.tar)
            print_success "Extracting ${C}$archive"
            pv -s "$total_size" -p -r "$archive" | tar xf - || { print_failed "Failed to extract ${C}$archive"; return 1; }
            ;;
        *.bz2)
            print_success "Extracting ${C}$archive"
            pv -s "$total_size" -p -r "$archive" | bunzip2 > "${archive%.bz2}" || { print_failed "Failed to extract ${C}$archive"; return 1; }
            ;;
        *.gz)
            print_success "Extracting ${C}$archive${W}"
            pv -s "$total_size" -p -r "$archive" | gunzip > "${archive%.gz}" || { print_failed "Failed to extract ${C}$archive"; return 1; }
            ;;
        *.7z)
            print_success "Extracting ${C}$archive"
            pv -s "$total_size" -p -r "$archive" | 7z x -si -y > /dev/null || { print_failed "Failed to extract ${C}$archive"; return 1; }
            ;;
		*.zip)
            extract_zip_with_progress "${archive}"
            ;;
        *.rar)
            print_success "Extracting ${C}$archive"
            unrar x "$archive" || { print_failed "Failed to extract ${C}$archive"; return 1; }
            ;;
        *)
            print_failed "Unsupported archive format: ${C}$archive"
            return 1
            ;;
    esac

    print_success "Successfully extracted ${C}$archive"
	print_log "$archive"
}

# download a archive file and extract it in a folder
function download_and_extract() {
    local url="$1"
    local target_dir="$2"
    local filename="${url##*/}"

    # Notify user about downloading
    echo "${R}[${C}-${R}]${C}${BOLD}Downloading ${G}${filename}...${W}"
    sleep 1.5

    # Change to the target directory
    cd "$target_dir" || return 1

    local attempt=1
    local success=false

    # Attempt to download the file with retries
    while [[ $attempt -le 3 ]]; do
        if curl -# -L "$url" -o "$filename"; then
            success=true
            break
        else
            print_failed "Failed to download ${C}${filename}"
            echo "${R}[${C}☓-{R}]${G}Retrying... Attempt ${C}$attempt${W}"
            ((attempt++))
            sleep 1
        fi
    done

    # If download is successful, extract and remove the archive
    if [[ "$success" = true ]]; then
        if [[ -f "$filename" ]]; then
            echo
            echo "${R}[${C}-${R}]${R}[${C}-${R}]${G} Extracting $filename${W}"
            extract_archive "$filename"
            rm "$filename"
        fi
    else
        # Notify if download fails after all attempts
        print_failed "Failed to download ${C}${filename}"
        echo "${R}[${C}-${R}]${C}Please check your internet connection${W}"
    fi
	print_log "$url $target_dir $filename"
}

# count the number subfolders inside a folder in my repo
function count_subfolders() {
    local owner="$1"
    local repo="$2"
    local path="$3"
    local branch="$4"
    
    # GitHub API URL with branch reference
    local url="https://api.github.com/repos/$owner/$repo/contents/$path?ref=$branch"
    
    # Get the response from the GitHub API
    local response
    response=$(curl -s "$url")
    
    # Check for API errors (e.g., rate limiting or wrong path)
    if echo "$response" | jq -e 'has("message")' >/dev/null; then
        echo "Error: $(echo "$response" | jq -r '.message')"
        return 1
    fi
    
    # Extract and count directoriest
    subfolder_count=$(echo "$response" | jq -r '.[] | select(.type == "dir") | .name' | wc -l)

    # Default to 0 if no subfolders are found
    if [[ -z "$subfolder_count" || "$subfolder_count" -eq 0 ]]; then
        subfolder_count=0
    fi

    echo "$subfolder_count"
}

# create a yes / no confirmation prompt
function confirmation_y_or_n() {
	 while true; do
        read -r -p "${R}[${C}-${R}]${Y}${BOLD} $1 ${Y}(y/n) ${W}" response
        response="${response:-y}"
        eval "$2='$response'"
        case $response in
            [yY]* )
				echo
                print_success "Continuing with answer: $response"
				echo
				sleep 0.2
                break;;
            [nN]* )
				echo
                echo "${R}[${C}-${R}]${C} Skipping this step${W}"
				echo
				sleep 0.2
                break;;
            * )
				echo
               	print_failed " Invalid input. Please enter 'y' or 'n'."
				echo
                ;;
        esac
    done
	print_log "$1 $response"
}

# get the latest version from a github releases
# ex. latest_tag=$(get_latest_release "$repo_owner" "$repo_name")
function get_latest_release() {
	local repo_owner="$1"
	local repo_name="$2"
	curl -s "https://api.github.com/repos/$repo_owner/$repo_name/releases/latest" |
	grep '"tag_name":' |
	sed -E 's/.*"v?([^"]+)".*/\1/'
}

function install_font_for_style() {
	local style_number="$1"
	echo "${R}[${C}-${R}]${G} Installing Fonts...${W}"
	check_and_create_directory "$HOME/.fonts"
	download_and_extract "https://raw.githubusercontent.com/sabamdarif/termux-desktop/refs/heads/setup-files/setup-files/$de_name/look_${style_number}/font.tar.gz" "$HOME/.fonts"
	fc-cache -f
	cd "$HOME" || return
}

function print_status() {
    local status
	status=$1
    local message
	message=$2
    if [[ "$status" == "ok" ]]; then
        print_success "$message"
    elif [[ "$status" == "warn" ]]; then
        print_warn "$message"
    elif [[ "$status" == "error" ]]; then
        print_failed "$message"
    fi
}

function select_an_option() {
    local max_options=$1
    local default_option=${2:-1}
    local response_var=$3
    local response

    while true; do
        read -r -p "${Y}select an option (Default ${default_option}): ${W}" response
        response=${response:-$default_option}

        if [[ $response =~ ^[0-9]+$ ]] && ((response >= 1 && response <= max_options)); then
            echo
            print_success "Continuing with answer: $response"
            sleep 0.2
            eval "$response_var=$response"
            break
        else
            echo
            print_failed " Invalid input, Please enter a number between 1 and $max_options"
        fi
    done
}

function preprocess_conf() {
    # Preprocess configuration file:
    # 1. Remove lines where keys contain dashes (-).
    # 2. Remove quotes from keys and values.
	echo "${R}[${C}-${R}]${G} Prepering config file...${W}"
    sed -i -E '/^[[:space:]]*[^#=]+-.*=/d; s/^([[:space:]]*[^#=]+)="([^"]*)"/\1=\2/g' "$config_file"
}

function read_conf() {
    if [[ ! -f "$config_file" ]]; then
        print_failed " Configuration file $config_file not found"
		exit 0
    fi

	source "$config_file"
    print_success "Configuration variables loaded"
}

function print_to_config() {
    local var_name="$1"
    local var_value="${2:-${!var_name}}"
    local IFS=$' \t\n'
  
    if grep -q "^${var_name}=" "$config_file" 2>/dev/null; then
        sed -i "s|^${var_name}=.*|${var_name}=\"${var_value}\"|" "$config_file"
    else
        echo "${var_name}=\"${var_value}\"" >> "$config_file"
    fi
    
    print_log "$var_name \"$var_value\""
}

function validate_required_vars() {
    local required_vars=(
        # Basic system variables
        "HOME" 
        "PREFIX"
        "TMPDIR"
        "PACKAGE_MANAGER"
        
        # Display and GUI variables
        "display_number"
        "gui_mode"
        "de_name"
        "de_startup"
        
        # Hardware acceleration variables
        "enable_hw_acc"
        "device_gpu_model_name"
        "app_arch"
        
        # Configuration paths
        "config_file"
        "themes_folder"
        "icons_folder"
    )

    # If hardware acceleration is enabled, add required variables
    if [[ "$enable_hw_acc" == "y" ]]; then
        required_vars+=(
            "termux_hw_answer"
            "pd_hw_answer"
            "confirmation_mesa_vulkan_icd_wrapper"
            "hw_method"
            "initialize_server_method"
        )
    fi

    # If a distro is enabled, add required variables
    if [[ "$distro_add_answer" == "y" ]]; then
        required_vars+=(
            "selected_distro"
            "pd_audio_config_answer"
            "pd_useradd_answer"
            "user_name"
        )
    fi

    local optional_vars=(
        "pd_hw_method"
        "gpu_environment_variable"
        "pass"  # Only required if pd_pass_type=2
        "distro_path"
    )

    echo "${R}[${C}-${R}]${G} Validating required variables...${W}"
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if (( ${#missing_vars[@]} > 0 )); then
        print_failed "The following required variables are not set:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        exit 1
    fi

    # Additional validation for specific variables
    if [[ "$enable_hw_acc" == "y" && -z "$termux_hw_answer" ]]; then
        print_failed "Hardware acceleration is enabled but termux_hw_answer is not set"
        exit 1
    fi

    if [[ "$enable_hw_acc" == "y" && "$distro_add_answer" == "y" && -z "$pd_hw_answer" ]]; then
        print_failed "Hardware acceleration is enabled but pd_hw_answer is not set"
        exit 1
    fi

    print_success "All required variables are set"
    return 0
}

#########################################################################
#
# Ask Required Questions
#
#########################################################################

# check the avilable styles and create a list to type the corresponding number
# in the style readme file the name must use this'## number name :' pattern, like:- ## 1. Basic Style:
function questions_theme_select() {
    local owner="sabamdarif"
	local repo="termux-desktop"
	local main_folder="setup-files/$de_name"
	local branch="setup-files"

	# Call the count_subfolders function with the branch parameter
	subfolder_count_value=$(count_subfolders "$owner" "$repo" "$main_folder" "$branch" 2>/dev/null)

    cd "$HOME" || return
    echo "${R}[${C}-${R}]${G} Downloading list of available styles...${W}"
    check_and_backup "${current_path}/styles.md"
    download_file "${current_path}/styles.md" "https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/${de_name}_styles.md"

    clear
    banner

    if [[ -n "$subfolder_count_value" ]]; then
        echo "${R}[${C}-${R}]${G} Check the $de_name styles section in GitHub${W}"
        echo
        echo "${R}[${C}-${R}]${B} https://github.com/sabamdarif/termux-desktop/blob/main/${de_name}_styles.md${W}"
        echo
        echo "${R}[${C}-${R}]${G} Number of available custom styles for $de_name is: ${C}${subfolder_count_value}${W}"
        echo
        echo "${R}[${C}-${R}]${G} Available Styles:${W}"
        echo
        grep -oP '## \d+\..+?(?=(\n## \d+\.|\Z))' styles.md | while read -r style; do
            echo "${Y}${style#### }${W}"
        done

        while true; do
            echo
            read -r -p "${R}[${C}-${R}]${Y} Type number of the style: ${W}" style_answer

            if [[ -z "$style_answer" ]]; then
                echo
                print_failed "Input cannot be empty. Please type a number"
                continue
            fi

            if [[ "$style_answer" =~ ^[0-9]+$ ]] && [[ "$style_answer" -ge 0 ]] && [[ "$style_answer" -le "$subfolder_count_value" ]]; then
                style_name=$(grep -oP "^## $style_answer\..+?(?=(\n## \d+\.|\Z))" "${current_path}/styles.md" | sed -e "s/^## $style_answer\. //" -e "s/:$//" -e 's/^[[:space:]]*//;s/[[:space:]]*$//')
                break
            else
                echo
                print_failed "The entered style number is incorrect"
                echo
                if [[ "$subfolder_count_value" == "0" ]]; then
                    echo "${R}[${C}-${R}]${Y} Please enter 0 because for $de_name only stock style is available${W}"
                    echo
                else
                    echo "${R}[${C}-${R}]${Y} Please enter a number between 0 to ${subfolder_count_value}${W}"
                    echo
                fi
                echo "${R}[${C}-${R}]${G} Check the $de_name styles section in GitHub${W}"
                echo
                echo "${R}[${C}-${R}]${B} https://github.com/sabamdarif/termux-desktop/blob/main/${de_name}_styles.md${W}"
                echo
            fi
        done
		print_to_config "style_answer"
		print_to_config "style_name"
        check_and_delete "${current_path}/styles.md"
    else
        print_failed "Failed to get total available styles value"
		exit 0
    fi
    print_log "$style_answer $subfolder_count_value"
}

function questions_setup_manual() {
	banner
	echo "${R}[${C}-${R}]${G} Select Desktop Environment${W}"
	echo " "
	echo "${Y}1. XFCE${W}"
	echo
	echo "${Y}2. LXQT${W}"
	echo
	echo "${Y}3. OPENBOX WM${W}"
	echo
	echo "${Y}4. MATE (Unstable)${W}"
	echo
	desktop_answer=1
	# set the variables based on chosen de
	sys_icons_folder="$PREFIX/share/icons"
	sys_themes_folder="$PREFIX/share/themes"
	if [[ "$desktop_answer" == "1" ]]; then
	de_name="xfce"
	themes_folder="$HOME/.themes"
	icons_folder="$HOME/.icons"
	de_startup="xfce4-session"
	elif [[ "$desktop_answer" == "2" ]]; then
	de_name="lxqt"
	themes_folder="$sys_themes_folder"
	icons_folder="$sys_icons_folder"
	de_startup="startlxqt"
	elif [[ "$desktop_answer" == "3" ]]; then
	de_name="openbox"
	themes_folder="$sys_themes_folder"
	icons_folder="$sys_icons_folder"
	de_startup="openbox-session"
	elif [[ "$desktop_answer" == "4" ]]; then
	de_name="mate"
	themes_folder="$HOME/.themes"
	icons_folder="$HOME/.icons"
	de_startup="mate-session"
	fi
	print_to_config "de_startup"
	print_to_config "de_name"
	print_to_config "themes_folder"
	print_to_config "icons_folder"

	banner
	questions_theme_select
	echo
	print_success "Continuing with answer: ${style_answer})$style_name"
	sleep 0.2
	banner
	echo "${R}[${C}-${R}]${G}${BOLD} Select browser you want to install${W}"
	echo
	echo "${Y}1. firefox${W}"
	echo
	echo "${Y}2. chromium${W}"
	echo
	echo "${Y}3. firefox & chromium (both)${W}"
	echo
	echo "${Y}4. Skip${W}"
	echo
	browser_answer=3
	banner
	echo "${R}[${C}-${R}]${G}${BOLD} Select IDE you want to install${W}"
	echo
	echo "${Y}1. VS Code${W}"
	echo
	echo "${Y}2. Geany (lightweight IDE)${W}"
	echo
	echo "${Y}3. VS Code & Geany (both)${W}"
	echo
	echo "${Y}4. Skip${W}"
	echo
	ide_answer=3
	banner
	echo "${R}[${C}-${R}]${G}${BOLD} Select Media Player you want to install${W}"
	echo
	echo "${Y}1. Vlc${W}"
	echo
	echo "${Y}2. Audacious${W}"
	echo
	echo "${Y}3. Vlc & Audacious (both)${W}"
	echo
	echo "${Y}4. Skip${W}"
	echo
	player_answer=1
	banner
	echo "${R}[${C}-${R}]${G}${BOLD} Select Photo Editor${W}"
	echo
	echo "${Y}1. Gimp${W}"
	echo
	echo "${Y}2. Inkscape${W}"
	echo
	echo "${Y}3. Gimp & Inkscape (both)${W}"
	echo
	echo "${Y}4. Skip${W}"
	echo
	photo_editor_answer=1
	banner
	echo "${R}[${C}-${R}]${G}${BOLD} Do you want to install wine in termux ${C}(without proot-distro)${W}"
	echo
	echo "${Y}1. Native ${C}(can run only arm64 based exe)${W}"
	echo
	echo "${Y}2. Using Mobox ${C}${W}"
	echo
	echo "${R}[${C}-${R}]${B} Know More About Mobox:- https://github.com/olegos2/mobox/${W}"
	echo
	echo "${Y}3. Wine Hangover (Best)${W}"
	echo
	echo "${Y}4. Skip${W}"
	echo
	wine_answer=3
	banner
	enable_hw_acc=n
	print_to_config "enable_hw_acc"
	banner
	echo "${R}[${C}-${R}]${G} By default, it only adds 4-5 wallpapers${W}"
	echo
	ext_wall_answer=y
	banner
	zsh_answer=y
	banner
	echo
	echo "${R}[${C}-${R}]${B} Know More About Terminal Utility:- https://github.com/sabamdarif/termux-desktop/blob/main/see-more.md#hammer_and_wrenchlearn-about-terminal-utilities${W}"
	echo
	terminal_utility_setup_answer=y
	banner
		echo -e "${R}[${C}-${R}]${B} File Manager Tools Enhancement${W}

${B}Overview:${W}
This option enhances your file manager with powerful right-click menu features.

${B}Key Features:${W}
   • Media Operations
     - Video processing and conversion
     - Image editing and optimization
     - Audio file management
     - PDF manipulation

   • File Management
     - Archive compression/extraction
     - File permissions control
     - Document processing
     - File encryption
     - Hash verification

   • Additional Features
     - Custom scripts integration
     - Batch processing
     - Quick actions menu

${B}How to Access:${W}
Access these features through the 'Scripts' menu in your file manager's right-click context menu.
${W}"
	fm_tools=y
	banner
	echo "${R}[${C}-${R}]${G}${BOLD} Select Gui Mode${W}"
	echo
	echo "${Y}1. Termux:x11${W}"
	echo
	echo "${Y}2. Both Termux:x11 and VNC${W}"
	echo
	gui_mode_num=2

	# set gui_mode and display_number value
	if [[ "$gui_mode_num" == "1" ]]; then
		gui_mode="termux_x11"
		display_number="0"
		gui_mode_name="Termux:x11"
		print_to_config "gui_mode"
		print_to_config "display_number"
	elif [[ "$gui_mode_num" == "2" ]]; then
		gui_mode="both"
		display_number="0"
		gui_mode_name="Both"
		print_to_config "gui_mode"
		print_to_config "display_number"
	fi
	print_to_config "gui_mode_num"

	banner
	de_on_startup=y
	if [[ "$de_on_startup" == "y" && "$gui_mode" == "both" ]]; then
	echo "${R}[${C}-${R}]${G} You chose both vnc and termux:x11 to access gui mode${W}"
	echo
	echo "${R}[${C}-${R}]${G} Which will be your default${W}"
	echo
	echo "${Y}1. Termux:x11${W}"
	echo
	echo "${Y}2. Vnc${W}"
	echo
	autostart_gui_mode_num=2
	print_to_config "autostart_gui_mode_num"

		if [[ "$autostart_gui_mode_num" == "1" ]]; then
			default_gui_mode="termux_x11"
		elif [[ "$autostart_gui_mode_num" == "2" ]]; then
			default_gui_mode="vnc"
		fi

	print_to_config "default_gui_mode"
	fi
	banner
	echo -e "
${R}[${C}-${R}]${G}${BOLD} Linux Distro Container (proot-distro):- ${W}

It will help you to install apps that aren't available in Termux.
So it will set up a Linux distro container and add options to install those apps.
Also, you can launch those installed apps from Termux like other apps.
"
echo "Learn More:- https://github.com/sabamdarif/termux-desktop/blob/main/proot-container.md"
echo
	distro_add_answer=y
	print_to_config "distro_add_answer"
if [[ "$enable_hw_acc" == "y" ]]; then
	banner
	if ! type -p pacman >/dev/null 2>&1; then
	echo "${R}[${C}-${R}]${R}${BOLD} Read This Carefully:-${W}"
	echo -e "
${R}[${C}-${R}]${G}${BOLD} Mesa Vulkan ICD-Wrapper ${W}

If you have Adreno GPU then please select ubuntu or debian as Linux container so it can use ternip in the Linux container.\n
Sadly for other then adreno, GPU might / might not work on the Linux container./n

If you type 'n/N' then it will use the old virtualizing way to setup Hardware Acceleration

Also type 'n/N' If you want to use Freedreno KGSL (Adreno GPU Only)./n
"
	confirmation_y_or_n "Do you want to install the new mesa-vulkan-icd-wrapper Driver" confirmation_mesa_vulkan_icd_wrapper
	print_to_config "confirmation_mesa_vulkan_icd_wrapper"
	fi
fi
}

function setup_device_gpu_model() {
	if [[ "$gpu_name" == "unknown" ]]; then
		while true; do
		banner
    	echo -e "${R}[${C}-${R}]${G} Unable to auto detect GPU\n ${W}"
    	echo "${R}[${C}-${R}]${G}${BOLD} Please Select Your Device GPU${W}"
    	echo
    	echo "${Y}1. Adreno${W}"
    	echo
    	echo "${Y}2. Mali${W}"
    	echo
    	echo "${Y}3. Xclipse${W}"
    	echo
    	echo "${Y}4. Others (Unstable)${W}"
    	echo
		# read -p "${Y}Enter your choice (1-4): ${W}" device_gpu_model

    		if [[ "$device_gpu_model" =~ ^[1-4]$ ]]; then
    		    print_success "Continuing with answer: $device_gpu_model"
    		    break
    		else
    		    print_warn "Invalid input, Please enter a number between 1 and 4"
    		fi
		done
		print_to_config "device_gpu_model"

		# set gpu model name
		case "$device_gpu_model" in
    	1) device_gpu_model_name="adreno" ;;
    	2) device_gpu_model_name="mali" ;;
    	3) device_gpu_model_name="xclipse" ;;
    	4) device_gpu_model_name="others" ;;
		esac
	else
		device_gpu_model_name="$gpu_name"
	fi
	print_to_config "device_gpu_model_name"

}

# distro hardware accelrration related questions
function distro_hw_questions() {
	if [[ "$distro_add_answer" == "y" ]]; then
    case "$termux_hw_answer" in
        "virgl"|"virgl_vulkan")
            if [[ "$device_gpu_model_name" == "adreno" ]]; then
                banner
                echo "${R}[${C}-${R}]${G}${BOLD} Select Hardware Acceleration Driver For Linux Container${W}"
                echo "${Y}1. OpenGL (VIRGL ANGLE)${W}"
                echo
                echo "${Y}2. Turnip (Adreno GPU Only)${W}"
                echo
                select_an_option 2 1 pd_hw_answer_num
                pd_hw_answer=$([ "$pd_hw_answer_num" == "1" ] && echo "virgl" || echo "turnip")
            else
                pd_hw_answer="virgl"
            fi
            ;;
            
        "freedreno")
            pd_hw_answer="freedreno"
            ;;
            
        *)
            banner
            echo "${R}[${C}-${R}]${G}${BOLD} Select Hardware Acceleration Driver For Linux Container${W}"
            echo
            echo "${R}[${C}-${R}]${G} If You Skip It, It Will Use The Previous Selection${W}"
            echo
            echo "${Y}1. Vulkan (ZINK)${W}"
            echo
            echo "${Y}2. OpenGL ES (ZINK VIRGL)${W}"
            echo
            echo "${Y}3. Turnip (Adreno GPU Only)${W}"
            echo
            echo "${Y}4. Skip${W}"
            echo
            select_an_option 4 1 pd_hw_answer_num

            case "$pd_hw_answer_num" in
                1) pd_hw_answer="zink" ;;
                2) pd_hw_answer="zink_virgl" ;;
                3) pd_hw_answer="turnip" ;;
            esac
            ;;
    esac

    	# Save to config file if pd_hw_answer was set
    	if [[ -n "$pd_hw_answer" ]]; then
        	print_to_config "pd_hw_answer_num"
        	print_to_config "pd_hw_answer"
    	fi
	fi
}

# hardware accelrration related questions

function exp_termux_gl_hw_support() {
	banner
	echo "${R}[${C}-${R}]${G}${BOLD} First Read This${W}"
	echo
	echo "${R}[${C}-${R}]${B} This:- https://github.com/sabamdarif/termux-desktop/blob/main/hw-acceleration.md${W}"
	echo
	echo "${R}[${C}-${R}]${G}${BOLD} It will be used to enable opengl support${W}"
	echo
	echo "${Y}1. Vulkan (ZINK)${W}"
	echo
	echo "${Y}2. OpenGL (VIRGL ANGLE)${W}"
	echo
	echo "${Y}3. Vulkan (VIRGL ANGLE)${W}"
	echo
	echo "${Y}4. OpenGL ES (ZINK VIRGL)${W}"
	echo
	echo "${Y}5. The Vulkan-Icd-Wrapper Driver With Mesa${W}"
	echo
	echo "${Y}6. The Vulkan-Icd-Wrapper Driver With Mesa-Zink${W}"
	echo
	echo "${Y}7. Freedreno KGSL (Unstable | Adreno GPU Only)${W}"
	echo
	select_an_option 7 1 exp_termux_gl_hw_answer_num
	print_to_config "exp_termux_gl_hw_answer_num"

	# set gpu api name
	case "$exp_termux_gl_hw_answer_num" in
	    1) exp_termux_gl_hw_answer="zink" ;;
	    2) exp_termux_gl_hw_answer="virgl" ;;
	    3) exp_termux_gl_hw_answer="virgl_vulkan" ;;
	    4) exp_termux_gl_hw_answer="zink_virgl" ;;
	    5) exp_termux_gl_hw_answer="zink_with_mesa" ;;
	    6) exp_termux_gl_hw_answer="zink_with_mesa_zink" ;;
	    7) exp_termux_gl_hw_answer="freedreno" ;;
	esac
	print_to_config "exp_termux_gl_hw_answer"
	termux_hw_answer="${exp_termux_gl_hw_answer}"
	print_to_config "exp_termux_gl_hw_answer"

    if [[ "$distro_add_answer" == "y" ]]; then
        case "$exp_termux_gl_hw_answer" in
            "virgl"|"virgl_vulkan")
				if [[ "$device_gpu_model_name" == "adreno" ]]; then
					distro_hw_questions
				else
                	pd_hw_answer="virgl"
                	print_to_config "pd_hw_answer"
				fi
                ;;
            *)
                distro_hw_questions
                ;;
        esac
    fi
}

function hw_questions() {
	banner
	if [[ "$confirmation_mesa_vulkan_icd_wrapper" == "y" ]]; then
	exp_termux_gl_hw_support
	else
    echo "${R}[${C}-${R}]${G}${BOLD} First Read This${W}"
    echo
    echo "${R}[${C}-${R}]${B} This:- https://github.com/sabamdarif/termux-desktop/blob/main/hw-acceleration.md${W}"
    echo
    echo "${R}[${C}-${R}]${G}${BOLD} Select Hardware Acceleration API${W}"
    echo
	echo "${Y}1. Vulkan (ZINK)${W}"
	echo
    echo "${Y}2. OpenGL (VIRGL ANGLE)${W}"
	echo
	echo "${Y}3. Vulkan (VIRGL ANGLE)${W}"
	echo
	echo "${Y}4. OpenGL ES (ZINK VIRGL)${W}"
	echo
	echo "${Y}5. Freedreno KGSL (Unstable | Adreno GPU Only)${W}"
	echo
	select_an_option 5 1 termux_hw_answer_num
	print_to_config "termux_hw_answer_num"

	# set gpu api name
	case "$termux_hw_answer_num" in
	    1) termux_hw_answer="zink" ;;
	    2) termux_hw_answer="virgl" ;;
	    3) termux_hw_answer="virgl_vulkan" ;;
	    4) termux_hw_answer="zink_virgl" ;;
	    5) termux_hw_answer="freedreno" ;;
	esac
		distro_hw_questions
	fi
}

# distro related questions
function choose_distro() {
	echo "${R}[${C}-${R}]${G}${BOLD} Select Linux Distro You Want To Add${W}"
	echo " "
	echo "${Y}1. Debian${W}"
	echo " "
	echo "${Y}2. Ubuntu${W}"
	echo " "
	echo "${Y}3. Arch (Unstable | Doen't Suppoted By AppStore)${W}"
	echo " "
	echo "${Y}4. Alpine (Doen't Suppoted By AppStore)${W}"
	echo " "
	echo "${Y}5. Fedora${W}"
	echo " "
	distro_answer=1
	print_to_config "distro_answer"

	case "$distro_answer" in
        1) selected_distro="debian" ;;
        2) selected_distro="ubuntu" ;;
        3) selected_distro="archlinux" ;;
        4) selected_distro="alpine" ;;
        5) selected_distro="fedora" ;;
        *) selected_distro="debian" ;;
    esac
    print_to_config "selected_distro"

}

function distro_questions() {
	banner
	choose_distro
	banner
	pd_audio_config_answer=y

	if [[ "$distro_add_answer" == "y" ]] && [[ "$zsh_answer" == "y" ]]; then
	banner
	distro_zsh_answer=y
	else
	distro_zsh_answer="$zsh_answer"
	fi
	print_to_config "distro_zsh_answer"

	if [[ "$distro_add_answer" == "y" ]] && [[ "$terminal_utility_setup_answer" == "y" ]]; then
	banner
	distro_terminal_utility_setup_answer=y
	else
	distro_terminal_utility_setup_answer="$terminal_utility_setup_answer"
	fi
	print_to_config "distro_terminal_utility_setup_answer"

	banner
	pd_useradd_answer=y
	print_to_config "pd_useradd_answer"
	echo

	if [[ "$pd_useradd_answer" == "n" ]]; then
	echo "${R}[${C}-${R}]${G} Skiping User Account Setup${W}"
	else
	echo "${R}[${C}-${R}]${G}${BOLD} Select user account type${W}"
	echo
	echo "${Y}1. User with no password confirmation${W}"
	echo
	echo "${Y}2. User with password confirmation${W}"
	echo
	pd_pass_type=1
	print_to_config "pd_pass_type"
	    if [[ "$pd_pass_type" == "1" ]]; then
	    while true; do
		echo " "
		echo "${R}[${C}-${R}]${G} Default Password Will Be Set, Because Sometimes It Might Ask You For Password${W}"
		echo
		echo "${R}[${C}-${R}]${G} Password:-${C}root${W}"
		echo
	    user_name=sefgh
	    echo
	    choice=y
	    echo
	    choice="${choice:-y}"
	    echo
	    print_success "Continuing with answer: $choice"
	    sleep 0.2
	    case $choice in
	    [yY]* )
	    print_success "Continuing with username ${C}$user_name"
	    break;;
	    [nN]* )
	    echo "${R}[${C}-${R}]${G}Please provide username again.${W}"
	    echo
	    ;;
	    * )
	    print_failed "Invalid input, Please enter y or n"
	    ;;
	    esac
	    done
	    print_to_config "user_name"
	    elif [[ "$pd_pass_type" == "2" ]]; then
	    echo
	    echo "${R}[${C}-${R}]${G}${BOLD} Create user account${W}"
	    echo
	    while true; do
	    read -r -p "${R}[${C}-${R}]${G}Input username [Lowercase]: ${W}" user_name
	    echo
	    read -r -p "${R}[${C}-${R}]${G}Input Password: ${W}" pass
	    echo
	    read -r -p "${R}[${C}-${R}]${Y}Do you want to continue with username ${C}$user_name ${Y}and password ${C}$pass${Y} ? (y/n) : ${W}" choice
	    echo
	    choice="${choice:-y}"
	    echo
	    print_success "Continuing with answer: $choice"
	    echo ""
	    sleep 0.2
	    case $choice in
	    [yY]* )
	    print_success "Continuing with username ${C}$user_name ${G}and password ${C}$pass"
	    break;;
	    [nN]* )
	    echo "${R}[${C}-${R}]${G}Please provide username and password again.${W}"
	    echo
	    ;;
	    * )
	    print_failed "Invalid input, Please enter y or n"
	    ;;
	    esac
	    done
	    print_to_config "user_name"
	    print_to_config "pass"
	    fi

	fi
}

function define_value_name() {
	# Gui mode
	if [[ "$gui_mode_num" == "1" ]]; then
	gui_mode_name="Termux:x11"
	elif [[ "$gui_mode_num" == "2" ]]; then
	gui_mode_name="Both"
	fi
	# autostart value
	if [[ "$de_on_startup" == "y" ]]; then
	autostart_value="Yes"
	elif [[ "$de_on_startup" == "n" ]]; then
	autostart_value="No"
	fi
	# browser
	if [[ "$browser_answer" == "1" ]]; then
	browser_name="Firefox"
	elif [[ "$browser_answer" == "2" ]]; then
	browser_name="Chromium"
	elif [[ "$browser_answer" == "3" ]]; then
	browser_name="Both Firefox and Chromium"
	elif [[ "$browser_answer" == "4" ]]; then
	browser_name="Skip"
	fi
	# media player
	if [[ "$player_answer" == "1" ]]; then
	media_player_name="Vlc"
	elif [[ "$player_answer" == "2" ]]; then
	media_player_name="Audacious"
	elif [[ "$player_answer" == "3" ]]; then
	media_player_name="Both Vlc and Audacious"
	elif [[ "$player_answer" == "4" ]]; then
	media_player_name="Skip"
	fi
	# Image Editor
	if [[ "$photo_editor_answer" == "1" ]]; then
	photo_editor_name="GIMP"
	elif [[ "$photo_editor_answer" == "2" ]]; then
	photo_editor_name="Inkscape"
	elif [[ "$photo_editor_answer" == "3" ]]; then
	photo_editor_name="Both GIMP and Inkscape"
	elif [[ "$photo_editor_answer" == "4" ]]; then
	photo_editor_name="Skip"
	fi
	# IDE
	if [[ "$ide_answer" == "1" ]]; then
	ide_name="VS Code (code-oss)"
	elif [[ "$ide_answer" == "2" ]]; then
	ide_name="Geany"
	elif [[ "$ide_answer" == "3" ]]; then
	ide_name="Both VS Code and Geany"
	elif [[ "$ide_answer" == "4" ]]; then
	ide_name="Skip"
	fi
	# WINE
	if [[ "$browser_answer" == "1" ]]; then
	wine_type_name="Native"
	elif [[ "$browser_answer" == "2" ]]; then
	wine_type_name="Mobox"
	elif [[ "$browser_answer" == "3" ]]; then
	wine_type_name="Wine Hangover"
	elif [[ "$browser_answer" == "4" ]]; then
	wine_type_name="Skip"
	fi
	# Extra Wallpapers
	if [[ "$ext_wall_answer" == "y" ]]; then
	ext_wall_answer_confirmation="Yes"
	elif [[ "$ext_wall_answer" == "n" ]]; then
	ext_wall_answer_confirmation="No"
	fi
	# File Manager Tools
	if [[ "$fm_tools" == "y" ]]; then
	fm_tools_confirmation="Yes"
	elif [[ "$fm_tools" == "n" ]]; then
	fm_tools_confirmation="No"
	fi
	# Shell
	if [[ "$zsh_answer" == "y" ]]; then
	current_shell_name="Zsh"
	elif [[ "$zsh_answer" == "n" ]]; then
	current_shell_name="Bash"
	fi
	# Terminal Utilities
	if [[ "$terminal_utility_setup_answer" == "y" ]]; then
	terminal_utility_setup_confirmation="Yes"
	elif [[ "$terminal_utility_setup_answer" == "n" ]]; then
	terminal_utility_setup_confirmation="No"
	fi
	# Hardware Acceleration Status
	if [[ "$enable_hw_acc" == "y" ]]; then
	hw_acc_confirmation="Enabled"
	elif [[ "$enable_hw_acc" == "n" ]]; then
	hw_acc_confirmation="Disabled"
	fi
	# Vulkan Driver
	if [[ "$confirmation_mesa_vulkan_icd_wrapper" == "y" ]]; then
	vulkan_driver_name="Vulkan ICD Wrapper"
	else
	vulkan_driver_name="Not Supported"
	fi
	# OpenGL Driver
	if [[ "$termux_hw_answer" == "zink" ]]; then
	opengl_driver_name="Zink"
	elif [[ "$termux_hw_answer" == "virgl" ]]; then
	opengl_driver_name="Virgl"
	elif [[ "$termux_hw_answer" == "virgl_vulkan" ]]; then
	opengl_driver_name="VIRGL ANGLE (Vulkan)"
	elif [[ "$termux_hw_answer" == "zink_virgl" ]]; then
	opengl_driver_name="OpenGL ES (ZINK VIRGL)"
	elif [[ "$termux_hw_answer" == "zink_with_mesa" ]]; then
	opengl_driver_name="The Vulkan-Icd-Wrapper Driver With Mesa"
	elif [[ "$termux_hw_answer" == "zink_with_mesa_zink" ]]; then
	opengl_driver_name="The Vulkan-Icd-Wrapper Driver With Mesa-Zink"
	elif [[ "$termux_hw_answer" == "freedreno" ]]; then
	opengl_driver_name="Freedreno KGSL"
	else
	opengl_driver_name="Unable to select"
	fi
	# Linux Distro Container
	if [[ "$distro_add_answer" == "y" ]]; then
	distro_container_confirmation="Yes"
	elif [[ "$distro_add_answer" == "n" ]]; then
	distro_container_confirmation="No"
	fi
	# Distro User and Pass
	if [[ "$pd_useradd_answer" == "y" ]]; then
	distro_user_add_confirmation="Yes"
	distro_user_name="${user_name}"
		if [[ -z "$pass" ]]; then
		distro_pass="root"
		else
		distro_pass="${pass}"
		fi
	elif [[ "$pd_useradd_answer" == "n" ]]; then
	distro_user_add_confirmation="No"
	distro_user_name="Null"
	distro_pass="Null"
	fi
	# Distro Audio Support
	if [[ "$pd_audio_config_answer" == "y" ]]; then
	pd_audio_config_confirmation="Yes"
	elif [[ "$pd_audio_config_answer" == "n" ]]; then
	pd_audio_config_confirmation="No"
	fi
	# Distro Hardware Acceleration
	if [[ "$enable_hw_acc" == "y" ]]; then
	distro_hw_acc_confirmation="Enabled"
	elif [[ "$enable_hw_acc" == "n" ]]; then
	distro_hw_acc_confirmation="Disabled"
	fi
	# Distro Vulkan Driver
	if [[ "$pd_hw_answer" == "zink" ]]; then
	distro_vulkan_driver="Not Supported"
	elif [[ "$pd_hw_answer" == "zink_virgl" ]] || [[ "$pd_hw_answer" == "virgl" ]]; then
	distro_vulkan_driver="Not Supported"
	elif [[ "$pd_hw_answer" == "turnip" ]]; then
	distro_vulkan_driver="Turnip"
	elif [[ "$pd_hw_answer" == "freedreno" ]]; then
	distro_vulkan_driver="Freedreno"
	else
	distro_vulkan_driver="Unable to select"
	fi
	# Distro OpenGL Driver
	if [[ "$pd_hw_answer" == "zink" ]]; then
	distro_opengl_driver="Zink"
	elif [[ "$pd_hw_answer" == "zink_virgl" ]]; then
	distro_opengl_driver="Zink Virgl"
	elif [[ "$pd_hw_answer" == "virgl" ]]; then
	distro_opengl_driver="Virgl"
	elif [[ "$pd_hw_answer" == "turnip" ]]; then
	distro_opengl_driver="Turnip"
	elif [[ "$pd_hw_answer" == "freedreno" ]]; then
	distro_opengl_driver="Freedreno"
	else
	distro_opengl_driver="Unable to select"
	fi
	# Distro Shell
	if [[ "$distro_zsh_answer" == "y" ]]; then
	distro_current_shell="Zsh"
	elif [[ "$distro_zsh_answer" == "n" ]]; then
	distro_current_shell="Bash"
	fi
	# Distro Terminal Utilities
	if [[ "$distro_terminal_utility_setup_answer" == "y" ]]; then
	distro_terminal_utility_setup_confirmation="Yes"
	elif [[ "$distro_terminal_utility_setup_answer" == "n" ]]; then
	distro_terminal_utility_setup_confirmation="No"
	fi
}

function print_conf_info() {
	define_value_name
	trap '' SIGINT SIGTSTP
		banner
		echo "${R}[${C}-${R}]${G} Installation Configuration Summary${W}"
		echo
		echo "${G}Desktop Environment${W}"
		echo "   • Desktop: $(echo "$de_name" | tr '[:lower:]' '[:upper:]')"
		echo "   • Desktop Style: ${style_answer}) ${style_name}"
		echo "   • GUI Access: ${gui_mode_name}"
		echo "   • Auto-start: ${autostart_value}"
		sleep 0.015

		echo "${G}Applications${W}"
		echo "   • Browser: ${browser_name}"
		echo "   • Media Player: ${media_player_name}"
		echo "   • Image Editor: ${photo_editor_name}"
		echo "   • IDE: ${ide_name}"
		echo "   • WINE: ${wine_type_name}"
		sleep 0.015

		echo "${G}Customization${W}"
		echo "   • Extra Wallpapers: ${ext_wall_answer_confirmation}"
		echo "   • File Manager Tools: ${fm_tools_confirmation}"
		sleep 0.015

		echo "${G}Terminal Setup${W}"
		echo "   • Shell: ${current_shell_name}"
		echo "   • Terminal Utilities: ${terminal_utility_setup_confirmation}"
		sleep 0.015

		echo "${G}Hardware Acceleration${W}"
		echo "   • Status: ${hw_acc_confirmation}"
		echo "   • GPU: $(echo "$device_gpu_model_name" | tr '[:lower:]' '[:upper:]')"
		echo "   • Vulkan Driver: ${vulkan_driver_name}"
		echo "   • OpenGL Driver: ${opengl_driver_name}"
		sleep 0.015

		echo "${G}Linux Distro Container${W}"
		echo "   • Distribution: ${selected_distro}"
		echo "   • Distro Username: $user_name"
		echo "   • Distro Pass: ${distro_pass}"
		echo "   • Audio Support: ${pd_audio_config_confirmation}"
		echo "   • Hardware Acceleration: ${distro_hw_acc_confirmation}"
		echo "   • Vulkan Driver: ${distro_vulkan_driver}"
		echo "   • OpenGL Driver: ${distro_opengl_driver}"
		echo "   • Shell: ${distro_current_shell}"
		echo "   • Terminal Utilities: ${distro_terminal_utility_setup_confirmation}"
		sleep 0.015
		# Re-enable keyboard interruptions
		# trap - SIGINT SIGTSTP
		# wait_for_keypress
}

function ask_to_chose_de() {
	# Setlect Desktop Environment
	banner
	echo "${R}[${C}-${R}]${G} Select Desktop Environment${W}"
	echo " "
	echo "${Y}1. XFCE${W}"
	echo
	echo "${Y}2. LXQT${W}"
	echo
	echo "${Y}3. OPENBOX WM${W}"
	echo
	echo "${Y}4. MATE (Unstable)${W}"
	echo
	desktop_answer=1
	echo
	# set the variables based on chosen de
	sys_icons_folder="$PREFIX/share/icons"
	sys_themes_folder="$PREFIX/share/themes"
	if [[ "$desktop_answer" == "1" ]]; then
	de_name="xfce"
	themes_folder="$HOME/.themes"
	icons_folder="$HOME/.icons"
	de_startup="xfce4-session"
	style_answer=1
	elif [[ "$desktop_answer" == "2" ]]; then
	de_name="lxqt"
	themes_folder="$sys_themes_folder"
	icons_folder="$sys_icons_folder"
	de_startup="startlxqt"
	style_answer=2
	elif [[ "$desktop_answer" == "3" ]]; then
	de_name="openbox"
	themes_folder="$sys_themes_folder"
	icons_folder="$sys_icons_folder"
	de_startup="openbox-session"
	style_answer=1
	elif [[ "$desktop_answer" == "4" ]]; then
	de_name="mate"
	themes_folder="$HOME/.themes"
	icons_folder="$HOME/.icons"
	de_startup="mate-session"
	style_answer=1
	fi
	print_to_config "de_startup"
	print_to_config "de_name"
	print_to_config "themes_folder"
	print_to_config "icons_folder"
	print_to_config "style_answer"

	# Get Style name
	local owner="sabamdarif"
	local repo="termux-desktop"
	local main_folder="setup-files/$de_name"

	echo "${R}[${C}-${R}]${G} Downloading list of available styles...${W}"
	check_and_backup "${current_path}/styles.md"
	if ! download_file "${current_path}/styles.md" "https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/${de_name}_styles.md"; then
	    print_failed "Failed to download styles list"
    	return 1
	fi

	if [[ -f "${current_path}/styles.md" ]]; then
    	style_name=$(grep -oP "^## $style_answer\..+?(?=(\n## \d+\.|\Z))" "${current_path}/styles.md" | sed -e "s/^## $style_answer\. //" -e "s/:$//" -e 's/^[[:space:]]*//;s/[[:space:]]*$//')
    	if [[ -z "$style_name" ]]; then
        	print_failed "Failed to get style name for style number $style_answer"
        	check_and_delete "${current_path}/styles.md"
        	return 1
    	fi
	else
    	print_failed "Styles list file not found"
    	return 1
	fi

	check_and_delete "${current_path}/styles.md"
	
	print_to_config "style_name"

}

function questions_install_type() {
    banner
    # Clear screen and show title first
    echo "${R}[${C}-${R}]${G} Installation Options Overview${W}"
    echo
    sleep 0.2

    echo -e "${G} Key Terms:${W}
• Generic: Pre-configured options that so far work best in most of the devices\n
• Recommended: Tested configurations with minimal known issues\n
• Hardware Acceleration: Uses your device's GPU for better graphics render\n
• Custom: Full control over all installation options\n
"
echo "${R}[${Y}!${R}]${R} Important Note: ${W}"
echo -e "${B}
Generic is only recomended for beginners\n
For most of the user who are familiar with termux, custom option recomended for them. 

${C}So use the ${G}3. Custom${C} option, it's best
${W}"
    
    # Show selection options
    echo "${R}[${C}-${R}]${G} Select Install Type${W}"
    echo " "
    echo "${Y}1. Generic Recommended With Hardware Acceleration${W}"
    echo " "
    echo "${Y}2. Generic Recommended Without Hardware Acceleration${W}"
	echo " "
    echo "${Y}3. Custom${W}"
    echo " "
    
    install_type_answer=3

	if [[ "$install_type_answer" == "1" ]]; then

######################################################################
# ********* Generic Recomended With Hardware Acceleration ********** #
######################################################################
		ask_to_chose_de
		setup_device_gpu_model
		# browser selection
		browser_answer=3
		print_to_config "browser_answer"
		# ide selection
		ide_answer=4
		print_to_config "ide_answer"
		# media player selection
		player_answer=1
		print_to_config "player_answer"
		# photo editor selection
		photo_editor_answer=1
		print_to_config "photo_editor_answer"
		# wine selection
		wine_answer=4
		print_to_config "wine_answer"
		# extra walllpaper
		ext_wall_answer=n
		print_to_config "ext_wall_answer"
		# zsh selection
		zsh_answer=y
		print_to_config "zsh_answer"
		# Terminal Utility selection
		terminal_utility_setup_answer=y
		print_to_config "terminal_utility_setup_answer"
		# file manager tools
		fm_tools=y
		print_to_config "fm_tools"
		# Gui Mode
		gui_mode_num=1
		gui_mode="termux_x11"
		display_number="0"
		print_to_config "gui_mode_num"
		print_to_config "gui_mode"
		print_to_config "display_number"
		# de on startup
		de_on_startup=n
		print_to_config "de_on_startup"
		# Linux container
		distro_add_answer=y
		distro_answer=1
		selected_distro="debian"
		print_to_config "distro_add_answer"
		print_to_config "distro_answer"
		print_to_config "selected_distro"
		# Hw enable question
		enable_hw_acc=y
		print_to_config "enable_hw_acc"
		print_to_config "device_gpu_model_name"
		# hw acc termux
		confirmation_mesa_vulkan_icd_wrapper=y
		exp_termux_gl_hw_answer_num=3
		exp_termux_gl_hw_answer="virgl_vulkan"
		termux_hw_answer="virgl_vulkan"
		print_to_config "confirmation_mesa_vulkan_icd_wrapper"
		print_to_config "exp_termux_gl_hw_answer_num"
		print_to_config "exp_termux_gl_hw_answer"
		if [[ "$device_gpu_model_name" == "adreno" ]] && [[ "$app_arch" == "aarch64" ]]; then
			# hw acc termux
			pd_hw_answer_num=2
			pd_hw_answer="turnip"
		else
			# hw acc termux
			pd_hw_answer_num=2
			pd_hw_answer="zink_virgl"
		fi
		print_to_config "pd_hw_answer_num"
		print_to_config "pd_hw_answer"
		# configure audio support for Linux distro container
		pd_audio_config_answer=y
		print_to_config "pd_audio_config_answer"
		# Linux distro container zsh setup
		distro_zsh_answer=y
		print_to_config "distro_zsh_answer"
		# Linux distro container terminal utility setup
		distro_terminal_utility_setup_answer=n
		print_to_config "distro_terminal_utility_setup_answer"
		# Linux distro container create a normal user account
		pd_useradd_answer=y
		pd_pass_type=1
		# Print Configuration

		# create username for distro
		banner
		echo "${R}[${C}-${R}]${G} Please type the username for the linux distro container${W}"
		echo
		while true; do
			echo " "
			echo "${R}[${C}-${R}]${G} Default Password Password for ubuntu is:-${C}root (if needed)${W}"
			echo
			read -r -p "${R}[${C}-${R}]${G} Input username [Lowercase]: ${W}" user_name
			echo
			read -r -p "${R}[${C}-${R}]${Y} Do you want to continue with username ${C}$user_name ${Y}? (y/n) : ${W}" choice
			echo
			choice="${choice:-y}"
			echo
			print_success "Continuing with answer: $choice"
			sleep 0.2
			case $choice in
			[yY]* )
			print_success "Continuing with username ${C}$user_name"
			break;;
			[nN]* )
			echo "${R}[${C}-${R}]${G}Please provide username again.${W}"
			echo
			;;
			* )
			print_failed "Invalid input, Please enter y or n"
			;;
			esac
		done

	elif [[ "$install_type_answer" == "2" ]]; then

######################################################################
# ******* Generic Recomended Without Hardware Acceleration ********* #
######################################################################
		ask_to_chose_de
		# browser selection
		browser_answer=3
		print_to_config "browser_answer"
		# ide selection
		ide_answer=4
		print_to_config "ide_answer"
		# media player selection
		player_answer=1
		print_to_config "player_answer"
		# photo editor selection
		photo_editor_answer=1
		print_to_config "photo_editor_answer"
		# wine selection
		wine_answer=4
		print_to_config "wine_answer"
		# extra walllpaper
		ext_wall_answer=n
		print_to_config "ext_wall_answer"
		# zsh selection
		zsh_answer=n
		print_to_config "zsh_answer"
		# Terminal Utility selection
		terminal_utility_setup_answer=n
		print_to_config "terminal_utility_setup_answer"
		# file manager tools
		fm_tools=n
		print_to_config "fm_tools"
		# Gui Mode
		gui_mode_num=1
		gui_mode="termux_x11"
		display_number="0"
		print_to_config "gui_mode_num"
		print_to_config "gui_mode"
		print_to_config "display_number"
		# de on startup
		de_on_startup=n
		print_to_config "de_on_startup"
		# Linux container
		distro_add_answer=y
		distro_answer=1
		selected_distro="debian"
		print_to_config "distro_add_answer"
		print_to_config "distro_answer"
		print_to_config "selected_distro"
		# Hw enable question
		enable_hw_acc=n
		print_to_config "enable_hw_acc"
		# configure audio support for Linux distro container
		pd_audio_config_answer=y
		print_to_config "pd_audio_config_answer"
		# Linux distro container zsh setup
		distro_zsh_answer=y
		print_to_config "distro_zsh_answer"
		# Linux distro container terminal utility setup
		distro_terminal_utility_setup_answer=n
		print_to_config "distro_terminal_utility_setup_answer"
		# Linux distro container create a normal user account
		pd_useradd_answer=y
		pd_pass_type=1
		print_to_config "pd_useradd_answer"
		print_to_config "pd_pass_type"

		# create username for distro
		banner
		echo "${R}[${C}-${R}]${G} Please type the username for the linux distro container${W}"
		echo
		while true; do
			echo " "
			echo "${R}[${C}-${R}]${G} Default Password Password for ubuntu is:-${C}root (if needed)${W}"
			echo
			read -r -p "${R}[${C}-${R}]${G} Input username [Lowercase]: ${W}" user_name
			echo
			read -r -p "${R}[${C}-${R}]${Y} Do you want to continue with username ${C}$user_name ${Y}? (y/n) : ${W}" choice
			echo
			choice="${choice:-y}"
			echo
			print_success "Continuing with answer: $choice"
			sleep 0.2
			case $choice in
			[yY]* )
			print_success "Continuing with username ${C}$user_name"
			break;;
			[nN]* )
			echo "${R}[${C}-${R}]${G}Please provide username again.${W}"
			echo
			;;
			* )
			print_failed "Invalid input, Please enter y or n"
			;;
			esac
		done

		
	elif [[ "$install_type_answer" == "3" ]]; then
		questions_setup_manual
	fi
}

#########################################################################
#
# Update System And Install Required Packages Repo And Bssic Task
#
#########################################################################

function chose_mirror() {
	echo "${R}[${C}-${R}]${G}${BOLD}Selecting best termux packages mirror please wait${W}"
	local todays_date
	todays_date=$(date +"%d-%m")
    unlink "$PREFIX/etc/termux/chosen_mirrors" &>/dev/null
    ln -s "$PREFIX/etc/termux/mirrors/all" "$PREFIX/etc/termux/chosen_mirrors" &>/dev/null
    pkg --check-mirror update
	touch "$HOME/.run_chosen_mirrors_once"
	echo "$todays_date" > "$HOME/.run_chosen_mirrors_once"
}

function update_sys() {
    banner
    echo "${R}[${C}-${R}]${G}${BOLD} Updating System....${W}"
    echo

    local todays_date
    todays_date=$(date +"%d-%m")

    if [[ "$PACKAGE_MANAGER" == "pacman" ]]; then
        pacman -Syu --noconfirm
    else
        if [[ -f "$HOME/.run_chosen_mirrors_once" ]]; then
			local date_on_file
			date_on_file="$(cat "$HOME"/.run_chosen_mirrors_once)"
			# Check if the file is older than today
            if [[ $(find "$HOME/.run_chosen_mirrors_once" -mtime +0 2>/dev/null) ]] && [[ "$date_on_file" != "$todays_date" ]]; then # although [[ "$date_on_file" != "$todays_date" ]] is unnecessary
                chose_mirror
            fi
            pkg update -y -o Dpkg::Options::="--force-confnew"
            pkg upgrade -y -o Dpkg::Options::="--force-confnew"
        else
            chose_mirror
            pkg update -y -o Dpkg::Options::="--force-confnew"
            pkg upgrade -y -o Dpkg::Options::="--force-confnew"
        fi
    fi
}

function check_system_requirements() {
	local errors=0
	clear

	# Disable keyboard interruptions
    trap '' SIGINT SIGTSTP

	printf "%s############################################################\n" "$C"
	printf "%s#                                                          #\n" "$C"
	printf "%s#  ▀█▀ █▀▀ █▀█ █▀▄▀█ █ █ ▀▄▀   █▀▄ █▀▀ █▀ █▄▀ ▀█▀ █▀█ █▀█  #\n" "$C"
	printf "%s#   █  ██▄ █▀▄ █   █ █▄█ █ █   █▄▀ ██▄ ▄█ █ █  █  █▄█ █▀▀  #\n" "$C"
	printf "%s#                                                          #\n" "$C"
	printf "%s################# System Compatibility Check ###############%s\n" "$C" "$W"
	echo " "
    sleep 0.3
    # Check if running on Android
	android_version=$(getprop ro.build.version.release | cut -d'.' -f1)

    if [[ "$(uname -o)" == "Android" ]]; then
		if [[ "$android_version" -ge 8 ]]; then
        	print_status "ok" "Running on: ${W}Android $android_version"
		else
			print_status "error" "Running on: ${W}Android $android_version is not recomended"
			((errors++))
		fi
    else
        print_status "error" "Not running on Android"
        ((errors++))
    fi
    sleep 0.2
	# Android device soc & model details
	model="$(getprop ro.product.brand) $(getprop ro.product.model)"
	print_status "ok" "Device: ${W}$model"
	sleep 0.2
	PROCESSOR_BRAND_NAME="$(getprop ro.soc.manufacturer)"
    PROCESSOR_NAME="$(getprop ro.soc.model)"
    HARDWARE="$(getprop ro.hardware)"
    
    if [[ -n "$PROCESSOR_BRAND_NAME" && -n "$PROCESSOR_NAME" ]]; then
        print_status "ok" "SOC: ${W}$PROCESSOR_BRAND_NAME $PROCESSOR_NAME"
    else
        print_status "ok" "SOC: ${W}$HARDWARE"
    fi
	sleep 0.2
	# Check GPU
	gpu_egl=$(getprop ro.hardware.egl)
    gpu_vulkan=$(getprop ro.hardware.vulkan)
    detected_gpu="$(echo -e "$gpu_egl\n$gpu_vulkan" | sort -u | tr '\n' ' ' | sed 's/ $//')"
	if echo "$detected_gpu" | grep -iq "adreno"; then
		gpu_name="adreno"
	elif echo "$detected_gpu" | grep -iq "mali"; then
		gpu_name="mali"
	elif echo "$detected_gpu" | grep -iq "xclipse"; then
		gpu_name="xclipse"
	else
		gpu_name="unknown"
	fi

	if [[ "$gpu_name" == "adreno" ]] ||  [[ "$gpu_name" == "mali" ]] || [[ "$gpu_name" == "xclipse" ]]; then
        print_status "ok" "GPU: ${W}$gpu_name"
    else
        print_status "warn" "Unknown GPU: ${W}$detected_gpu"
    fi
	sleep 0.2
    # Check architecture
	app_arch=$(uname -m)
	supported_arch="$(getprop ro.product.cpu.abilist)"
	local archtype
	case "$app_arch" in
    aarch64) archtype="aarch64" ;;
    armv7*|arm) archtype="arm" ;;
	esac

    if [[ "$archtype" == "aarch64" ]] || [[ "$archtype" == "arm" ]]; then
        print_status "ok" "App architecture: ${W}$app_arch"
    else
        print_status "error" "Unsupported architecture: $app_arch, requires aarch64/arm/armv7*"
        ((errors++))
    fi
	sleep 0.2
    # Check for termux app requirements
    if [[ -d "$PREFIX" ]]; then
        print_status "ok" "Termux PREFIX: ${W}Directory found"
		sleep 0.2
		local latest_tag
		latest_tag=$(get_latest_release "termux" "termux-app")
		if [[ "$TERMUX_VERSION" == "$latest_tag" ]]; then
			print_status "ok" "Termux Version: ${W}$TERMUX_VERSION"
			sleep 0.2
			local termux_build
			termux_build=$(echo "$TERMUX_APK_RELEASE" | awk '{print tolower($0)}')
			if [[ "$termux_build" == "github" ]] || [[ "$termux_build" == "fdroid" ]]; then
				print_status "ok" "Termux Build: ${W}$TERMUX_APK_RELEASE"
				sleep 0.2
			else
        		print_status "error" "$TERMUX_APK_RELEASE build is not recomended"
				echo "${W}Update Termux:- https://github.com/termux/termux-app/releases ${W}"
				sleep 0.2
			fi
		else
			print_status "warn" "Termux Version: ${W}$TERMUX_VERSION (Not Recomended)"
			echo "${R}[${G}!${R}]${G} Update Termux:- https://github.com/termux/termux-app/releases ${W}"
			sleep 0.2
		fi
    else
        print_status "error" "Termux PREFIX: directory not found"
        ((errors++))
		sleep 0.2
    fi
    # Check available storage space
	free_space=$(df -h "$HOME" | awk 'NR==2 {print $4}')
    if [[ $(df "$HOME" | awk 'NR==2 {print $4}') -gt 4194304 ]]; then
        print_status "ok" "Available storage: ${W}$free_space"
    else
        print_status "warn" "Low storage space: ${W}$free_space (4GB recommended)"
    fi
	sleep 0.2
    # Check RAM
	total_ram=$(free -htm | awk '/Mem:/ {print $2}')
    if [[ $(free -m | awk 'NR==2 {print $2}') -gt 2048 ]]; then
        print_status "ok" "RAM: ${W}${total_ram}"
    else
        print_status "warn" "Low RAM: ${W}${total_ram} (2GB recommended)"
    fi
	sleep 0.2
    echo
    if [[ $errors -eq 0 ]]; then
        print_success "All system requirements met!"
		sleep 0.2
        return 0
    else
        print_failed "Found $errors error(s). System requirements not met."
		sleep 0.2
		echo
        confirmation_y_or_n "Do you want to continue anyway (Not Recomended)" continue_install_anyway
		if [[ "$continue_install_anyway" == "n" ]]; then
			trap - SIGINT SIGTSTP
			exit 1
		fi
    fi
}

function print_recomended_msg() {
check_system_requirements
echo
echo "${R}[${C}-${R}]${G}${BOLD} Pre-Installation Requirements${W}"
echo
echo "${G}Essential Steps:${W}"
echo "   • Start with a clean installation"
echo "   • Ensure at least 1GB of available data"
echo "   • Use a stable internet connection or VPN"
echo
echo "${G}Device Settings:${W}"
echo "   • Enable 'Keep screen on' in Termux settings"
if [[ "$android_version" -ge 12 ]]; then
echo "   • Disable Phantom Process Killer (Android 12+ requirement)"
fi
echo
echo "${G}Important Notes:${W}"
echo "   • Keep Termux open during the entire installation"
echo "   • Review all README documentation carefully"
echo
# Re-enable keyboard interruptions
# trap - SIGINT SIGTSTP
# wait_for_keypress
}

function install_required_packages() {
    banner
    echo "${R}[${C}-${R}]${G}${BOLD} Installing required packages...${W}"
    echo

    if [[ "$PACKAGE_MANAGER" == "pacman" ]]; then
        package_install_and_check "wget git pv jq curl termux-am termux-api"
    else
        package_install_and_check "wget git pv jq curl tar xz-utils gzip termux-am x11-repo tur-repo termux-api"
    fi
}

function install_desktop() {
    log_info "Starting desktop installation" "Desktop: $de_name"
    
    banner
    if [[ "$desktop_answer" == "1" ]]; then
        log_info "Installing XFCE4"
        echo "${R}[${C}-${R}]${G}${BOLD} Installing Xfce4 Desktop${W}"
        package_install_and_check "xfce4 xfce4-goodies xfce4-pulseaudio-plugin xfce4-battery-plugin xfce4-docklike-plugin xfce4-notifyd-static"
    elif [[ "$desktop_answer" == "2" ]]; then
        echo "${R}[${C}-${R}]${G}${BOLD} Installing Lxqt Desktop${W}"
        echo
        package_install_and_check "lxqt openbox gtk3 papirus-icon-theme xorg-xsetroot"
    elif [[ "$desktop_answer" == "3" ]]; then
        echo "${R}[${C}-${R}]${G}${BOLD} Installing Openbox WM${W}"
        echo
        package_install_and_check "openbox polybar xorg-xsetroot lxappearance wmctrl feh thunar firefox mpd rofi bmon xcompmgr xfce4-settings gtk3 gedit"
    elif [[ "$desktop_answer" == "4" ]]; then
        echo "${R}[${C}-${R}]${G}${BOLD} Installing MATE${W}"
        echo
        package_install_and_check "mate*"
        package_install_and_check "marco mousepad xfce4-taskmanager lximage-qt"
    fi
	package_install_and_check "kvantum xwayland pulseaudio file-roller pavucontrol gnome-font-viewer atril galculator gdk-pixbuf libwayland-protocols xorg-xrdb"
    # Uncomment if additional package installation is needed
    # if [[ "$distro_add_answer" == "y" ]]; then
    #     package_install_and_check "xdg-utils"
    # fi

    log_info "Desktop installation process done"
}

#########################################################################
#
# Theme Installer
#
#########################################################################
function set_config_dir() {
	if [[ "$de_name" == "xfce" ]]; then
	config_dirs=(autostart cairo-dock eww picom dconf gtk-3.0 Mousepad pulse Thunar menu ristretto rofi xfce4)
	elif [[ "$de_name" == "lxqt" ]]; then
	config_dirs=(fontconfig gtk-3.0 lxqt pcmanfm-qt QtProject.conf glib-2.0 Kvantum openbox qterminal.org)
	elif [[ "$de_name" == "openbox" ]]; then
	config_dirs=(dconf gedit Kvantum openbox pulse rofi xfce4 enchant gtk-3.0 mimeapps.list polybar QtProject.conf Thunar)
	elif [[ "$de_name" == "mate" ]]; then
	config_dirs=(caja dconf galculator gtk-3.0 Kvantum lximage-qt menus Mousepad pavucontrol.ini xfce4)
    fi
}

function theme_installer() {
    log_info "Starting theme installation" "Theme: $style_name"
    banner
    echo "${R}[${C}-${R}]${G}${BOLD} Configuring Theme: ${C}${style_name}${W}"
    echo

    if [[ "$de_name" == "xfce" ]] || [[ "$de_name" == "openbox" ]]; then
        package_install_and_check "gnome-themes-extra gtk2-engines-murrine"
    fi

    sleep 3
    banner
    echo "${R}[${C}-${R}]${G}${BOLD} Configuring Wallpapers...${W}"
    echo
    check_and_create_directory "$PREFIX/share/backgrounds"
    download_and_extract "https://raw.githubusercontent.com/sabamdarif/termux-desktop/refs/heads/setup-files/setup-files/${de_name}/look_${style_answer}/wallpaper.tar.gz" "$PREFIX/share/backgrounds/"

    banner
    check_and_create_directory "$icons_folder"
    download_and_extract "https://raw.githubusercontent.com/sabamdarif/termux-desktop/refs/heads/setup-files/setup-files/${de_name}/look_${style_answer}/icon.tar.gz" "$icons_folder"

    if [[ "$de_name" == "xfce" ]]; then
        local icons_themes_names
		icons_themes_names=$(ls "$icons_folder")
        local icons_theme
        for icons_theme in $icons_themes_names; do
            if [[ -d "$icons_folder/$icons_theme" ]]; then
                echo "${R}[${C}-${R}]${G} Creating icon cache...${W}"
                gtk-update-icon-cache -f -t "$icons_folder/$icons_theme"
            fi
        done
    fi

    local sys_icons_themes_names
	sys_icons_themes_names=$(ls "$PREFIX/share/icons")
    local sys_icons_theme
    for sys_icons_theme in $sys_icons_themes_names; do
        if [[ -d "$sys_icons_folder/$sys_icons_theme" ]]; then
            echo "${R}[${C}-${R}]${G} Creating icon cache...${W}"
            gtk-update-icon-cache -f -t "$sys_icons_folder/$sys_icons_theme"
        fi
    done

    echo "${R}[${C}-${R}]${G}${BOLD} Installing Theme...${W}"
    echo
    check_and_create_directory "$themes_folder"
    download_and_extract "https://raw.githubusercontent.com/sabamdarif/termux-desktop/refs/heads/setup-files/setup-files/${de_name}/look_${style_answer}/theme.tar.gz" "$themes_folder"

    echo "${R}[${C}-${R}]${G} Making Additional Configuration...${W}"
    echo
    check_and_create_directory "$HOME/.config"
    set_config_dir

    for the_config_dir in "${config_dirs[@]}"; do
        check_and_delete "$HOME/.config/$the_config_dir"
    done

    if [[ "$de_name" == "openbox" ]]; then
        download_and_extract "https://raw.githubusercontent.com/sabamdarif/termux-desktop/refs/heads/setup-files/setup-files/${de_name}/look_${style_answer}/config.tar.gz" "$HOME"
    else
        download_and_extract "https://raw.githubusercontent.com/sabamdarif/termux-desktop/refs/heads/setup-files/setup-files/${de_name}/look_${style_answer}/config.tar.gz" "$HOME/.config/"
    fi

    if [ $? -ne 0 ]; then
        log_error "Theme installation failed" "Theme: $style_name"
    else
        log_info "Theme installation completed successfully"
    fi
}

#########################################################################
#
# Install Additional Packages For Setup
#
#########################################################################

function additional_required_steps() {
    banner
	if [[ "$de_name" == "xfce" ]]; then
    echo "${R}[${C}-${R}]${G}${BOLD} Installing Additional Packages If Required...${W}"
	echo
		if [[ "$style_answer" == "4" ]] || [[ "$style_answer" == "5" ]]; then
		install_font_for_style "${style_answer}"
		fi
		if [[ "$style_answer" == "5" ]]; then
		package_install_and_check "eww"
		fi
	elif [[ "$de_name" == "openbox" ]]; then
	    if [[ "$style_answer" == "1" ]]; then
	    install_font_for_style "1"
		else
		echo "${R}[${C}-${R}]${G} No Additional Packages Required For Theme: ${style_answer}${W}"
	    sleep 1
	    fi
	fi
}

#########################################################################
#
# Setup Selected Style And Wallpapers
#
#########################################################################

function setup_config() {
	cd "$HOME" || return
	if [[ ${style_answer} =~ ^[1-9][0-9]*$ ]]; then
	banner
	echo "${R}[${C}-${R}]${G}${BOLD} Installing $de_name Style: ${C}${style_answer}${W}"
	theme_installer
	additional_required_steps
	else
	print_failed "Failed to select style..."
	fi
	if [[ "$ext_wall_answer" == "n" ]]; then
	echo "${R}[${C}-${R}]${C} Skipping Extra Wallpapers Setup...${W}"
	echo
	elif [[ "$ext_wall_answer" == "y" ]]; then
	echo "${R}[${C}-${R}]${G}${BOLD} Installing Some Extra Wallpapers...${W}"
	echo
	check_and_create_directory "$PREFIX/share/backgrounds"
	download_and_extract "https://archive.org/download/wallpaper-extra.tar/wallpaper-extra.tar.gz" "$PREFIX/share/backgrounds/"
	fi
}

function setup_folder() {
	banner
	echo "${R}[${C}-${R}]${G}${BOLD} Configuring Storage...${W}"
	echo
	while true; do
	termux-setup-storage
	sleep 4
    if [[ -d ~/storage ]]; then
	break
    else
	print_failed "Storage permission denied"
    fi
    sleep 3
	done
	cd "$HOME" || return
	termux-reload-settings
	directories=(Music Download Pictures Videos)
	for dir in "${directories[@]}"; do
	check_and_create_directory "/sdcard/$dir"
	done
	check_and_create_directory "$HOME/Desktop"
	ln -s "$HOME/storage/shared/Music" "$HOME/"
	ln -s "$HOME/storage/shared/Download" "$HOME/Downloads"
	ln -s "$HOME/storage/shared/Pictures" "$HOME/"
	ln -s "$HOME/storage/shared/Videos" "$HOME/"
}

#########################################################################
#
# Hardware Acceleration Setup
#
#########################################################################

# setup hardware acceleration, check if the enable-hw-acceleration already exist then then first check if it different from github , then ask user if they want to replace it or not, if not then continue with the lacal enable-hw-acceleration file
function hw_config() {
    banner
    echo "${R}[${C}-${R}]${G}${BOLD} Configuring Hardware Acceleration${W}"
    echo

    if [[ -f ${current_path}/enable-hw-acceleration ]]; then
        local current_script_hash
        current_script_hash=$(curl -sL https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/enable-hw-acceleration | sha256sum | cut -d ' ' -f 1)
        local local_script_hash
        local_script_hash=$(sha256sum "${current_path}/enable-hw-acceleration" | cut -d ' ' -f 1)

        if [[ "$local_script_hash" != "$current_script_hash" ]]; then
            echo "${R}[${C}-${R}]${G} A different version of the hardware acceleration installer is detected.${W}"
            echo

            confirmation_y_or_n "Do you want to replace it with the latest version?" change_old_hw_installer

            if [[ "$change_old_hw_installer" == "y" ]]; then
                check_and_backup "${current_path}/enable-hw-acceleration"
                download_file "${current_path}/enable-hw-acceleration" https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/enable-hw-acceleration
				chmod +x "${current_path}/enable-hw-acceleration"
                . "${current_path}"/enable-hw-acceleration
            else
                echo "${R}[${C}-${R}]${G} Using the local hardware acceleration setup file.${W}"
                chmod +x "${current_path}/enable-hw-acceleration"
                . "${current_path}"/enable-hw-acceleration
            fi

            print_to_config "change_old_hw_installer"
        else
            echo "${R}[${C}-${R}]${G} Using the local hardware acceleration setup file.${W}"
            chmod +x "${current_path}/enable-hw-acceleration"
            . "${current_path}"/enable-hw-acceleration
        fi
    else
        download_file "${current_path}/enable-hw-acceleration" https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/enable-hw-acceleration
		chmod +x "${current_path}/enable-hw-acceleration"
        . "${current_path}"/enable-hw-acceleration
    fi

    check_and_delete "${current_path}/enable-hw-acceleration"
	print_log "$current_path $current_script_hash $local_script_hash"
}

#########################################################################
#
# Proot Distro Setup
#
#########################################################################

# same as the hardware acceleration setup but for distro-container-setup file
function distro_container_setup() {
    if [[ "$distro_add_answer" == "n" ]]; then
        banner
        echo "${R}[${C}-${R}]${C} Skipping Linux Distro Container Setup...${W}"
        echo
		if [[ "$enable_hw_acc" == "y" ]]; then
        	hw_config
		fi
    else
        banner
        echo "${R}[${C}-${R}]${G}${BOLD} Configuring Linux Distro Container${W}"
        echo

        if [[ -f "${current_path}/distro-container-setup" ]]; then
            local current_script_hash
            current_script_hash=$(curl -sL https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/distro-container-setup | sha256sum | cut -d ' ' -f 1)
            local local_script_hash
            local_script_hash=$(basename "$(sha256sum "${current_path}/distro-container-setup" | cut -d ' ' -f 1)")

            if [[ "$local_script_hash" != "$current_script_hash" ]]; then
                echo "${R}[${C}-${R}]${G} It looks like you already have a different distro-container setup script in your current directory${W}"
                echo
                confirmation_y_or_n "Do you want to change it with the latest installer" change_old_distro_installer

                if [[ "$change_old_distro_installer" == "y" ]]; then
                    check_and_backup "${current_path}/distro-container-setup"
                    download_file "${current_path}/distro-container-setup" "https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/distro-container-setup"

                    chmod +x "${current_path}/distro-container-setup"
                    . "${current_path}/distro-container-setup"
                else
                    echo "${R}[${C}-${R}]${G} Using the local distro-container setup file${W}"
                    chmod +x "${current_path}/distro-container-setup"
                    . "${current_path}/distro-container-setup"
                fi

                print_to_config "change_old_distro_installer"
            else
                echo "${R}[${C}-${R}]${G} Using the local distro-container setup file${W}"
                chmod +x "${current_path}/distro-container-setup"
                . "${current_path}/distro-container-setup"
            fi
        else
            download_file "${current_path}/distro-container-setup" "https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/distro-container-setup"

            # Check if arguments are passed
            if [[ ("$1" == "--change" || "$1" == "-c") && ("$2" == "distro" || "$2" == "pd") ]]; then
                sed -i 's/\(call_from_change_d="\)[^"]*/\1y/' "${current_path}/distro-container-setup"
            fi

            chmod +x "${current_path}/distro-container-setup"
            . "${current_path}/distro-container-setup"
        fi
	check_and_delete "${current_path}/distro-container-setup"
    fi

    print_to_config "distro_add_answer"
	print_log "$current_path $distro_add_answer $local_script_hash"
}

#########################################################################
#
# Vnc | Termux:x11 | Launch Scripts
#
#########################################################################

function setup_vncstart_cmd() {
    check_and_delete "$PREFIX/bin/vncstart"
if [[ "$enable_hw_acc" == "n" ]]; then
cat <<EOF > "$PREFIX/bin/vncstart"
#!/data/data/com.termux/files/usr/bin/bash

termux-wake-lock

vnc_server_pid=\$(pgrep -f "vncserver")
de_pid=\$(pgrep -f "$de_startup")
if [[ -n "\$de_pid" ]] || [[ -n "\$vnc_server_pid" ]]>/dev/null 2>&1; then
vncstop -f
fi

pulseaudio --start --exit-idle-time=-1

case \$1 in
--help|-h)
echo "${C}vncstart ${G}to start vncserver with gpu acceleration${W}"
echo "${C}vncstart ---nogpu ${G}to start vncserver without gpu acceleration${W}"
;;
*)
env XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg vncserver
;;
esac
EOF
elif [[ "$enable_hw_acc" == "y" ]]; then
cat <<EOF > "$PREFIX/bin/vncstart"
#!/data/data/com.termux/files/usr/bin/bash

termux-wake-lock

vnc_server_pid=\$(pgrep -f "vncserver")
de_pid=\$(pgrep -f "$de_startup")
if [[ -n "\$de_pid" ]] || [[ -n "\$vnc_server_pid" ]]>/dev/null 2>&1; then
vncstop -f
fi

pulseaudio --start --exit-idle-time=-1

case \$1 in
--nogpu)
env XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe GALLIUM_DRIVER=llvmpipe vncserver
;;
--help|-h)
echo "${C}vncstart ${G}to start vncserver with gpu acceleration${W}"
echo "${C}vncstart ---nogpu ${G}to start vncserver without gpu acceleration${W}"
;;
*)
export ${set_to_export}
${initialize_server_method} &
env XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg $hw_method vncserver
;;
esac
EOF
fi
    chmod +x "$PREFIX/bin/vncstart"
}

function setup_vncstop_cmd() {
    check_and_delete "$PREFIX/bin/vncstop"
cat <<'EOF' > "$PREFIX/bin/vncstop"
#!/data/data/com.termux/files/usr/bin/bash

termux-wake-unlock

if [[ "$1" == "-f" ]]; then
pkill -9 Xtigervnc > /dev/null 2>&1
else
display_numbers=$(vncserver -list | awk '/^:[0-9]+/ {print $1}')

for display in $display_numbers; do
    vncserver -kill "$display"
done
fi
rm $HOME/.vnc/localhost:*.log > /dev/null 2>&1
rm $PREFIX/tmp/.X1-lock > /dev/null 2>&1
rm $PREFIX/tmp/.X11-unix/X1 > /dev/null 2>&1
EOF
    chmod +x "$PREFIX/bin/vncstop"
}

function setup_vnc() {
    banner
    echo "${R}[${C}-${R}]${G}${BOLD} Configuring Vnc...${W}"
    echo
    package_install_and_check "tigervnc"
    check_and_create_directory "$HOME/.vnc"
    check_and_delete "$HOME/.vnc/xstartup"
cat << EOF > "$HOME/.vnc/xstartup"
    $de_startup &
EOF
    chmod +x "$HOME/.vnc/xstartup"
	setup_vncstart_cmd
	setup_vncstop_cmd
}

function setup_tx11start_cmd() {
	check_and_delete "$PREFIX/bin/tx11start"
if [[ "$enable_hw_acc" == "y" ]]; then
cat <<EOF > "$PREFIX/bin/tx11start"
#!/data/data/com.termux/files/usr/bin/bash

termux-wake-lock

termux_x11_pid=\$(pgrep -f "app_process -Xnoimage-dex2oat / com.termux.x11.Loader :${display_number}")
de_pid=\$(pgrep -f "$de_startup")
if [ -n "\$termux_x11_pid" ] || [ -n "\$de_pid" ] >/dev/null 2>&1; then
pkill -f com.termux.x11 > /dev/null 2>&1
kill -9 \$de_pid > /dev/null 2>&1
fi

pulseaudio --start --exit-idle-time=-1

###########################################################
#                                                         #
#************************* Debug *************************#
#                                                         #
###########################################################

if [[ "\$1" == "--debug" ]]; then
case \$2 in
--nogpu)
    # Start Termux X11 without GPU acceleration
    XDG_RUNTIME_DIR=\${TMPDIR} TERMUX_X11_DEBUG=1 termux-x11 :${display_number} &
    sleep 1
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
    sleep 1
    env DISPLAY=:${display_number} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe GALLIUM_DRIVER=llvmpipe dbus-launch --exit-with-session $de_startup

    # Check if the second argument is --legacy
    if [[ "\$3" == "--legacy" ]]; then
        XDG_RUNTIME_DIR=\${TMPDIR} TERMUX_X11_DEBUG=1 termux-x11 :${display_number} -legacy-drawing &
        sleep 1
        am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
        sleep 1
        env DISPLAY=:${display_number} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} dbus-launch --exit-with-session $de_startup
    fi
    ;;

--nodbus)
    # Start Termux X11 without dbus-launch
	export ${set_to_export}
	${initialize_server_method} &
    env XDG_RUNTIME_DIR=\${TMPDIR} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} ${hw_method} TERMUX_X11_DEBUG=1 termux-x11 :${display_number} -xstartup $de_startup
    exit 0

    # Nested case to check for additional options
    case \$3 in
    --nogpu)
        env LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe GALLIUM_DRIVER=llvmpipe XDG_RUNTIME_DIR=\${TMPDIR} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} TERMUX_X11_DEBUG=1 termux-x11 :${display_number} -xstartup $de_startup

        if [[ "\$4" == "--legacy" ]]; then
            env XDG_RUNTIME_DIR=\${TMPDIR} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} TERMUX_X11_DEBUG=1 termux-x11 :${display_number} -legacy-drawing -xstartup $de_startup
        fi
        ;;
    --legacy)
	export ${set_to_export}
	${initialize_server_method} &
        env XDG_RUNTIME_DIR=\${TMPDIR} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} ${hw_method} TERMUX_X11_DEBUG=1 termux-x11 :${display_number} -legacy-drawing -xstartup $de_startup
        ;;
    *)
        echo -e "${C}--legacy ${G}to start termux:x11 with -legacy-drawing${W}"
        echo -e "${C}--nogpu ${G}to start termux:x11 without GPU acceleration${W}"
        exit 0
        ;;
    esac
    ;;

--legacy)
    # Start Termux X11 with legacy drawing mode
	export ${set_to_export}
	${initialize_server_method} &
    sleep 1
    XDG_RUNTIME_DIR=\${TMPDIR} TERMUX_X11_DEBUG=1 termux-x11 :${display_number} -legacy-drawing &
    sleep 1
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1 &
    sleep 1
    env DISPLAY=:${display_number} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} ${hw_method} dbus-launch --exit-with-session $de_startup
    ;;

*)
    # Default behavior: start Termux X11 with GPU acceleration and dbus
	export ${set_to_export}
	${initialize_server_method} &
    sleep 1
    XDG_RUNTIME_DIR=\${TMPDIR} TERMUX_X11_DEBUG=1 termux-x11 :${display_number} &
    sleep 1
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1 &
    sleep 1
    env DISPLAY=:${display_number} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} ${hw_method} dbus-launch --exit-with-session $de_startup
    ;;
esac

elif [[ "\$1" == "--help" ]]; then

###########################################################
#                                                         #
#************************** Help *************************#
#                                                         #
###########################################################

    # Display help information
    echo -e "${C}tx11start ${G}to start termux:x11 with GPU acceleration${W}"
    echo -e "${C}tx11start --nogpu ${G}to start termux:x11 without GPU acceleration${W}"
    echo -e "${C}tx11start --nodbus ${G}to start termux:x11 without dbus${W}"
    echo -e "${C}tx11start --legacy ${G}to start termux:x11 with -legacy-drawing${W}"
	echo -e "${C}tx11start --debug ${G}at the start to see debug log${W}"
    exit 0
else

###########################################################
#                                                         #
#************************* Main **************************#
#                                                         #
###########################################################

case \$1 in
--nogpu)
    # Start Termux X11 without GPU acceleration
    XDG_RUNTIME_DIR=\${TMPDIR} termux-x11 :${display_number} &
    sleep 1
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
    sleep 1
    env DISPLAY=:${display_number} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe GALLIUM_DRIVER=llvmpipe dbus-launch --exit-with-session $de_startup > /dev/null 2>&1 &

    # Check if the second argument is --legacy
    if [[ "\$2" == "--legacy" ]]; then
        XDG_RUNTIME_DIR=\${TMPDIR} termux-x11 :${display_number} -legacy-drawing &
        sleep 1
        am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
        sleep 1
        env DISPLAY=:${display_number} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} dbus-launch --exit-with-session $de_startup > /dev/null 2>&1 &
    fi
    ;;

--nodbus)
    # Start Termux X11 without dbus-launch
	export ${set_to_export}
	${initialize_server_method} &
    env XDG_RUNTIME_DIR=\${TMPDIR} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} ${hw_method} termux-x11 :${display_number} -xstartup $de_startup > /dev/null 2>&1 &
    exit 0

    # Nested case to check for additional options
    case \$2 in
    --nogpu)
        env LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe GALLIUM_DRIVER=llvmpipe XDG_RUNTIME_DIR=\${TMPDIR} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} termux-x11 :${display_number} -xstartup $de_startup > /dev/null 2>&1 &

        if [[ "\$3" == "--legacy" ]]; then
            env XDG_RUNTIME_DIR=\${TMPDIR} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} termux-x11 :${display_number} -legacy-drawing -xstartup $de_startup > /dev/null 2>&1 &
        fi
        ;;
    --legacy)
	export ${set_to_export}
	${initialize_server_method} &
        env XDG_RUNTIME_DIR=\${TMPDIR} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} ${hw_method} termux-x11 :${display_number} -legacy-drawing -xstartup $de_startup > /dev/null 2>&1 &
        ;;
    *)
        echo -e "${C}--legacy ${G}to start termux:x11 with -legacy-drawing${W}"
        echo -e "${C}--nogpu ${G}to start termux:x11 without GPU acceleration${W}"
        exit 0
        ;;
    esac
    ;;

--legacy)
    # Start Termux X11 with legacy drawing mode
	export ${set_to_export}
	${initialize_server_method} &
    sleep 1
    XDG_RUNTIME_DIR=\${TMPDIR} termux-x11 :${display_number} -legacy-drawing &
    sleep 1
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1 &
    sleep 1
    env DISPLAY=:${display_number} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} ${hw_method} dbus-launch --exit-with-session $de_startup > /dev/null 2>&1 &
    ;;
*)
    # Default behavior: start Termux X11 with GPU acceleration and dbus
	export ${set_to_export}
	${initialize_server_method} &
    sleep 1
    XDG_RUNTIME_DIR=\${TMPDIR} termux-x11 :${display_number} &
    sleep 1
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1 &
    sleep 1
    env DISPLAY=:${display_number} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg ${gpu_environment_variable} ${hw_method} dbus-launch --exit-with-session $de_startup > /dev/null 2>&1 &
    ;;
esac
fi
EOF

elif [[ "$enable_hw_acc" == "n" ]]; then
cat <<EOF > "$PREFIX/bin/tx11start"
#!/data/data/com.termux/files/usr/bin/bash

termux-wake-lock

termux_x11_pid=\$(pgrep -f "app_process -Xnoimage-dex2oat / com.termux.x11.Loader :${display_number}")
de_pid=\$(pgrep -f "$de_startup")
if [ -n "\$termux_x11_pid" ] || [ -n "\$de_pid" ] >/dev/null 2>&1; then
pkill -f com.termux.x11 > /dev/null 2>&1
kill -9 \$de_pid > /dev/null 2>&1
fi

pulseaudio --start --exit-idle-time=-1

###########################################################
#                                                         #
#************************* Debug *************************#
#                                                         #
###########################################################

if [[ "\$1" == "--debug" ]]; then
case \$2 in
--nodbus)
    # Start Termux X11 without dbus-launch
    env XDG_RUNTIME_DIR=\${TMPDIR} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg TERMUX_X11_DEBUG=1 termux-x11 :${display_number} -xstartup $de_startup
    exit 0

    # Nested case to check for additional options
    case \$3 in
    --legacy)
        env XDG_RUNTIME_DIR=\${TMPDIR} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg TERMUX_X11_DEBUG=1 termux-x11 :${display_number} -legacy-drawing -xstartup $de_startup
        ;;
    *)
        echo -e "${C}--legacy ${G}to start termux:x11 with -legacy-drawing${W}"
        exit 0
        ;;
    esac
    ;;

--legacy)
    # Start Termux X11 with legacy drawing mode
    XDG_RUNTIME_DIR=\${TMPDIR} TERMUX_X11_DEBUG=1 termux-x11 :${display_number} -legacy-drawing &
    sleep 1
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1 &
    sleep 1
    env DISPLAY=:${display_number} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg dbus-launch --exit-with-session $de_startup
    ;;

*)
    # Default behavior: start Termux X11 with GPU acceleration and dbus
    XDG_RUNTIME_DIR=\${TMPDIR} TERMUX_X11_DEBUG=1 termux-x11 :${display_number} &
    sleep 1
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1 &
    sleep 1
    env DISPLAY=:${display_number} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg dbus-launch --exit-with-session $de_startup
    ;;
esac

elif [[ "\$1" == "--help" ]]; then

###########################################################
#                                                         #
#************************** Help *************************#
#                                                         #
###########################################################

    # Display help information
    echo -e "${C}tx11start ${G}to start termux:x11 with GPU acceleration${W}"
    echo -e "${C}tx11start --nodbus ${G}to start termux:x11 without dbus${W}"
    echo -e "${C}tx11start --legacy ${G}to start termux:x11 with -legacy-drawing${W}"
	echo -e "${C}tx11start --debug ${G}at the start to see debug log${W}"
    exit 0
else

###########################################################
#                                                         #
#************************* Main **************************#
#                                                         #
###########################################################

case \$1 in

--nodbus)
    # Start Termux X11 without dbus-launch
    env XDG_RUNTIME_DIR=\${TMPDIR} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg termux-x11 :${display_number} -xstartup $de_startup > /dev/null 2>&1 &
    exit 0

    # Nested case to check for additional options
    case \$2 in
    --legacy)
        env XDG_RUNTIME_DIR=\${TMPDIR} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg termux-x11 :${display_number} -legacy-drawing -xstartup $de_startup > /dev/null 2>&1 &
        ;;
    *)
        echo -e "${C}--legacy ${G}to start termux:x11 with -legacy-drawing${W}"
        exit 0
        ;;
    esac
    ;;

--legacy)
    # Start Termux X11 with legacy drawing mode
    XDG_RUNTIME_DIR=\${TMPDIR} termux-x11 :${display_number} -legacy-drawing &
    sleep 1
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1 &
    sleep 1
    env DISPLAY=:${display_number} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg dbus-launch --exit-with-session $de_startup > /dev/null 2>&1 &
    ;;
*)
    # Default behavior: start Termux X11 without acceleration and dbus
    XDG_RUNTIME_DIR=\${TMPDIR} termux-x11 :${display_number} &
    sleep 1
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1 &
    sleep 1
    env DISPLAY=:${display_number} XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg dbus-launch --exit-with-session $de_startup > /dev/null 2>&1 &
    ;;
esac
fi
EOF

fi

if [[ "$de_name" == "xfce" ]]; then
cat <<'EOF' >> "$PREFIX/bin/tx11start"
sleep 5
process_id=$(ps -aux | grep '[x]fce4-screensaver' | awk '{print $2}')
kill "$process_id" > /dev/null 2>&1
EOF
fi
chmod +x "$PREFIX/bin/tx11start"
}

function setup_tx11stop_cmd() {
	check_and_delete "$PREFIX/bin/tx11stop"
if [[ "$de_name" == "openbox" ]]; then
cat <<EOF > "$PREFIX/bin/tx11stop"
#!/data/data/com.termux/files/usr/bin/bash

termux-wake-unlock

termux_x11_pid=\$(pgrep -f "/system/bin/app_process / com.termux.x11.Loader :${display_number}")
de_pid=\$(pgrep -f $de_startup)
if [[ -n "\$termux_x11_pid" ]] || [[ -n "\$de_pid" ]]; then
kill -9 "\$termux_x11_pid" > /dev/null 2>&1
pkill -9 pulseaudio > /dev/null 2>&1
killall virgl_test_server > /dev/null 2>&1
pkill -9 openbox* > /dev/null 2>&1
pkill -9 dbus-* > /dev/null 2>&1
pkill -f com.termux.x11 > /dev/null 2>&1
sleep 1
	if [[ ! -n "\$termux_x11_pid" ]] || [[ ! -n "\$de_pid" ]]; then
	echo -e "${G}Termux:X11 Stopped Successfully ${W}"
	fi
elif [[ "\$1" == "-f" ]]; then
pkill -f com.termux.x11 > /dev/null 2>&1
pkill -9 openbox* > /dev/null 2>&1
killall virgl_test_server > /dev/null 2>&1
pkill -9 pulseaudio > /dev/null 2>&1
pkill -9 dbus-* > /dev/null 2>&1
echo -e "${G}Termux:X11 Successfully Force Stopped ${W}"
elif [[ "\$1" == "-h" ]]; then
echo -e "tx11stop       to stop termux:x11"
echo -e "tx11stop -f    to kill termux:x11"
fi
exec 2>/dev/null
EOF
else
cat <<EOF > "$PREFIX/bin/tx11stop"
#!/data/data/com.termux/files/usr/bin/bash

termux-wake-unlock

termux_x11_pid=\$(pgrep -f "/system/bin/app_process / com.termux.x11.Loader :${display_number}")
de_pid=\$(pgrep -f $de_startup)
if [[ -n "\$termux_x11_pid" ]] || [[ -n "\$de_pid" ]]; then
kill -9 "\$termux_x11_pid" > /dev/null 2>&1
pkill -9 pulseaudio > /dev/null 2>&1
killall virgl_test_server > /dev/null 2>&1
pkill -9 $de_name-* > /dev/null 2>&1
pkill -9 dbus-* > /dev/null 2>&1
pkill -f com.termux.x11 > /dev/null 2>&1
	if [[ ! -n "\$termux_x11_pid" ]] || [[ ! -n "\$de_pid" ]]; then
	echo -e "${G}Termux:X11 Stopped Successfully ${W}"
	fi
elif [[ "\$1" == "-f" ]]; then
pkill -f com.termux.x11 > /dev/null 2>&1
pkill -9 $de_name-* > /dev/null 2>&1
killall virgl_test_server > /dev/null 2>&1
pkill -9 pulseaudio > /dev/null 2>&1
pkill -9 dbus-* > /dev/null 2>&1
echo -e "${G}Termux:X11 Successfully Force Stopped ${W}"
elif [[ "\$1" == "-h" ]]; then
echo -e "tx11stop       to stop termux:x11"
echo -e "tx11stop -f    to kill termux:x11"
fi
exec 2>/dev/null
EOF
fi
chmod +x "$PREFIX/bin/tx11stop"
}

function setup_termux_x11() {
	banner
        echo "${R}[${C}-${R}]${G}${BOLD} Configuring Termux:X11 ${W}"
        echo
        package_install_and_check "termux-x11-nightly"
		local repo_owner="termux"
		local repo_name="termux-x11"
		local latest_tag
		latest_tag=$(get_latest_release "$repo_owner" "$repo_name")
		local termux_x11_url="https://github.com/$repo_owner/$repo_name/releases/download/v$latest_tag/"
		local assets
		assets=$(curl -s "https://api.github.com/repos/$repo_owner/$repo_name/releases/latest" | grep -oP '(?<="name": ")[^"]*')
		deb_assets=$(echo "$assets" | grep "termux-x11.*all.deb")
		download_file "$current_path/termux-x11.deb" "$termux_x11_url/$deb_assets"
		apt install "$current_path/termux-x11.deb" -y
		rm "$current_path/termux-x11.deb"
		# "sed -i '12s/^#//' "$HOME/.termux/termux.properties"
		setup_tx11start_cmd
		setup_tx11stop_cmd
}

function gui_termux_x11() {
cat << EOF > "$PREFIX/bin/gui"
#!/data/data/com.termux/files/usr/bin/bash
case \$1 in
--start|-l)
tx11start
;;
--stop|-s)
tx11stop
;;
--kill|-k|-kill)
tx11stop -f
;;
--help|-h)
echo -e "${G} Use ${C}gui --start / gui -l ${G}to start termux:x11\n Use ${C}gui --stop / gui -s ${G}to stop termux:x11${W}"
;;
*)
echo "${R}Invalid choise${W}"
gui -h
;;
esac
EOF
}

function gui_both() {
cat << EOF > "$PREFIX/bin/gui"
#!/data/data/com.termux/files/usr/bin/bash
case \$1 in
    --start|-l)
        case \$2 in
            tx11)
                tx11start
                ;;
            vnc)
                vncstart
                ;;
            *)
                echo -e "${R}Invalid choise. Use ${C}tx11${R} or ${C}vnc ${G}with it${W}"
                ;;
        esac
        ;;
	--kill|-k|-kill)
	vncstop -f > /dev/null 2>&1
	tx11stop -f > /dev/null 2>&1
	echo -e "${G}Gui services killed successfully ${W}"
	;;
    --stop|-s)
        case \$2 in
            tx11)
                tx11stop
                ;;
            vnc)
                vncstop
                ;;
            *)
                echo -e "${R}Invalid choise. Use ${C}tx11${R} or ${C}vnc ${G}with it${W}"
                ;;
        esac
        ;;
    --help|-h)
        echo -e "${G}Use ${C}gui --start tx11/vnc${G} or ${C}gui -l tx11/vnc${G} to start a gui"
        echo -e "Use ${C}gui --stop tx11/vnc${G} or ${C}gui -s tx11/vnc${G} to stop a gui${W}"
		echo -e "Use ${C}gui --kill ${G} To kill both at once${W}"
        ;;
    *)
        echo -e "${R}Invalid choice${W}"
        gui -h
        ;;
esac
EOF
}

function gui_launcher() {
	check_and_delete "$PREFIX/bin/gui"
	package_install_and_check "xorg-xhost"
	if [[ "$gui_mode" == "termux_x11" ]]; then
	setup_termux_x11
	print_to_config "gui_mode" "termux_x11"
	gui_termux_x11
	elif [[ "$gui_mode" == "both" ]]; then
	setup_termux_x11
	setup_vnc
	print_to_config "gui_mode" "both"
	gui_both
	else
	setup_termux_x11
	print_to_config "gui_mode" "termux_x11"
	gui_termux_x11
	fi
	chmod +x "$PREFIX/bin/gui"
	check_and_create_directory "$PREFIX/share/applications/"
cat <<EOF > "$PREFIX/share/applications/killgui.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Stop Desktop
Comment=Kill or stop termux desktop
Exec=gui --kill
Icon=system-shutdown
Categories=System;
Path=
Terminal=false
StartupNotify=false
EOF
	chmod 644 "$PREFIX/share/applications/killgui.desktop"
	cp "$PREFIX/share/applications/killgui.desktop" "$HOME/Desktop/"
}

function check_desktop_process() {
    banner
    echo "${R}[${C}-${R}]${G} Checking Termux:X11 and $de_name setup or not... ${W}"
    echo
    sleep 0.5
    
    # check tx11start file and start termux x11 to check termux x11 process
    if [[ -f "${PREFIX}/bin/tx11start" ]]; then
        print_status "ok" "Found tx11start file."
        echo "${R}[${C}-${R}]${G} Starting Termux:X11 for checkup...${W}"
    	termux-x11 :${display_number} -xstartup xfce4-session > /dev/null 2>&1 &
		sleep 10
    	print_log "$(cat $PREFIX/bin/tx11start)"
		termux-reload-settings
		local termux_x11_pid
		termux_x11_pid=$(pgrep -f "app_process -Xnoimage-dex2oat / com.termux.x11.Loader :${display_number}")
		if [[ -n "$termux_x11_pid" ]]; then
            print_status "ok" "Termux:X11 Working"
		else
			print_status "error" "No Termux:X11 process found"
		fi

    # check for the desktop environment related process
	local de_pid
	case "$de_name" in
	    xfce)
	        de_pid="$(pgrep xfce4)"
	        ;;
	    lxqt|openbox|mate)
	        de_pid="$(pgrep $de_name)"
	        ;;
	    *)
	        print_status "error" "Unknown desktop environment: $de_name"
	        sleep 0.2
	        return 1
	        ;;
	esac

	if [[ -n "$de_pid" ]]; then
	    print_status "ok" "$de_name is running fine"
	    sleep 0.2
	else
	    print_status "error" "No $de_name process found, attempting to reinstall..."
	    sleep 0.2
	    install_desktop

	    # Check again after installation
		unset de_pid
	    case "$de_name" in
	        xfce)
	            de_pid="$(pgrep xfce4)"
	            ;;
	        lxqt|openbox|mate)
	            de_pid="$(pgrep $de_name)"
	            ;;
	    esac

	    if [[ -n "$de_pid" ]]; then
	        print_status "ok" "$de_name is now running after re-installation"
	        sleep 0.2
	    else
	        print_status "error" "$de_name failed to install or start, still after re-installation"
	        sleep 0.2
	        return 1
	    fi
	fi

    # check tx11stop file and run it to check if there any termux x11 process exist or not
    if [[ -f "${PREFIX}/bin/tx11stop" ]]; then
        print_status "ok" "Found tx11stop file."
        print_log "$(cat $PREFIX/bin/tx11stop)"
		tx11stop -f
        
        # Wait a bit for the process to stop
        sleep 2
        unset termux_x11_pid
        termux_x11_pid=$(pgrep -f "app_process -Xnoimage-dex2oat / com.termux.x11.Loader :${display_number}")
        if [[ -z "$termux_x11_pid" ]]; then
            print_status "ok" "Tx11stop command working"
        else
            print_status "error" "Tx11stop command not working"
        fi
	fi
    fi
}

#########################################################################
#
# Install Browser
#
#########################################################################

function browser_installer() {
	banner
	if [[ ${browser_answer} == "1" ]]; then
	package_install_and_check "firefox"
	print_to_config "installed_browser" "firefox"
	elif [[ ${browser_answer} == "2" ]]; then
	package_install_and_check "chromium"
	print_to_config "installed_browser" "chromium"
	elif [[ ${browser_answer} == "3" ]]; then
	package_install_and_check "firefox chromium"
	print_to_config "installed_browser" "both"
	elif [[ ${browser_answer} == "4" ]]; then
    echo "${R}[${C}-${R}]${C} Skipping Browser Installation...${W}"
	print_to_config "installed_browser" "skip"
	echo
	sleep 2
	else
	package_install_and_check "firefox"
	print_to_config "installed_browser" "firefox"
	fi
}

#########################################################################
#
# Install Ide
#
#########################################################################

function ide_installer() {
	banner
	if [[ ${ide_answer} == "1" ]]; then
		package_install_and_check "code-oss code-is-code-oss"
	print_to_config "installed_ide" "code"
	elif [[ ${ide_answer} == "2" ]]; then
		package_install_and_check "geany"
	print_to_config "installed_ide" "geany"
	elif [[ ${ide_answer} == "3" ]]; then
		package_install_and_check "code-oss code-is-code-oss geany"
	print_to_config "installed_ide" "both"
	elif [[ ${ide_answer} == "4" ]]; then
    echo "${R}[${C}-${R}]${C} Skipping Ide Installation...${W}"
	echo
	print_to_config "installed_ide" "skip"
	sleep 2
	else
		package_install_and_check "code-oss code-is-code-oss"
	print_to_config "installed_ide" "code"
	fi
}

#########################################################################
#
# Install Media Player
#
#########################################################################

function media_player_installer() {
	banner
	if [[ ${player_answer} == "1" ]]; then
		package_install_and_check "vlc-qt-static"
	print_to_config "installed_media_player" "vlc"
	elif [[ ${player_answer} == "2" ]]; then
		package_install_and_check "audacious"
	print_to_config "installed_media_player" "audacious"
	elif [[ ${player_answer} == "3" ]]; then
		package_install_and_check "vlc-qt-static audacious"
	print_to_config "installed_media_player" "both"
	elif [[ ${player_answer} == "4" ]]; then
    echo "${R}[${C}-${R}]${C} Skipping Media Player Installation...${W}"
	echo
	sleep 2
	print_to_config "installed_media_player" "skip"
	else
		package_install_and_check "vlc-qt-static"
	print_to_config "installed_media_player" "vlc"
	fi
}

#########################################################################
#
# Install Photo Editor
#
#########################################################################

function photo_editor_installer() {
	banner
	if [[ ${photo_editor_answer} == "1" ]]; then
		package_install_and_check "gimp"
	print_to_config "installed_photo_editor" "gimp"
	elif [[ ${photo_editor_answer} == "2" ]]; then
		package_install_and_check "inkscape"
	print_to_config "installed_photo_editor" "inkscape"
	elif [[ ${photo_editor_answer} == "3" ]]; then
		package_install_and_check "gimp inkscape"
	print_to_config "installed_photo_editor" "both"
	elif [[ ${photo_editor_answer} == "4" ]]; then
    echo "${R}[${C}-${R}]${C} Skipping Photo Editor Installation...${W}"
	echo
	sleep 2
	print_to_config "installed_photo_editor" "skip"
	else
		package_install_and_check "gimp"
	print_to_config "installed_photo_editor" "gimp"
	fi

}

#########################################################################
#
# Install Software Manager
#
#########################################################################

function install_termux_desktop_appstore() {
    banner
    echo "${R}[${C}-${R}]${C} Setting up AppStore...${W}"
    echo
    echo "${R}[${C}-${R}]${C} Keep in mind that the AppStore is still in the early development stage. Bugs are expected.${W}"
    echo
    sleep 1

    package_install_and_check "aria2 python python3 cloneit"
    check_and_create_directory "${PREFIX}/opt/appstore"
    cd ${PREFIX}/opt/appstore || return
    cloneit https://github.com/sabamdarif/Termux-AppStore/tree/main/src
    cd src || return
    mv -f * ${PREFIX}/opt/appstore/
    cd .. || return
    check_and_delete "src"
    check_and_create_directory "$HOME/.appstore"
    check_and_create_directory "$HOME/.termux_appstore"

    # Install Python dependencies only if not already installed
    echo "${R}[${C}-${R}]${C} Checking Python dependencies...${W}"
    while IFS= read -r module; do
        if [[ -n "$module" && ! "$module" =~ ^[[:space:]]*# ]]; then  # Skip empty lines and comments
            if ! pip show "${module%[>=<]*}" >/dev/null 2>&1; then
                echo "${R}[${C}-${R}]${G} Installing ${module}...${W}"
                pip install "$module" || {
                    print_failed "Failed to install $module. Retrying..."
                    sleep 0.3
                    pip install "$module" || {
                        print_failed "Failed to install $module after retry. Continuing..."
                    }
                }
            else
                echo "${R}[${C}-${R}]${G} ${module%[>=<]*} is already installed${W}"
            fi
        fi
    done < requirements.txt

    # Move desktop file only if it doesn't exist
    if [[ ! -f "${PREFIX}/share/applications/org.sabamdarif.termux.appstore.desktop" ]]; then
        mv -f org.sabamdarif.termux.appstore.desktop "${PREFIX}/share/applications/"
    fi
	if [[ ! -f "/data/data/com.termux/files/home/Desktop/org.sabamdarif.termux.appstore.desktop" ]]; then
        cp "${PREFIX}/share/applications/org.sabamdarif.termux.appstore.desktop" "/data/data/com.termux/files/home/Desktop"
		chmod +x /data/data/com.termux/files/home/Desktop/org.sabamdarif.termux.appstore.desktop
    fi
    chmod +x "${PREFIX}/opt/appstore/inbuild_functions/inbuild_functions"
    cd "${HOME}" || return
}

#########################################################################
#
# Setup Zsh And Terminal and File Manager Utility
#
#########################################################################

function get_shellrc_path() {
	if [[ "$shell_name" == "bash" ]]; then
	shell_rc_file="/data/data/com.termux/files/usr/etc/bash.bashrc"
	elif [[ "$shell_name" == "zsh" ]]; then
	shell_rc_file="$HOME/.zshrc"
	fi
}

function setup_zsh() {
	banner
    if [[ "$zsh_answer" == "n" ]]; then
	echo "${R}[${C}-${R}]${C} Canceling Zsh Setup...${W}"
    sleep 1.5
	shell_name="bash"
	else
	shell_name="zsh"
	echo "${R}[${C}-${R}]${G}${BOLD} Configuring Zsh..${W}"
	echo
	package_install_and_check "zsh git"
	wget --tries=5 --retry-connrefused https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/other/install-zsh.sh
	if [[ "$distro_add_answer" == "y" ]]; then
	banner
	bash install-zsh.sh -u "$user_name"
	else
	banner
	bash install-zsh.sh
	fi
	check_and_delete "install-zsh.sh"
	clear
	fi
	get_shellrc_path
	print_to_config "zsh_answer"
}

function terminal_utility_setup() {
	if [[ "$terminal_utility_setup_answer" == "n" ]]; then
    banner
	echo "${R}[${C}-${R}]${C} Skipping Terminal Utility Setup...${W}"
	echo
	else
	banner
	echo "${R}[${C}-${R}]${C}${BOLD} Configuring Terminal Utility For Termux...${W}"
	echo
	package_install_and_check "bat eza zoxide fastfetch openssh fzf"
	check_and_backup "$PREFIX/etc/motd"
	check_and_backup "$PREFIX/etc/motd-playstore"
    check_and_backup "$PREFIX/etc/motd.sh"
	download_file "$PREFIX/etc/motd.sh" "https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/other/motd.sh"
	if grep -q "motd.sh$" "$PREFIX/etc/termux-login.sh"; then
	sed -i "s|.*motd\.sh$|bash $PREFIX/etc/motd.sh|" "$PREFIX/etc/termux-login.sh"
    else
	echo "bash $PREFIX/etc/motd.sh" >> "$PREFIX/etc/termux-login.sh"
    fi
	check_and_create_directory "$HOME/.termux"
	check_and_backup "$HOME/.termux/colors.properties $HOME/.termux/termux.properties $HOME/.aliases"

	check_and_create_directory "$HOME/.config/fastfetch"
	download_file "$HOME/.config/fastfetch/config.jsonc" "https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/other/config.jsonc" 
	download_file "$HOME/.termux/termux.properties" "https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/other/termux.properties"
	download_file "$HOME/.aliases" "https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/other/.aliases"
	download_file "$HOME/.termux/colors.properties" "https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/other/colors.properties"
	download_file "$PREFIX/bin/termux-ssh" "https://raw.githubusercontent.com/sabamdarif/simple-linux-scripts/main/termux-ssh" && chmod +x "$PREFIX/bin/termux-ssh"
	cp "$shell_rc_file" "${shell_rc_file}-2"
	check_and_backup "$shell_rc_file"
	mv "${shell_rc_file}-2" "${shell_rc_file}"
cat <<'EOF' >> "$shell_rc_file"
#######################################################
# SPECIAL FUNCTIONS
#######################################################
# Extracts any archive(s)
extract() {
	for archive in "$@"; do
    if [[ ! -f "$archive" ]]; then
        echo "Error: '$archive' does not exist!"
        continue
    fi

    total_size=$(stat -c '%s' "$archive")

    case "$archive" in
        *.tar.gz|*.tgz)
            pv -s "$total_size" "$archive" | tar xzf -
            ;;
        *.tar.xz)
            pv -s "$total_size" "$archive" | tar xJf -
            ;;
        *.tar.bz2|*.tbz2)
            pv -s "$total_size" "$archive" | tar xjf -
            ;;
        *.tar)
            pv -s "$total_size" "$archive" | tar xf -
            ;;
        *.bz2)
            pv -s "$total_size" "$archive" | bunzip2 > "${archive%.bz2}"
            ;;
        *.gz)
            pv -s "$total_size" "$archive" | gunzip > "${archive%.gz}"
            ;;
        *.7z)
            pv -s "$total_size" "$archive" | 7z x -si -y > /dev/null
            ;;
        *.rar)
            pv -s "$total_size" "$archive" | unrar x -
            ;;
        *.zip)
            pv -s "$total_size" "$archive" | unzip -
            ;;
        *.Z)
            pv -s "$total_size" "$archive" | uncompress -
            ;;
        *)
            echo "Unsupported archive format: $archive"
            ;;
    esac
	done
}
# Searches for text in all files in the current folder
ftext() {
	# -i case-insensitive
	# -I ignore binary files
	# -H causes filename to be printed
	# -r recursive search
	# -n causes line number to be printed
	# optional: -F treat search term as a literal, not a regular expression
	# optional: -l only print filenames and not the matching lines ex. grep -irl "$1" *
	grep -iIHrn --color=always "$1" . | less -r
}
# Copy and go to the directory
cpg() {
	if [ -d "$2" ]; then
		cp "$1" "$2" && cd "$2"
	else
		cp "$1" "$2"
	fi
}
# Move and go to the directory
mvg() {
	if [ -d "$2" ]; then
		mv "$1" "$2" && cd "$2"
	else
		mv "$1" "$2"
	fi
}
# Create and go to the directory
mkdirg() {
	mkdir -p "$1"
	cd "$1"
}
EOF
cat <<EOF >> "$shell_rc_file"
# set zoxide as cd
eval "\$(zoxide init --cmd cd ${shell_name})"
source $HOME/.aliases
EOF
	fi
cat <<EOF >> "$shell_rc_file"
# print your current termux-desktop configuration
alias 'tdconfig'='cat "$config_file"'
EOF
if [[ "$distro_add_answer" == "y" ]]; then
cat <<EOF >> "$shell_rc_file"
# open the folder where all the apps added by proot-distro are located
alias 'pdapps'='cd /data/data/com.termux/files/usr/share/applications/pd_added && ls'
EOF
fi
print_to_config "terminal_utility_setup_answer"
}

function install_fm_tools() {
    if [[ "$fm_tools" == "y" ]]; then
        banner
        echo "${R}[${C}-${R}]${G}${BOLD} Installing File Manager Tools...${W}"
        check_and_backup "$HOME/.local/share/nautilus/scripts"
        check_and_create_directory "$HOME/.local/share/nautilus/scripts"
        
        # Clone repository
        cd "$HOME"
        git clone https://github.com/sabamdarif/nautilus-scripts
        cd nautilus-scripts
        
        # Download required files
        if ! wget --tries=5 --retry-connrefused https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/patches/fix-nautilus-scripts.patch; then
            print_failed "Failed to download the patch file"
        fi
		patch -p1 < fix-nautilus-scripts.patch
        # Cleanup
        check_and_delete "fix-nautilus-scripts.patch"
        rm -rf 'Security and recovery'
        find . -type f -name "*.orig" -exec rm -f {} \;
        find . -type f -name "*.rej" -exec rm -f {} \;
        # Run setup script and move files
		wget --tries=5 --retry-connrefused https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/other/setup-termux.sh
        bash setup-termux.sh
        cd "$HOME"
        check_and_delete "nautilus-scripts"
    fi
}

#########################################################################
#
# Install Fonts
#
#########################################################################

function setup_fonts() {
	if [[ "$terminal_utility_setup_answer" == "y" ]]; then
	banner
	echo "${R}[${C}-${R}]${G}${BOLD} Installing Fonts...${W}"
	package_install_and_check "nerdfix fontconfig-utils"
	check_and_create_directory "$HOME/.termux"
	check_and_create_directory "$HOME/.fonts"
	check_and_backup "$HOME/.termux/font.ttf"
	download_and_extract "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/0xProto.zip" "$HOME/.fonts"
	clear
	check_and_delete "$HOME/.fonts/README.md $HOME/.fonts/LICENSE"
	cp "$HOME/.fonts/0xProtoNerdFont-Regular.ttf" "$HOME/.termux/font.ttf"
	fc-cache -f
	fi
}

#########################################################################
#
# Install Wine
#
#########################################################################

function run_wine_shortcut_script() {
	download_file "${current_path}/add-wine-shortcut" https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/other/add-wine-shortcut
	chmod +x "${current_path}/add-wine-shortcut"
    . ${current_path}/add-wine-shortcut
	check_and_delete "add-wine-shortcut"
}

function setup_wine() {
	banner
    if [[ "$wine_answer" == "1" ]]; then
	echo "${R}[${C}-${R}]${G}${BOLD} Installing Wine Natively In Termux${W}"
	echo
	package_install_and_check "wine-stable winetricks"
	run_wine_shortcut_script
	print_to_config "setup_wine" "default-wine"
	elif [[ "$wine_answer" == "2" ]]; then
	echo "${R}[${C}-${R}]${G}${BOLD} Addind Mobox Launch Option To Termux${W}"
	echo
	echo "${R}[${C}-${R}]${C}${BOLD} After the installation finishes, make sure to install Mobox using their official instructions${W}"
	echo
	echo "${R}[${C}-${R}]${G}${BOLD} Mobox:- ${C}https://github.com/olegos2/mobox${W}"
	echo
	sleep 4
	download_file "$PREFIX/bin/wine" "https://raw.githubusercontent.com/LinuxDroidMaster/Termux-Desktops/main/scripts/termux_native/mobox_run.sh"
	chmod +x "$PREFIX/bin/wine"
	run_wine_shortcut_script
	cp "$PREFIX/share/applications/wine-explorer.desktop" "$HOME/Desktop/MoboxExplorer.desktop"
	print_to_config "setup_wine" "mobox"
	elif [[ "$wine_answer" == "3" ]]; then
	package_install_and_check "hangover hangover-wine winetricks"
	run_wine_shortcut_script
	print_to_config "setup_wine" "hangover-wine"
	elif [[ "$wine_answer" == "4" ]]; then
	echo "${R}[${C}-${R}]${C} Skipping wine Installation...${W}"
	print_to_config "setup_wine" "skip"
	else
    echo "${R}[${C}-${R}]${G} Installing Wine Natively In Termux${W}"
	echo
	package_install_and_check "wine-stable winetricks"
	run_wine_shortcut_script
	print_to_config "setup_wine" "default-wine"
	fi
}

#########################################################################
#
# Add Autostart
#
#########################################################################

function add_vnc_autostart() {
	echo "${R}[${C}-${R}]${G}${BOLD} Adding vnc to autostart${W}"
	if grep -q "^vncstart" "$shell_rc_file"; then
	echo "${R}[${C}-${R}]${G} Termux:X11 start already exist${W}"
	else
cat << EOF >> "$shell_rc_file"
# Start Vnc
if ! pgrep Xvnc > /dev/null; then
echo "${G}Starting Vnc...${W}"
vncstart
fi
EOF
	fi
}

function add_tx11_autostart() {
	echo "${R}[${C}-${R}]${G}${BOLD} Adding Termux:x11 to autostart${W}"
	if grep -q "^tx11start" "$shell_rc_file"; then
	echo "${R}[${C}-${R}]${G} Termux:X11 start already exist${W}"
	else
cat << EOF >> "$shell_rc_file"
# Start Termux:X11
termux_x11_pid=\$(pgrep -f "app_process -Xnoimage-dex2oat / com.termux.x11.Loader :${display_number}")
if [ -z "\$termux_x11_pid" ]; then
echo "${G}Starting Termux:x11...${W}"
tx11start
fi
EOF
	fi
}

function add_to_autostart() {
	if [[ "$de_on_startup" == "y" ]]; then
		if [[ "$default_gui_mode" == "vnc" ]]; then
			add_vnc_autostart
		elif [[ "$gui_mode" == "termux_x11" ]]; then
			add_tx11_autostart
		elif [[ "$default_gui_mode" == "termux_x11" ]]; then
			add_tx11_autostart
		fi
	fi
	print_to_config "de_on_startup"
}


#########################################################################
#
# Finish | Notes
#
#########################################################################
function cleanup_cache() {
	banner
	echo "${R}[${C}-${R}]${G} Cleaning up the cache...${W}"
	if [[ "$PACKAGE_MANAGER" == "pacman" ]]; then
	pacman -Scc
	else
	apt clean all
	fi
}

function add_common_function() {
	check_and_delete "$PREFIX/etc/termux-desktop/common_functions"
cat <<'EOF' > "$PREFIX/etc/termux-desktop/common_functions"
#!/data/data/com.termux/files/usr/bin/bash

R="$(printf '\033[1;31m')"
G="$(printf '\033[1;32m')"
Y="$(printf '\033[1;33m')"
B="$(printf '\033[1;34m')"
C="$(printf '\033[1;36m')"
W="$(printf '\033[0m')"
BOLD="$(printf '\033[1m')"

cd "$HOME" || exit
termux_desktop_path="/data/data/com.termux/files/usr/etc/termux-desktop"
config_file="$termux_desktop_path/configuration.conf"
log_file="/data/data/com.termux/files/home/termux-desktop.log"
EOF
typeset -f check_termux print_log print_success print_failed wait_for_keypress check_and_create_directory check_and_delete check_and_backup download_file check_and_restore detact_package_manager package_install_and_check package_check_and_remove get_file_name_number extract_zip_with_progress extract_archive download_and_extract count_subfolders confirmation_y_or_n get_latest_release install_font_for_style select_an_option preprocess_conf read_conf print_to_config >> "$PREFIX/etc/termux-desktop/common_functions"
chmod +x "$PREFIX/etc/termux-desktop/common_functions"
}

function delete_installer_file() {
	current_script_path="$(realpath "$0")"
	if [[ "$current_script_path" != */bin* ]]; then
	    if [[ -f "${current_path}/setup-termux-desktop" ]]; then
		(exec rm -- "${current_path}/setup-termux-desktop") &
		else
		print_failed "Installer file not found"
		fi
	fi
}

function notes() {
	banner
	echo "${R}[${C}-${R}]${G}${BOLD} Installation Successfull...${W}"
	echo
	sleep 2
	echo "${R}[${C}-${R}]${C}${BOLD} Now Restart Termux ${G}(Must)${W}"
	echo
	echo "${R}[${C}-${R}]${C}${BOLD} Some basic commands:-${G}(Must)${W}"
	echo
	echo "${R}[${C}-${R}]${G} tx11start        to start the gui with termux:x11${W}"
	echo
	echo "${R}[${C}-${R}]${G} tx11stop         to stop the gui with termux:x11${W}"
	echo
	echo "${R}[${C}-${R}]${G} tx11stop -f      to force stop the gui with termux:x11${W}"
	echo
	if [[ "$gui_mode" == "both" ]]; then
	echo "${R}[${C}-${R}]${G} vncstart         to start the gui with vnc${W}"
	echo
	echo "${R}[${C}-${R}]${G} vncstop          to stop the gui with vnc${W}"
	echo
	fi
	echo "${R}[${C}-${R}]${C} $selected_distro to login into $selected_distro${W}"
	echo
	echo "${R}[${C}-${R}]${C}${BOLD} See Uses Section in github to know how to use it${W}"
	echo
	echo "${R}[${C}-${R}]${C} URL:- ${B}https://github.com/sabamdarif/termux-desktop/blob/main/README.md#5-usage-instructions${W}"
	echo
	if [[ "$distro_add_answer" == "y" ]]; then
	echo "${R}[${C}-${R}]${C}${BOLD} See how to use Linux distro container${W}"
	echo
	echo "${R}[${C}-${R}]${C} URL:- ${B}https://github.com/sabamdarif/termux-desktop/blob/main/proot-container.md${W}"
	fi
}

#########################################################################
#
# Remove
#
#########################################################################

function remove_termux_desktop() {
	if [[ ! -e "$config_file" ]]; then
	echo "${R}[${C}-${R}]${C}${BOLD} Please Install Termux Desktop First${W}"
	exit 0
	else
	banner
	echo "${R}[${C}-${R}]${R}${BOLD} Remove Termux Desktop${W}"
	echo ""
	confirmation_y_or_n "Are You Sure You Want To Remove Termux Desktop Completely" ask_remove
	if [[ "$ask_remove" == "n" ]]; then
	echo "${R}[${C}-${R}]${G}${BOLD} Canceling...${W}"
	exit 0
	else
	echo "${R}[${C}-${R}]${R}${BOLD} Removeing Termux Desktop${W}"
	sleep 3
	read_conf
	#remove basic packages
	package_check_and_remove "pulseaudio x11-repo tur-repo"
	#remove desktop related packages
	if [[ "$de_name" == "xfce" ]]; then
	package_check_and_remove "xfce4 xfce4-goodies xwayland kvantum"
	elif [[ "$de_name" == "lxqt" ]]; then
	package_check_and_remove "lxqt xorg-xsetroot papirus-icon-theme xwayland kvantum"
	elif [[ "$de_name" == "openbox" ]]; then
	package_check_and_remove "openbox polybar xorg-xsetroot lxappearance wmctrl feh xwayland kvantum thunar firefox mpd rofi bmon xcompmgr xfce4-settings gedit"
	fi
	#remove zsh
	if [[ "$zsh_answer" == "y" ]]; then
	package_check_and_remove "zsh"
	check_and_delete ".oh-my-zsh .zsh_history .zshrc"
	fi
	#remove terminal utility
	if [[ "$terminal_utility_setup_answer" == "y" ]]; then
	check_and_delete "$PREFIX/etc/motd.sh $HOME/.termux $HOME/.fonts/font.ttf $HOME/.termux/colors.properties"
	check_and_restore "$PREFIX/etc/motd"
	check_and_restore "$PREFIX/etc/motd-playstore"
	check_and_restore "$PREFIX/etc/motd.sh"
	check_and_restore "$HOME/.termux/colors.properties"
	if grep -q "motd.sh$" "$PREFIX/etc/termux-login.sh"; then
	sed -i "s|.*motd\.sh$|# |" "$PREFIX/etc/termux-login.sh"
	fi
	package_check_and_remove "nerdfix fontconfig-utils bat eza"
	fi
	#remove browser
	if [[ "$installed_browser" == "firefox" ]]; then
	package_check_and_remove "firefox"
	elif [[ "$installed_browser" == "chromium" ]]; then
	package_check_and_remove "chromium"
	elif [[ "$installed_browser" == "both" ]]; then
	package_check_and_remove "firefox chromium"
	fi
	#remove ide
	if [[ "$installed_ide" == "code" ]]; then
	package_check_and_remove "code-oss code-is-code-oss"
	elif [[ "$installed_ide" == "geany" ]]; then
	package_check_and_remove "geany"
	elif [[ "$installed_ide" == "both" ]]; then
	package_check_and_remove "code-oss code-is-code-oss geany"
	fi
	#remove media player
	if [[ "$installed_media_player" == "vlc" ]]; then
	package_check_and_remove "vlc-qt-static"
	elif [[ "$installed_media_player" == "audacious" ]]; then
	package_check_and_remove "audacious"
	elif [[ "$installed_media_player" == "both" ]]; then
	package_check_and_remove "vlc-qt-static audacious"
	fi
	#remove photo editor
	if [[ "$installed_photo_editor" == "gimp" ]]; then
	package_check_and_remove "gimp"
	elif [[ "$installed_photo_editor" == "audacious" ]]; then
	package_check_and_remove "audacious"
	elif [[ "$installed_photo_editor" == "both" ]]; then
	package_check_and_remove "gimp audacious"
	fi
	#remove wine
	if [[ "$setup_wine" == "default-wine" ]]; then
	package_check_and_remove "wine winetricks"
	elif [[ "$setup_wine" == "mobox" ]]; then
	echo "${R}[${C}-${R}]${C}${BOLD} Make Sure To Uninstall Mobox Using Their Instruction${W}"
	check_and_delete "$HOME/Desktop/MoboxExplorer.desktop"
	sleep 4
	elif [[ "$setup_wine" == "hangover-wine" ]]; then
	package_check_and_remove "hangover-wine winetricks"
	fi
	check_and_delete "$PREFIX/bin/wine $PREFIX/share/applications/wine-*"
	#remove styles
	if [[ "$style_name" == "Modern Style" ]] || [[ "$style_name" == "MacOS Inspired-1 Style" ]] || [[ "$style_name" == "MacOS Inspired-2 Style" ]]; then
	package_check_and_remove "cairo-dock-core"
	elif [[ "$style_name" == "Modern Style" ]] || [[ "$style_name" == "MacOS Inspired-2 Style" ]]; then
	package_check_and_remove "rofi"
	elif [[ "$style_name" == "Modern Style" ]]; then
	package_check_and_remove "fluent-icon-theme vala-panel-appmenu"
	elif [[ "$style_name" == "Windows10 Style" ]]; then
	package_check_and_remove "gtk2-engines-murrine"
	fi
	#Remove folders and other files
	check_and_delete "$PREFIX/share/backgrounds $themes_folder $icons_folder $PREFIX/etc/termux-desktop"
	check_and_delete "$HOME/.config/$the_config_dir"
	check_and_delete "$HOME/Desktop $HOME/Downloads $HOME/Videos $HOME/Pictures $HOME/Music"
	#remove hw packages
	package_check_and_remove "mesa-zink virglrenderer-mesa-zink vulkan-loader-android angle-android virglrenderer-android mesa-vulkan-icd-freedreno mesa-vulkan-icd-wrapper mesa-zink"
	#remove distro container
	if [[ "$distro_add_answer" == "y" ]]; then
	proot-distro remove "$selected_distro"
	proot-distro clear-cache
	package_check_and_remove "proot-distro"
	check_and_delete "$PREFIX/bin/$selected_distro $PREFIX/bin/pdrun"
	fi
	#remove vnc and termux x11
	check_and_delete "$PREFIX/bin/gui"
	if [[ "$gui_mode" == "termux_x11" ]]; then
	package_check_and_remove "termux-x11-nightly xorg-xhost"
	check_and_delete "$PREFIX/bin/tx11start $PREFIX/bin/tx11stop"
	elif [[ "$gui_mode" == "both" ]]; then
	package_check_and_remove "termux-x11-nightly tigervnc xorg-xhost"
	check_and_delete "$PREFIX/bin/tx11start $PREFIX/bin/tx11stop $HOME/.vnc/xstartup $PREFIX/bin/vncstart $PREFIX/bin/vncstop $PREFIX/bin/gui $PREFIX/bin/tx11start $PREFIX/bin/tx11stop"
	# remove appstore
	package_check_and_remove "aria2 python python3 cloneit"
	check_and_delete "${PREFIX}/opt/appstore"
	check_and_delete "${PREFIX}/share/applications/org.sabamdarif.termux.appstore.desktop"
	fi
	check_and_delete "$PREFIX/etc/termux-desktop $PREFIX/bin/setup-termux-desktop"
	clear
	echo "${R}[${C}-${R}]${G}${BOLD} Everything remove successfully${W}"
	fi
	fi
}

#########################################################################
#
# Change Style
#
#########################################################################

function gui_check_up() {
termux_x11_pid=$(pgrep -f "app_process -Xnoimage-dex2oat / com.termux.x11.Loader :${display_number}")
vnc_server_pid=$(pgrep -f "vncserver")
de_pid=$(pgrep -f "$de_startup")
if [[ -n "$termux_x11_pid" ]] || [[ -n "$de_pid" ]] || [[ -n "$vnc_server_pid" ]]>/dev/null 2>&1; then
echo "${G}Please Stop The Gui Desktop Server First${W}"
exit 0
fi
}

function change_style() {
	if [[ ! -e "$config_file" ]]; then
	echo -e "${C} It look like you haven't install the desktop yet\n Please install the desktop first${W}"
	exit 0
	else
	read_conf
	gui_check_up
	banner
	echo "${R}[${C}-${R}]${G} Your currently installed style is ${C}${BOLD}$style_name ${W}"
	echo
	sleep 2
	questions_theme_select
	rm -rf ~/.cache/sessions/x*
	setup_config
	banner
	echo "${R}[${C}-${R}]${G} Style changed successfully${W}"
	echo
	unset style_name
	read_conf
	echo "${R}[${C}-${R}]${G} Your currently installed style is ${C}${BOLD}$style_name ${W}"
	fi
}

#########################################################################
#
# Change Hardware Acceleration
#
#########################################################################

function change_hw() {
	# Check if the configuration file exists
	if [[ ! -e "$config_file" ]]; then
	    echo -e "${C} It looks like you haven't installed the desktop yet\n Please install the desktop first${W}"
	    exit 0
	else
		read_conf
		if [[ "$enable_hw_acc"  == "y" ]]; then
		    banner
		    echo "${R}[${C}-${R}]${G} Your current hardware acceleration method for Termux is: ${C}${BOLD}${termux_hw_answer}${W}"
		    echo
		    echo "${R}[${C}-${R}]${G} Changing drivers might break the desktop environment sometimes${W}"
		    confirmation_y_or_n "Do you want to continue" confirmation_break_de
		    if [[ "$confirmation_break_de" == "y" ]]; then
		        package_check_and_remove "mesa-zink vulkan-loader-android virglrenderer-android angle-android mesa-vulkan-icd-freedreno-dri3"
		    else
		        exit 0
		    fi
		    echo "${R}[${C}-${R}]${R}${BOLD} This process might break your desktop environment${W}"
		    echo "${R}[${C}-${R}]${G}${BOLD} Make your new choice${W}"
		    echo
		    hw_questions
		    hw_config
		    if [[ "$gui_mode" == "termux_x11" ]]; then
		        setup_tx11start_cmd
		    elif [[ "$gui_mode" == "both" ]]; then
		        setup_tx11start_cmd
		        setup_vncstart_cmd
		    fi
		    if [[ "$distro_add_answer" == "y" ]]; then
		        sed -i "s|selected_pd_hw_method=\"[^\"]*\"|selected_pd_hw_method=\"$pd_hw_method\"|" "$PREFIX/bin/pdrun"
		    fi
		    clear
		    print_success "${BOLD}Hardware acceleration method changed successfully"
		elif [[ "$enable_hw_acc" == "n" ]]; then
			echo "${R}[${C}-${R}]${G} This option is only for Hardware Acceleration enabled user${W}"
		fi
	fi
}

#########################################################################
#
# Change Distro
#
#########################################################################

function change_distro() {
	if [[ ! -e "$config_file" ]]; then
	echo -e "${C} It look like you haven't install the desktop yet\n Please install the desktop first${W}"
	exit 0
	else
	read_conf
	banner
		if [[ "$distro_add_answer" == "y" ]]; then
			call_from_change_pd="y"
		    if [[ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/$selected_distro" ]] ;then
			echo "${R}[${C}-${R}]${G} Your currently installed distro is :${C}${BOLD}${selected_distro}${W}"
			echo
			echo "${R}[${C}-${R}]${R} Changing distro will delete all the data from your previous distro${W}"
			echo
			confirmation_y_or_n "Do you want to continue" distro_change_confirmation
			    if [[ "$distro_change_confirmation" == "y" ]]; then
				choose_distro
				echo "${R}[${C}-${R}]${G} Removing $selected_distro and it's data${W}"
				pd remove $selected_distro
				check_and_delete "$PREFIX/share/applications/pd_added"
				check_and_delete "$PREFIX/bin/$selected_distro"
				pd_hw_method=$(grep 'selected_pd_hw_method=' "$PREFIX/bin/pdrun" | sed -e 's/.*selected_pd_hw_method="\([^"]*\)".*/\1/')
					if [[ "$pd_audio_config_answer" == "y" ]]; then
					rm "$HOME/.${selected_distro}-sound-access"
					fi
					echo
					distro_container_setup "$1" "$2"
				else
				echo "${R}[${C}-${R}]${C} Canceling distro change process...${W}"
				sleep 2
				exit 0
				fi
			else
			print_failed "${selected_distro} isn't installed"
		    fi
		else
			echo "${R}[${C}-${R}]${G} It look like you haven't install any distro yet${W}"
			echo
			echo "${R}[${C}-${R}]${G}${BOLD} Do you want to add a Linux distro container (proot distro)${W}"
			echo
			echo "${R}[${C}-${R}]${G} It will help you to install those app which are not avilable in termux${W}"
			echo
			echo "${R}[${C}-${R}]${G} You can launch those installed apps from termux like other apps${W}"
			echo
			confirmation_y_or_n "Do you want to continue" distro_add_answer
			print_to_config "distro_add_answer"
			distro_questions
			distro_hw_questions
			distro_container_setup "$1" "$2"
		fi
	fi
}

#########################################################################
#
# Change Autostart
#
#########################################################################

function change_autostart() {
    read_conf

    if [[ $SHELL = *zsh ]]; then
        current_shell="zsh"
        shell_rc_file="$HOME/.zshrc"
    elif [[ $SHELL = *bash ]]; then
        current_shell="bash"
        shell_rc_file="/data/data/com.termux/files/usr/etc/bash.bashrc"
	else
        print_failed "Unable to detect current shell"
		echo "${R}[${C}-${R}]${G} current shell is:-${W} $SHELL"
		exit 0
    fi

    if [[ "$zsh_answer" == "y" && "$current_shell" == "bash" ]] || [[ "$zsh_answer" == "n" && "$current_shell" == "zsh" ]]; then
        print_failed "It looks like you have changed your shell after the installation"
        exit 0
    fi

    if [[ "$de_on_startup" == "y" ]]; then
	confirmation_y_or_n "You are sure you want to change auto" confirmation_enable_auto_start
		if [[ "$confirmation_enable_auto_start" == "y" ]]; then
    	    if grep -q "^vncstart" "$shell_rc_file"; then
    	        sed -i '/# Start Vnc/,/fi/d' "$shell_rc_file"
				print_to_config "de_on_startup" "n"
			fi
    	    if grep -q "^tx11start" "$shell_rc_file"; then
    	        sed -i '/# Start Termux:X11/,/fi/d' "$shell_rc_file"
				print_to_config "de_on_startup" "n"
    	    fi
		echo "${R}[${C}-${R}]${G} Auto start disabled${W}"
		else
			echo "${R}[${C}-${R}]${G} Keeping auto start disabled${W}"
		fi
	elif [[ "$de_on_startup" == "n" ]]; then
	confirmation_y_or_n "You haven't have auto start enable, do you want to enable it" confirmation_enable_auto_start
		if [[ "$confirmation_enable_auto_start" == "y" ]]; then
		    if [[ "$gui_mode" == "both" ]]; then
			echo "${R}[${C}-${R}]${G} You chose both vnc and termux:x11 to access gui mode${W}"
			echo
			echo "${R}[${C}-${R}]${G} Which will be your default${W}"
			echo
			echo "${Y}1. Termux:x11${W}"
			echo
			echo "${Y}2. Vnc${W}"
			echo
			autostart_gui_mode_num=2
				if [[ "$autostart_gui_mode_num" == "1" ]]; then
					default_gui_mode="termux_x11"
				elif [[ "$autostart_gui_mode_num" == "2" ]]; then
					default_gui_mode="vnc"
				fi
				print_to_config "default_gui_mode"
			fi
		de_on_startup=y
		print_to_config "de_on_startup"
		add_to_autostart
		else
		echo "${R}[${C}-${R}]${G} Keeping auto start disabled${W}"
		fi
    fi
}

#########################################################################
#
# Change Display Port
#
#########################################################################

# change the Display Port/Display Number where it will show the output
function change_display() {
	read_conf
	gui_check_up
	if [[ "$gui_mode" == "termux_x11" ]] || [[ "$gui_mode" == "both" ]]; then
		echo "${R}[${C}-${R}]${G}${BOLD} Your Current Display Port: ${display_number}${W}"
		echo
		confirmation_y_or_n "Do you want to change the display port" change_display_port
		if [[ "$change_display_port" == "y" ]]; then
			while true; do
        	read -r -p "${R}[${C}-${R}]${Y}${BOLD} Type the Display Port number: ${W}" display_number
				if [[ "$display_number" =~ ^[0-9]+$ ]]; then
					break
				else
					echo "${R}[${C}-${R}]${R} Please enter a valid number between 0-9 ${W}"
				fi
    		done
			call_from_change_display=y
			hw_config
			setup_tx11start_cmd
			print_to_config "display_number"
			sed -i "s|DISPLAY=:[0-9]*|DISPLAY=:$display_number|" "${PREFIX}/bin/pdrun"
			sed -i "s|DISPLAY=:[0-9]*|DISPLAY=:$display_number|" "${PREFIX}/bin/$selected_distro"
			print_log "Type the Display Port number: $display_number"
		fi
	else
	echo "${R}[${C}-${R}]${G} Changing display port only supported in Termux:x11${W}"
	fi
}


#########################################################################
#
# Reinstall themes
#
#########################################################################

function reinstall_themes() {
	read_conf
	gui_check_up
	tmp_themes_folder="$PREFIX/tmp/themes"
	check_and_create_directory "$tmp_themes_folder"
	echo "${R}[${C}-${R}]${G} Reinstalling Themes...${W}"
	download_and_extract "https://raw.githubusercontent.com/sabamdarif/termux-desktop/refs/heads/setup-files/setup-files/${de_name}/look_${style_answer}/theme.tar.gz" "$tmp_themes_folder"
	local theme_names
	theme_names=$(ls "$tmp_themes_folder")
	local theme_name
	for theme_name in $theme_names; do
	check_and_delete "$themes_folder/$theme_name"
	mv "$tmp_themes_folder/$theme_name" "$themes_folder/"
	done
	echo "${R}[${C}-${R}]${G}${BOLD} Themes reinstall successfully${W}"
}

#########################################################################
#
# Reinstall icons
#
#########################################################################

function reinstall_icons() {
	read_conf
	gui_check_up
	tmp_icons_folder="$PREFIX/tmp/icons"
	check_and_create_directory "$tmp_icons_folder"
	package_install_and_check "gdk-pixbuf"
	echo "${R}[${C}-${R}]${G} Reinstalling Icons...${W}"
	download_and_extract "https://raw.githubusercontent.com/sabamdarif/termux-desktop/refs/heads/setup-files/setup-files/${de_name}/look_${style_answer}/icon.tar.gz" "$tmp_icons_folder"
	local icon_themes_names
	icon_themes_names=$(ls "$tmp_icons_folder")
	local icon_theme
		for icon_theme in $icon_themes_names; do
		check_and_delete "$icons_folder/$icon_theme"
		mv "$tmp_icons_folder/$icon_theme" "$icons_folder/"
		echo "${R}[${C}-${R}]${G} Creating icon cache...${W}"
			if [[ "$de_name" == "xfce" ]]; then
			gtk-update-icon-cache -f -t "$icons_folder/$icons_theme"
			fi
		gtk-update-icon-cache -f -t "$PREFIX/share/icons/$icons_theme"
		done
	echo "${R}[${C}-${R}]${G}${BOLD} Icons reinstall successfully${W}"
}

#########################################################################
#
# Reinstall config
#
#########################################################################

function reinstall_config() {
	read_conf
	gui_check_up
	tmp_config_folder="$PREFIX/tmp/config"
	check_and_create_directory "$tmp_config_folder"
	echo "${R}[${C}-${R}]${G} Reinstalling Config...${W}"
	download_and_extract "https://raw.githubusercontent.com/sabamdarif/termux-desktop/refs/heads/setup-files/setup-files/${de_name}/look_${style_answer}/config.tar.gz" "$tmp_config_folder"
	local config_file_names
	config_file_names=$(ls "$tmp_config_folder")
	local config_file
	for config_file in $config_file_names; do
	check_and_delete "$HOME/.config/$config_file"
	mv "$tmp_config_folder/$config_file" "$HOME/.config/"
	done
	echo "${R}[${C}-${R}]${G}${BOLD} Config reinstall successfully${W}"
}

#########################################################################
#
# Some Fixes | Basic Task
#
#########################################################################

function disable_vblank_mode() {
	if [[ "$de_name" == "xfce" ]]; then
		sed -i 's|<property name="vblank_mode" type="string" value="auto"/>|<property name="vblank_mode" type="string" value="off"/>|' "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml"
	fi
}

function some_fixes() {

	# samsung oneui-6 audio fixes
	local device_brand_name
	device_brand_name=$(getprop ro.product.brand | cut -d ' ' -f 1)
	if [[ $device_brand_name == samsung* && $android_version -ge 14 ]]; then
    grep -q "LD_PRELOAD=/system/lib64/libskcodec.so" "$shell_rc_file" || echo "LD_PRELOAD=/system/lib64/libskcodec.so" >> "$shell_rc_file"
	fi
	# tx11start and vncstart
	if [[ $termux_hw_answer == "freedreno" ]] || [[ $termux_hw_answer == "zink_with_mesa" ]] || [[ $termux_hw_answer == "zink_with_mesa_zink" ]]; then
	sed -i 's/^[[:space:]]*&[[:space:]]*$/ /' "$PREFIX/bin/tx11start"
	sed -i 's/^[[:space:]]*&[[:space:]]*$/ /' "$PREFIX/bin/vncstart"
	disable_vblank_mode
	fi

	if [[ "$confirmation_mesa_vulkan_icd_wrapper" == "y" ]]; then
		disable_vblank_mode
		if [[ "$device_gpu_model" == "1" ]]; then
		sed -i 's/^[[:space:]]*initialize_server="\s*"/ /' "$PREFIX/bin/pdrun"
		fi

		if [[ "$browser_answer" == "2" ]] || [[ "$browser_answer" == "3" ]]; then
		sed -i 's|Exec=/data/data/com.termux/files/usr/bin/chromium-browser %U|Exec=/data/data/com.termux/files/usr/bin/chromium-browser --enable-features=Vulkan %U|' /data/data/com.termux/files/usr/share/applications/chromium.desktop
		fi

		if [[ "$ide_answer" == "2" ]] || [[ "$ide_answer" == "3" ]]; then
		sed -i 's|/data/data/com.termux/files/usr/bin/code-oss|/data/data/com.termux/files/usr/bin/code-oss --enable-features=Vulkan|g' /data/data/com.termux/files/usr/share/applications/code-oss*
		fi
	fi
}

# add the basic details into a config file
function print_basic_details() {
	local net_condition
	local country
	net_condition="$(getprop gsm.network.type)"
	country="$(getprop gsm.sim.operator.iso-country)"
cat <<EOF > "$config_file"
####################################
########## Termux Desktop ##########
####################################

########################
#  -:Device Details:-  #
########################
#
# Termux Version: ${TERMUX_VERSION}-${TERMUX_APK_RELEASE}
# Device Model: $model
# Android Version: $android_version
# Free Space: $free_space
# Total Ram: $total_ram
# Architecture: $app_arch
# System CPU Architecture: $supported_arch
# Processor: $PROCESSOR_BRAND_NAME $PROCESSOR_NAME
# GPU: $detected_gpu
# Network Condition: $net_condition (On first run)
# Country: $country
#
########################

##### Please don't modify this file otherwise some functions won't work #####

EOF
}

function add_installer() {
	if [[ ! -e "$PREFIX/bin/setup-termux-desktop" ]]; then
		echo "${R}[${C}-${R}]${G} Adding setup-termux-desktop installer to bin${W}"
    	download_file "$PREFIX/bin/setup-termux-desktop" "https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/setup-termux-desktop"
    	chmod +x "$PREFIX/bin/setup-termux-desktop"
	fi
}

#########################################################################
#
# Update Task
#
#########################################################################

# check for the changes in the installer file
function check_for_update_and_update_installer() {
    if [[ -e "$PREFIX/bin/setup-termux-desktop" ]]; then
		banner
        echo "${R}[${C}-${R}]${G} Checking for update...${W}"
        echo

        check_and_create_directory "$termux_desktop_path"
        local current_script_hash
		local update_installer
		current_script_hash=$(curl -sL https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/setup-termux-desktop | sha256sum | cut -d ' ' -f 1)
        local local_script_hash
		local_script_hash=$(basename "$(sha256sum "$PREFIX/bin/setup-termux-desktop" | cut -d ' ' -f 1)")

        if [[ "$local_script_hash" != "$current_script_hash" ]]; then
            confirmation_y_or_n "You are using an old installer. Do you want to update it to the latest version" update_installer

            if [[ "$update_installer" == "y" ]]; then
				check_and_create_directory "$PREFIX/etc/termux-desktop"
                mv "$PREFIX/bin/setup-termux-desktop" "$PREFIX/etc/termux-desktop/"
                check_and_backup "$PREFIX/etc/termux-desktop/setup-termux-desktop"
                add_installer
                add_common_function
				unset local_script_hash
                local new_local_script_hash
				new_local_script_hash=$(basename "$(sha256sum "$PREFIX/bin/setup-termux-desktop" | cut -d ' ' -f 1)")
                if [[ "$new_local_script_hash" == "$current_script_hash" ]]; then
                    echo "${R}[${C}-${R}]${G} Installer updated successfully${W}"
                    check_and_delete "$termux_desktop_path/skip_update_checkup"
                    exit 0
                else
                    echo "${R}[${C}-${R}]${G} Failed to update the installer${W}"
                    exit 0
                fi
            elif [[ "$update_installer" == "n" ]]; then
            	echo "${R}[${C}-${R}]${G} Keeping the old installer${W}"
            	check_and_create_directory "$termux_desktop_path"
            	touch "$termux_desktop_path/skip_update_checkup"
            	exit 0
            fi
        else
            echo -e "${R}[${C}-${R}]${G}${BOLD} Good job, you are using the latest installer${W}"
        fi
    fi
}

function check_installer_status() {
    if [[ -e "$PREFIX/bin/setup-termux-desktop" ]]; then
        if [[ ! -e "$termux_desktop_path/skip_update_checkup" ]]; then
            check_for_update_and_update_installer
        else
            echo "${R}[${C}-${R}]${G}${BOLD} Update check skipped${W}"
            echo "${R}[${C}-${R}]${G}${BOLD} Use ${C}--update ${G}to force update check${W}"
        fi
    fi
}

function check_for_appstore_update() {
    if [[ ! -d "$PREFIX/opt/appstore" ]]; then
        return
    fi

    echo "${R}[${C}-${R}]${G} Checking for appstore updates...${W}"
    echo

    local files_to_check=(
        "gtk_app_store.py"
        "inbuild_functions/inbuild_functions"
        "requirements.txt" 
        "style/style.css"
    )
    
    local update_needed=false
    local failed_hash_checks=()

    # Check each file's hash against GitHub version
    for file in "${files_to_check[@]}"; do
        local github_hash
        local local_hash
        
        # Get GitHub file hash
        if [[ "$file" == "gtk_app_store.py" ]]; then
            github_hash=$(curl -sL "https://raw.githubusercontent.com/sabamdarif/Termux-AppStore/main/src/${file}" | sha256sum | cut -d ' ' -f 1)
        else
            github_hash=$(curl -sL "https://raw.githubusercontent.com/sabamdarif/Termux-AppStore/main/src/${file}" | sha256sum | cut -d ' ' -f 1)
        fi

        # Get local file hash
        if [[ -f "$PREFIX/opt/appstore/$file" ]]; then
            local_hash=$(sha256sum "$PREFIX/opt/appstore/$file" | cut -d ' ' -f 1)
        else
            failed_hash_checks+=("$file")
            update_needed=true
            continue
        fi

        # Compare hashes
        if [[ "$local_hash" != "$github_hash" ]]; then
            update_needed=true
            failed_hash_checks+=("$file")
        fi
    done

    if [[ "$update_needed" == true ]]; then
        echo "${R}[${C}-${R}]${Y} Updates found for the following files:${W}"
        printf '%s\n' "${failed_hash_checks[@]}"
        echo
        
        confirmation_y_or_n "Would you like to update the appstore to the latest version" update_appstore

        if [[ "$update_appstore" == "y" ]]; then
            echo "${R}[${C}-${R}]${G} Updating appstore...${W}"
            check_and_delete "$PREFIX/opt/appstore"
            install_termux_desktop_appstore
            echo "${R}[${C}-${R}]${G} Appstore updated successfully${W}"
        else
            echo "${R}[${C}-${R}]${C} Skipping appstore update${W}"
        fi
    else
        echo "${R}[${C}-${R}]${G}${BOLD} You are using the latest version${W}"
    fi
}

#########################################################################
#
# Reset Changes
#
#########################################################################

function reset_changes() {
    if [[ ! -e "$config_file" ]]; then
        echo -e "${C} It looks like you haven't installed the desktop yet.\n Please install the desktop first.${W}"
        exit 0
    else
        read_conf
        banner
        echo "${R}[${C}-${R}]${G} Removing $de_name Config...${W}"
        set_config_dir
		check_and_delete "${config_dirs}"
		shell_name=$(basename "$SHELL")
        get_shellrc_path
		if [[ "$distro_add_answer" == "y" ]]; then
            confirmation_y_or_n "Do you want to reset the Linux distro container as well?" conf_distro_reset
            if [[ "$conf_distro_reset" == "y" ]]; then
                check_and_restore "$save_path/.${pd_shell_name}rc"
            fi
        fi

        if [[ "$terminal_utility_setup_answer" == "y" ]]; then
            check_and_delete "$PREFIX/etc/motd.sh $HOME/.termux $HOME/.fonts/font.ttf $HOME/.termux/colors.properties" ; termux-reload-settings
            check_and_restore "$PREFIX/etc/motd" ; termux-reload-settings
            check_and_restore "$PREFIX/etc/motd-playstore"
            check_and_restore "$PREFIX/etc/motd.sh" ; termux-reload-settings
            check_and_restore "$HOME/.termux/colors.properties"
            if grep -q "motd.sh$" "$PREFIX/etc/termux-login.sh"; then
                sed -i "s|.*motd\.sh$|# |" "$PREFIX/etc/termux-login.sh" ; termux-reload-settings
            fi
            rm "$PREFIX/share/applications/wine-*.desktop" >/dev/null 2>&1
            check_and_delete "$termux_desktop_path"
            check_and_delete "$PREFIX/bin/tx11start $PREFIX/bin/tx11stop $PREFIX/bin/vncstop $PREFIX/bin/vncstart $PREFIX/bin/gui $PREFIX/bin/pdrun"
        fi

        check_and_delete "$HOME/Music"
        check_and_delete "$HOME/Downloads"
        check_and_delete "$HOME/Desktop"
        check_and_delete "$HOME/Pictures"
        check_and_delete "$HOME/Videos"

        if [[ "$shell_name" == "zsh" ]]; then
            chsh -s bash
            check_and_delete "$HOME/.oh-my-zsh"
        fi

        check_and_delete "$shell_rc_file"
        check_and_restore "$shell_rc_file"
		check_and_backup "$config_file"
        touch "$config_file"
        print_basic_details

        echo -e "${R}[${C}-${R}]${G}${BOLD} Reset successful.\n Now restart Termux.${W}"
    fi
}

#########################################################################
#
# Call Functions
#
#########################################################################
check_termux
if [[ -z "$1" ]] || [[ "$1" == "--install" ]] || [[ "$1" == "-i" ]]; then
	check_installer_status "$1"
fi
current_path=$(pwd)
function install_termux_desktop() {
print_recomended_msg
banner
cleanup_cache
detact_package_manager
termux-wake-lock
sleep 1
check_and_create_directory "$PREFIX/etc/termux-desktop"
touch "$config_file"
print_basic_details
add_common_function
update_sys
install_required_packages
questions_install_type
if [[ "$install_type_answer" == "3" ]]; then
	if [[ "$distro_add_answer" == "y" ]]; then
		distro_questions
	fi

	if [[ "$enable_hw_acc" == "y" ]]; then
		setup_device_gpu_model
		hw_questions
	fi
fi
print_conf_info
setup_folder
setup_zsh
setup_fonts
install_desktop
browser_installer
ide_installer
media_player_installer
photo_editor_installer
setup_wine
if [[ "$style_answer" == "0" ]]; then
	banner
	echo "${R}[${C}-${R}]${G}${BOLD} Configuring Stock $de_name Style...${W}"
	echo
	print_to_config "style_answer"
	print_to_config "style_name" "Stock"
else
	setup_config
fi
banner
call_from_change_pd="n"
distro_container_setup
gui_launcher
terminal_utility_setup
install_termux_desktop_appstore
add_to_autostart
check_desktop_process
install_fm_tools
some_fixes
preprocess_conf
cleanup_cache
termux-wake-unlock
add_installer
notes
print_log "$(cat $config_file)"
delete_installer_file
}

function show_help() {
echo -e "
--debug           to create a log file
-i,--install      to start installation
-r,--remove       to remove termux desktop
-c,--change       to change some previous configuration
-ri,--reinstall   to reinstall some previously install stuff
--reset           to reset all changes made by this script without uninstalling any package
-h,--help         to show help
"
}

function show_change_help() {
echo "options you can use with --change"
echo -e "
style      to change installed style
pd,distro  to change installed linux distro container
hw,hwa     to change hardware acceleration method
autostart  to change autostart behaviour
display    to change termux:x11 display port
h,help     to show help

example uses : --change style
"
}

function show_reinstall_help() {
echo -e "
options you can use with --reinstall

icons      to reinstall icons pack
themes     to reinstall themes pack
config     to reinstall config
h,help     to show help

example uses : --reinstall icons
example uses : --reinstall icons,themes...etc to reinstall them at once
"
}

if [[ $1 == "--debug" ]]; then
    debug
    shift
fi

case $1 in
    --remove|-r)
        remove_termux_desktop
        ;;
    --install|-i)
        install_termux_desktop
        ;;
    --change|-c)
        case $2 in
            style)
                change_style
                ;;
            distro|pd)
                change_distro "$1" "$2"
                ;;
            hw|hwa)
                change_hw
                ;;
            autostart)
                change_autostart
                ;;
            display)
                change_display
                ;;
            h|help|-h|--help)
                show_change_help
                ;;
            *)
                print_failed "${BOLD} Invalid option: ${C}$2"
                echo "${R}[${C}-${R}]${G} Use --change help to show help${W}"
                ;;
        esac
        ;;
    --reinstall|-ri)
        IFS=',' read -ra OPTIONS <<< "$2"
        for option in "${OPTIONS[@]}"; do
            case $option in
                icons)
                    reinstall_icons
                    ;;
                themes)
                    reinstall_themes
                    ;;
                config)
                    reinstall_config
                    ;;
                h|help|-h|--help)
                    show_reinstall_help
                    exit
                    ;;
                *)
                    print_failed "${BOLD} Invalid option: ${C}$option"
                    echo "${R}[${C}-${R}]${G} Use --reinstall help to show help${W}"
                    ;;
            esac
        done
        ;;
    --update)
        check_for_update_and_update_installer "$1"
        check_for_appstore_update
        ;;
    --help|-h)
        show_help
        ;;
    --reset)
        reset_changes
        ;;
    *)
        if [[ -n "$1" ]]; then
            print_failed "${BOLD} Invalid option: ${C}$1"
            show_help
        else
            install_termux_desktop
        fi
        ;;
esac