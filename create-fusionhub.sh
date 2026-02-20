#!/bin/bash

# Function to display usage information
usage() {
  echo "Usage: $0 [--VM_NAME name] [--MEMORY memory_in_MB] [--CORES number_of_cores] [--NETWORK network_config] [--OS_TYPE os_type] [--IMG_NAME image_name] [--IMG_URL image_url] [--IMG_DIR image_directory] [--CI_ISO iso_name] [--IMG_NAME_LOCAL local_image_path] [--LICENSE license_key] [--STORAGE storage_pool] [--WAN_CONN_METHOD method] [--LAN_CONN_METHOD method]"
  echo ""
  echo "Options:"
  echo "  --VM_NAME     Name of the new VM (default: FusionHub)"
  echo "  --MEMORY      Memory for the VM in MB (default: 1024)"
  echo "  --CORES       Number of CPU cores (default: 2)"
  echo "  --NETWORK     Network configuration (default: virtio,bridge=vmbr0)"
  echo "  --OS_TYPE     Operating system type (default: l26)"
  echo "  --IMG_NAME    Name of the RAW image (default: fusionhub_sfcn-8.5.1s045-build5258.raw)"
  echo "  --IMG_URL     URL to download the RAW image (optional)"
  echo "  --IMG_DIR     Directory to store the downloaded image (default: /var/lib/vz/template/iso/)"
  echo "  --CI_ISO      Name of the ISO file for automated setup (optional)"
  echo "  --IMG_NAME_LOCAL  Path to local RAW image file (optional)"
  echo "  --LICENSE     License key for FusionHub (optional)"
  echo "  --STORAGE     Proxmox storage pool to use (default: auto-detect)"
  echo ""
  echo "Cloud-init WAN options (optional):"
  echo "  --WAN_CONN_METHOD        WAN connection method: dhcp, static, pppoe"
  echo "  --WAN_DNS_AUTO           WAN DNS auto setting: yes or no"
  echo "  --WAN_DNS_SERVERS        WAN DNS servers (quoted, space-separated IPs)"
  echo "  --WAN_IPADDR             WAN static IP address"
  echo "  --WAN_NETMASK            WAN static netmask"
  echo "  --WAN_GATEWAY            WAN static gateway"
  echo "  --WAN_PPPOE_USER         WAN PPPoE username"
  echo "  --WAN_PPPOE_PASSWORD     WAN PPPoE password"
  echo "  --WAN_PPPOE_SERVICE_NAME WAN PPPoE service name"
  echo ""
  echo "Cloud-init LAN options (optional):"
  echo "  --LAN_CONN_METHOD        LAN connection method: none, dhcp, static"
  echo "  --LAN_DHCP_CLIENT_ID     LAN DHCP client ID (optional)"
  echo "  --LAN_IPADDR             LAN static IP address"
  echo "  --LAN_NETMASK            LAN static netmask"
  echo "  --help, -h    Display this help message"
  exit 1
}

# Function to get the next available VMID
get_next_vmid() {
  pvesh get /cluster/nextid
}

# Function to get suitable storage pool for VM disk images
# Finds ANY storage that supports images and has > 1GB free space
get_storage() {
  # Get first storage pool that:
  # - Supports 'images' content type
  # - Has more than 1GB (1048576 KiB) available space
  # awk: NR>1 skips header, $6>1048576 checks available space, print first match
  pvesm status --content images | awk 'NR>1 && $6>1048576 {print $1; exit}'
}

join_path() {
  local dir="$1"
  local file="$2"

  if [ -z "$dir" ]; then
    printf "%s\n" "$file"
    return
  fi

  while [ "$dir" != "/" ] && [ "${dir%/}" != "$dir" ]; do
    dir="${dir%/}"
  done

  if [ "$dir" = "/" ]; then
    printf "/%s\n" "$file"
  else
    printf "%s/%s\n" "$dir" "$file"
  fi
}

derive_img_name_from_url() {
  local url="$1"
  local clean_url="$url"
  local no_scheme=""
  local path_part=""
  local file_name=""

  clean_url="${clean_url%%\#*}"
  clean_url="${clean_url%%\?*}"

  if [ -z "$clean_url" ] || [ "${clean_url%/}" != "$clean_url" ]; then
    printf "\n"
    return
  fi

  no_scheme="${clean_url#*://}"
  path_part="${no_scheme#*/}"
  if [ "$path_part" = "$no_scheme" ] || [ -z "$path_part" ]; then
    printf "\n"
    return
  fi

  file_name="${path_part##*/}"
  if [ -z "$file_name" ]; then
    printf "\n"
    return
  fi

  printf "%s\n" "$file_name"
}

# Simplified Function to download the RAW image if it doesn't exist or is zero bytes
download_image() {
  local img_url=$1
  local img_path=$2

  if [ ! -f "$img_path" ] || [ ! -s "$img_path" ]; then
    echo "📥 Image does not exist or is empty. Downloading..."
    wget -O "$img_path" "$img_url" || { echo "❌ Download failed."; exit 1; }
    echo "✅ Image downloaded successfully."
  else
    echo "✅ Image exists and is valid. Skipping download."
  fi
}

# Function to create a new VM
create_vm() {
  local vmid=$1
  local vm_name=$2
  local memory=$3
  local cores=$4
  local network=$5
  local os_type=$6

  echo "🔧 Creating VM with ID $vmid..."
  qm create "$vmid" --name "$vm_name" --memory "$memory" --cores "$cores" --net0 "$network" --ostype "$os_type" || { echo "❌ VM creation failed."; exit 1; }
}

# Function to import and attach the RAW disk image to the VM
attach_disk() {
  local vmid=$1
  local img_path=$2
  local storage=$3

  echo "🖇️  Importing disk image to VM $vmid..."
  local import_output=""
  if ! import_output=$(qm importdisk "$vmid" "$img_path" "$storage" 2>&1); then
    echo "$import_output"
    echo "❌ Disk import failed."
    exit 1
  fi

  # Proxmox "dir" storage requires a full volid like "local:115/vm-115-disk-0.raw",
  # while other backends may use "storage:vm-115-disk-0". Use the returned volid.
  local disk_volid=""
  disk_volid="$(printf '%s\n' "$import_output" | sed -nE "s/.*successfully imported disk '([^']+)'.*/\\1/p" | tail -n 1)"
  if [ -z "$disk_volid" ]; then
    disk_volid="$(qm config "$vmid" | awk -F': ' '/^unused[0-9]+:/{print $2; exit}')"
  fi
  if [ -z "$disk_volid" ]; then
    echo "$import_output"
    echo "❌ Could not determine imported disk volume ID."
    exit 1
  fi

  qm set "$vmid" --scsihw virtio-scsi-pci --scsi0 "$disk_volid" || { echo "❌ Setting disk failed."; exit 1; }
}

# Function to configure the VM boot options
configure_boot() {
  local vmid=$1

  echo "🔄 Configuring boot options for VM $vmid..."
  qm set "$vmid" --boot c --bootdisk scsi0 --onboot 1 || { echo "❌ Boot configuration failed."; exit 1; }
}

# Function to attach ISO and start VM if CI mode
attach_iso_and_start() {
  local vmid=$1
  local iso_name=$2
  
  local iso_path="/var/lib/vz/template/iso/$iso_name"
  
  if [ -f "$iso_path" ]; then
    echo "💿 Attaching ISO $iso_name to VM $vmid..."
    qm set "$vmid" --ide2 "local:iso/$iso_name,media=cdrom" || { echo "❌ ISO attachment failed."; exit 1; }
    echo "🚀 Starting VM $vmid..."
    qm start "$vmid" || { echo "❌ VM start failed."; exit 1; }
  else
    echo "❌ ISO file $iso_path not found."
    exit 1
  fi
}

print_cloud_init_iso_layout_and_contents() {
  local iso_path=$1
  local -a iso_entries=()
  local -a iso_files=()
  local entry=""
  local file_entry=""
  local file_name=""
  local i=0
  local branch_prefix=""
  local -i entry_count=0

  if ! command -v isoinfo >/dev/null 2>&1; then
    echo "⚠️  Skipping ISO content dump: 'isoinfo' is not installed."
    return
  fi

  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    iso_entries+=("$entry")
  done < <(isoinfo -i "$iso_path" -R -f 2>/dev/null | sort)

  for entry in "${iso_entries[@]}"; do
    if [ "${entry: -1}" != "/" ]; then
      iso_files+=("$entry")
    fi
  done

  entry_count=${#iso_entries[@]}

  echo "📁 Cloud-init ISO file structure:"
  echo "$iso_path"
  if [ "$entry_count" -eq 0 ]; then
    echo "└── (no entries found)"
  else
    for i in "${!iso_entries[@]}"; do
      entry="${iso_entries[$i]}"
      if [ "$i" -eq $((entry_count - 1)) ]; then
        branch_prefix="└──"
      else
        branch_prefix="├──"
      fi
      echo "${branch_prefix} ${entry}"
    done
  fi

  echo "📄 Cloud-init ISO file contents:"
  if [ "${#iso_files[@]}" -eq 0 ]; then
    echo "(no files to display)"
    return
  fi

  for file_entry in "${iso_files[@]}"; do
    file_name="$(basename "$file_entry")"
    echo "----- BEGIN ${file_name} (${file_entry}) -----"
    isoinfo -i "$iso_path" -R -x "$file_entry" 2>/dev/null
    echo "----- END ${file_name} (${file_entry}) -----"
  done
}

create_cloud_init_iso() {
  local user_data=$1
  local vmid=$2
  local vm_name=$3
  local iso_name="vmid${vmid}-${vm_name}-cloudinit.iso"
  local iso_path="/var/lib/vz/template/iso/$iso_name"
  local temp_dir=$(mktemp -d)
  
  # Create user-data file
  printf "%s\n" "$user_data" > "$temp_dir/user-data"

  # Create the ISO
  genisoimage -output "$iso_path" -volid cidata -joliet -rock "$temp_dir/user-data"

  # Print generated ISO layout and file contents for verification.
  print_cloud_init_iso_layout_and_contents "$iso_path"
  
  # Clean up
  rm -rf "$temp_dir"
  
  echo "✅ Created Cloud-init ISO at $iso_path" >&2
  echo "$iso_name"
}

is_valid_choice() {
  local value=$1
  shift
  local choices=("$@")
  local choice
  for choice in "${choices[@]}"; do
    if [ "$value" = "$choice" ]; then
      return 0
    fi
  done
  return 1
}

has_any_cloud_init_network_arg() {
  [ "$WAN_CONN_METHOD_SET" = true ] || [ "$WAN_DNS_AUTO_SET" = true ] || [ "$WAN_DNS_SERVERS_SET" = true ] || [ "$WAN_IPADDR_SET" = true ] || [ "$WAN_NETMASK_SET" = true ] || [ "$WAN_GATEWAY_SET" = true ] || [ "$WAN_PPPOE_USER_SET" = true ] || [ "$WAN_PPPOE_PASSWORD_SET" = true ] || [ "$WAN_PPPOE_SERVICE_NAME_SET" = true ] || [ "$LAN_CONN_METHOD_SET" = true ] || [ "$LAN_DHCP_CLIENT_ID_SET" = true ] || [ "$LAN_IPADDR_SET" = true ] || [ "$LAN_NETMASK_SET" = true ]
}

validate_cloud_init_network_config() {
  local has_wan_detail=false
  local has_lan_detail=false
  local wan_method=""
  local lan_method=""

  if [ "$WAN_DNS_AUTO_SET" = true ] || [ "$WAN_DNS_SERVERS_SET" = true ] || [ "$WAN_IPADDR_SET" = true ] || [ "$WAN_NETMASK_SET" = true ] || [ "$WAN_GATEWAY_SET" = true ] || [ "$WAN_PPPOE_USER_SET" = true ] || [ "$WAN_PPPOE_PASSWORD_SET" = true ] || [ "$WAN_PPPOE_SERVICE_NAME_SET" = true ]; then
    has_wan_detail=true
  fi

  if [ "$LAN_DHCP_CLIENT_ID_SET" = true ] || [ "$LAN_IPADDR_SET" = true ] || [ "$LAN_NETMASK_SET" = true ]; then
    has_lan_detail=true
  fi

  if [ "$has_wan_detail" = true ] && [ "$WAN_CONN_METHOD_SET" != true ]; then
    echo "❌ WAN fields were provided but --WAN_CONN_METHOD is missing."
    usage
  fi

  if [ "$has_lan_detail" = true ] && [ "$LAN_CONN_METHOD_SET" != true ]; then
    echo "❌ LAN fields were provided but --LAN_CONN_METHOD is missing."
    usage
  fi

  if [ "$WAN_CONN_METHOD_SET" = true ]; then
    wan_method="$WAN_CONN_METHOD"
    if ! is_valid_choice "$wan_method" "dhcp" "static" "pppoe"; then
      echo "❌ Invalid --WAN_CONN_METHOD '$wan_method'. Must be one of: dhcp, static, pppoe."
      usage
    fi

    case "$wan_method" in
      dhcp)
        if [ "$WAN_DNS_AUTO_SET" = true ] && ! is_valid_choice "$WAN_DNS_AUTO" "yes" "no"; then
          echo "❌ Invalid --WAN_DNS_AUTO '$WAN_DNS_AUTO'. Must be yes or no."
          usage
        fi
        if [ "$WAN_DNS_AUTO_SET" != true ]; then
          WAN_DNS_AUTO="yes"
        fi
        if [ "$WAN_DNS_AUTO" = "no" ] && [ -z "$WAN_DNS_SERVERS" ]; then
          echo "❌ --WAN_DNS_SERVERS is required when --WAN_CONN_METHOD=dhcp and --WAN_DNS_AUTO=no."
          usage
        fi
        if [ "$WAN_IPADDR_SET" = true ] || [ "$WAN_NETMASK_SET" = true ] || [ "$WAN_GATEWAY_SET" = true ] || [ "$WAN_PPPOE_USER_SET" = true ] || [ "$WAN_PPPOE_PASSWORD_SET" = true ] || [ "$WAN_PPPOE_SERVICE_NAME_SET" = true ]; then
          echo "❌ Static/PPPoE WAN fields are not allowed when --WAN_CONN_METHOD=dhcp."
          usage
        fi
        ;;
      static)
        if [ -z "$WAN_IPADDR" ] || [ -z "$WAN_NETMASK" ] || [ -z "$WAN_GATEWAY" ] || [ -z "$WAN_DNS_SERVERS" ]; then
          echo "❌ --WAN_CONN_METHOD=static requires --WAN_IPADDR, --WAN_NETMASK, --WAN_GATEWAY, and --WAN_DNS_SERVERS."
          usage
        fi
        if [ "$WAN_DNS_AUTO_SET" = true ] || [ "$WAN_PPPOE_USER_SET" = true ] || [ "$WAN_PPPOE_PASSWORD_SET" = true ] || [ "$WAN_PPPOE_SERVICE_NAME_SET" = true ]; then
          echo "❌ --WAN_DNS_AUTO and PPPoE fields are not allowed when --WAN_CONN_METHOD=static."
          usage
        fi
        ;;
      pppoe)
        if [ -z "$WAN_PPPOE_USER" ] || [ -z "$WAN_PPPOE_PASSWORD" ] || [ -z "$WAN_PPPOE_SERVICE_NAME" ]; then
          echo "❌ --WAN_CONN_METHOD=pppoe requires --WAN_PPPOE_USER, --WAN_PPPOE_PASSWORD, and --WAN_PPPOE_SERVICE_NAME."
          usage
        fi
        if [ "$WAN_DNS_AUTO_SET" = true ] && ! is_valid_choice "$WAN_DNS_AUTO" "yes" "no"; then
          echo "❌ Invalid --WAN_DNS_AUTO '$WAN_DNS_AUTO'. Must be yes or no."
          usage
        fi
        if [ "$WAN_DNS_AUTO_SET" != true ]; then
          WAN_DNS_AUTO="yes"
        fi
        if [ "$WAN_DNS_AUTO" = "no" ] && [ -z "$WAN_DNS_SERVERS" ]; then
          echo "❌ --WAN_DNS_SERVERS is required when --WAN_CONN_METHOD=pppoe and --WAN_DNS_AUTO=no."
          usage
        fi
        if [ "$WAN_IPADDR_SET" = true ] || [ "$WAN_NETMASK_SET" = true ] || [ "$WAN_GATEWAY_SET" = true ]; then
          echo "❌ Static WAN fields are not allowed when --WAN_CONN_METHOD=pppoe."
          usage
        fi
        ;;
    esac
  fi

  if [ "$LAN_CONN_METHOD_SET" = true ]; then
    lan_method="$LAN_CONN_METHOD"
    if ! is_valid_choice "$lan_method" "none" "dhcp" "static"; then
      echo "❌ Invalid --LAN_CONN_METHOD '$lan_method'. Must be one of: none, dhcp, static."
      usage
    fi

    case "$lan_method" in
      none)
        if [ "$LAN_DHCP_CLIENT_ID_SET" = true ] || [ "$LAN_IPADDR_SET" = true ] || [ "$LAN_NETMASK_SET" = true ]; then
          echo "❌ LAN DHCP/static fields are not allowed when --LAN_CONN_METHOD=none."
          usage
        fi
        ;;
      dhcp)
        if [ "$LAN_IPADDR_SET" = true ] || [ "$LAN_NETMASK_SET" = true ]; then
          echo "❌ --LAN_IPADDR and --LAN_NETMASK are not allowed when --LAN_CONN_METHOD=dhcp."
          usage
        fi
        ;;
      static)
        if [ -z "$LAN_IPADDR" ] || [ -z "$LAN_NETMASK" ]; then
          echo "❌ --LAN_CONN_METHOD=static requires --LAN_IPADDR and --LAN_NETMASK."
          usage
        fi
        if [ "$LAN_DHCP_CLIENT_ID_SET" = true ]; then
          echo "❌ --LAN_DHCP_CLIENT_ID is not allowed when --LAN_CONN_METHOD=static."
          usage
        fi
        ;;
    esac
  fi
}

build_cloud_init_user_data() {
  local user_data='TYPE="Peplink_User_Data"'
  user_data+=$'\n''VERSION="1"'

  if [ -n "$LICENSE" ]; then
    user_data+=$'\n''LICENSE="'"$LICENSE"'"'
  fi

  if [ "$WAN_CONN_METHOD_SET" = true ]; then
    user_data+=$'\n''WAN_CONN_METHOD="'"$WAN_CONN_METHOD"'"'
    case "$WAN_CONN_METHOD" in
      dhcp)
        user_data+=$'\n''WAN_DNS_AUTO="'"$WAN_DNS_AUTO"'"'
        if [ "$WAN_DNS_AUTO" = "no" ]; then
          user_data+=$'\n''WAN_DNS_SERVERS="'"$WAN_DNS_SERVERS"'"'
        fi
        ;;
      static)
        user_data+=$'\n''WAN_IPADDR="'"$WAN_IPADDR"'"'
        user_data+=$'\n''WAN_NETMASK="'"$WAN_NETMASK"'"'
        user_data+=$'\n''WAN_GATEWAY="'"$WAN_GATEWAY"'"'
        user_data+=$'\n''WAN_DNS_SERVERS="'"$WAN_DNS_SERVERS"'"'
        ;;
      pppoe)
        user_data+=$'\n''WAN_PPPOE_USER="'"$WAN_PPPOE_USER"'"'
        user_data+=$'\n''WAN_PPPOE_PASSWORD="'"$WAN_PPPOE_PASSWORD"'"'
        user_data+=$'\n''WAN_PPPOE_SERVICE_NAME="'"$WAN_PPPOE_SERVICE_NAME"'"'
        user_data+=$'\n''WAN_DNS_AUTO="'"$WAN_DNS_AUTO"'"'
        if [ "$WAN_DNS_AUTO" = "no" ]; then
          user_data+=$'\n''WAN_DNS_SERVERS="'"$WAN_DNS_SERVERS"'"'
        fi
        ;;
    esac
  fi

  if [ "$LAN_CONN_METHOD_SET" = true ]; then
    user_data+=$'\n''LAN_CONN_METHOD="'"$LAN_CONN_METHOD"'"'
    case "$LAN_CONN_METHOD" in
      dhcp)
        if [ -n "$LAN_DHCP_CLIENT_ID" ]; then
          user_data+=$'\n''LAN_DHCP_CLIENT_ID="'"$LAN_DHCP_CLIENT_ID"'"'
        fi
        ;;
      static)
        user_data+=$'\n''LAN_IPADDR="'"$LAN_IPADDR"'"'
        user_data+=$'\n''LAN_NETMASK="'"$LAN_NETMASK"'"'
        ;;
    esac
  fi

  printf "%s\n" "$user_data"
}

# Default Variables
VM_NAME="FusionHub"                                # Name of the new VM
CORES=2                                            # Number of CPU cores
MEMORY=1024                                        # Memory for the VM (in MB)
NETWORK="virtio,bridge=vmbr0"                      # Network configuration
OS_TYPE="l26"                                      # Operating system type (change accordingly)
IMG_NAME="fusionhub_sfcn-8.5.1s045-build5258.raw"       # Name of the downloaded image
IMG_URL="https://download.peplink.com/firmware/fusionhub/$IMG_NAME" # URL of the RAW image
IMG_DIR="/var/lib/vz/template/iso/"                # Directory to store the downloaded image
IMG_PATH="$(join_path "$IMG_DIR" "$IMG_NAME")"     # Full path to the image
CI_ISO=""                                          # Optional ISO for automated setup
IMG_NAME_LOCAL=""                                  # Optional local image path
LICENSE=""                                         # Optional license key
STORAGE=""                                         # Storage pool (auto-detected if not specified)
WAN_CONN_METHOD=""
WAN_DNS_AUTO=""
WAN_DNS_SERVERS=""
WAN_IPADDR=""
WAN_NETMASK=""
WAN_GATEWAY=""
WAN_PPPOE_USER=""
WAN_PPPOE_PASSWORD=""
WAN_PPPOE_SERVICE_NAME=""
LAN_CONN_METHOD=""
LAN_DHCP_CLIENT_ID=""
LAN_IPADDR=""
LAN_NETMASK=""

# Flags to track if variables are set via arguments
VM_NAME_SET=false
MEMORY_SET=false
CORES_SET=false
NETWORK_SET=false
OS_TYPE_SET=false
IMG_NAME_SET=false
IMG_URL_SET=false
IMG_DIR_SET=false
CI_ISO_SET=false
IMG_NAME_LOCAL_SET=false
LICENSE_SET=false
STORAGE_SET=false
WAN_CONN_METHOD_SET=false
WAN_DNS_AUTO_SET=false
WAN_DNS_SERVERS_SET=false
WAN_IPADDR_SET=false
WAN_NETMASK_SET=false
WAN_GATEWAY_SET=false
WAN_PPPOE_USER_SET=false
WAN_PPPOE_PASSWORD_SET=false
WAN_PPPOE_SERVICE_NAME_SET=false
LAN_CONN_METHOD_SET=false
LAN_DHCP_CLIENT_ID_SET=false
LAN_IPADDR_SET=false
LAN_NETMASK_SET=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    --VM_NAME)
      VM_NAME="$2"
      VM_NAME_SET=true
      shift # past argument
      shift # past value
      ;;
    --MEMORY)
      MEMORY="$2"
      MEMORY_SET=true
      shift
      shift
      ;;
    --CORES)
      CORES="$2"
      CORES_SET=true
      shift
      shift
      ;;
    --NETWORK)
      NETWORK="$2"
      NETWORK_SET=true
      shift
      shift
      ;;
    --OS_TYPE)
      OS_TYPE="$2"
      OS_TYPE_SET=true
      shift
      shift
      ;;
    --IMG_NAME)
      IMG_NAME="$2"
      if [ "$IMG_URL_SET" = false ]; then
        IMG_URL="https://download.peplink.com/firmware/fusionhub/$IMG_NAME" # Update IMG_URL if IMG_NAME changes and IMG_URL not explicitly set
      fi
      IMG_PATH="$(join_path "$IMG_DIR" "$IMG_NAME")"
      IMG_NAME_SET=true
      shift
      shift
      ;;
    --IMG_URL)
      IMG_URL="$2"
      IMG_URL_SET=true
      shift
      shift
      ;;
    --IMG_DIR)
      IMG_DIR="$2"
      IMG_PATH="$(join_path "$IMG_DIR" "$IMG_NAME")"
      IMG_DIR_SET=true
      shift
      shift
      ;;
    --CI_ISO)
      CI_ISO="$2"
      CI_ISO_SET=true
      shift
      shift
      ;;
    --IMG_NAME_LOCAL)
      IMG_NAME_LOCAL="$2"
      IMG_NAME_LOCAL_SET=true
      shift
      shift
      ;;
    --LICENSE)
      LICENSE="$2"
      LICENSE_SET=true
      shift
      shift
      ;;
    --STORAGE)
      STORAGE="$2"
      STORAGE_SET=true
      shift
      shift
      ;;
    --WAN_CONN_METHOD)
      WAN_CONN_METHOD="$2"
      WAN_CONN_METHOD_SET=true
      shift
      shift
      ;;
    --WAN_DNS_AUTO)
      WAN_DNS_AUTO="$2"
      WAN_DNS_AUTO_SET=true
      shift
      shift
      ;;
    --WAN_DNS_SERVERS)
      WAN_DNS_SERVERS="$2"
      WAN_DNS_SERVERS_SET=true
      shift
      shift
      ;;
    --WAN_IPADDR)
      WAN_IPADDR="$2"
      WAN_IPADDR_SET=true
      shift
      shift
      ;;
    --WAN_NETMASK)
      WAN_NETMASK="$2"
      WAN_NETMASK_SET=true
      shift
      shift
      ;;
    --WAN_GATEWAY)
      WAN_GATEWAY="$2"
      WAN_GATEWAY_SET=true
      shift
      shift
      ;;
    --WAN_PPPOE_USER)
      WAN_PPPOE_USER="$2"
      WAN_PPPOE_USER_SET=true
      shift
      shift
      ;;
    --WAN_PPPOE_PASSWORD)
      WAN_PPPOE_PASSWORD="$2"
      WAN_PPPOE_PASSWORD_SET=true
      shift
      shift
      ;;
    --WAN_PPPOE_SERVICE_NAME)
      WAN_PPPOE_SERVICE_NAME="$2"
      WAN_PPPOE_SERVICE_NAME_SET=true
      shift
      shift
      ;;
    --LAN_CONN_METHOD)
      LAN_CONN_METHOD="$2"
      LAN_CONN_METHOD_SET=true
      shift
      shift
      ;;
    --LAN_DHCP_CLIENT_ID)
      LAN_DHCP_CLIENT_ID="$2"
      LAN_DHCP_CLIENT_ID_SET=true
      shift
      shift
      ;;
    --LAN_IPADDR)
      LAN_IPADDR="$2"
      LAN_IPADDR_SET=true
      shift
      shift
      ;;
    --LAN_NETMASK)
      LAN_NETMASK="$2"
      LAN_NETMASK_SET=true
      shift
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "❌ Unknown option: $1"
      usage
      ;;
  esac
done

# If --IMG_URL is provided without --IMG_NAME, derive local filename from URL.
if [ "$IMG_URL_SET" = true ] && [ "$IMG_NAME_SET" = false ]; then
  IMG_NAME="$(derive_img_name_from_url "$IMG_URL")"
  if [ -z "$IMG_NAME" ]; then
    echo "❌ Could not derive image filename from --IMG_URL. Please provide --IMG_NAME explicitly."
    usage
  fi
  IMG_PATH="$(join_path "$IMG_DIR" "$IMG_NAME")"
fi

validate_cloud_init_network_config

# Function to display variable values and their source
display_variables() {
  echo "----------------------------------------"
  echo "📋 Configuration Summary:"
  echo "----------------------------------------"
  echo "VM_NAME : $VM_NAME ($( [ "$VM_NAME_SET" = true ] && echo "user-defined" || echo "default"))"
  echo "MEMORY  : $MEMORY MB ($( [ "$MEMORY_SET" = true ] && echo "user-defined" || echo "default"))"
  echo "CORES   : $CORES ($( [ "$CORES_SET" = true ] && echo "user-defined" || echo "default"))"
  echo "NETWORK : $NETWORK ($( [ "$NETWORK_SET" = true ] && echo "user-defined" || echo "default"))"
  echo "OS_TYPE : $OS_TYPE ($( [ "$OS_TYPE_SET" = true ] && echo "user-defined" || echo "default"))"
  echo "IMG_NAME: $IMG_NAME ($( [ "$IMG_NAME_SET" = true ] && echo "user-defined" || echo "default"))"
  echo "IMG_DIR : $IMG_DIR ($( [ "$IMG_DIR_SET" = true ] && echo "user-defined" || echo "default"))"
  echo "CI_ISO  : ${CI_ISO:-None} ($( [ "$CI_ISO_SET" = true ] && echo "user-defined" || echo "not set"))"
  echo "IMG_NAME_LOCAL: ${IMG_NAME_LOCAL:-None} ($( [ "$IMG_NAME_LOCAL_SET" = true ] && echo "user-defined" || echo "not set"))"
  echo "LICENSE : ${LICENSE:-None} ($( [ "$LICENSE_SET" = true ] && echo "user-defined" || echo "not set"))"
  echo "WAN_CONN_METHOD : ${WAN_CONN_METHOD:-None} ($( [ "$WAN_CONN_METHOD_SET" = true ] && echo "user-defined" || echo "not set"))"
  echo "LAN_CONN_METHOD : ${LAN_CONN_METHOD:-None} ($( [ "$LAN_CONN_METHOD_SET" = true ] && echo "user-defined" || echo "not set"))"
  if has_any_cloud_init_network_arg; then
    echo "WAN_DNS_AUTO : ${WAN_DNS_AUTO:-None} ($( [ "$WAN_DNS_AUTO_SET" = true ] && echo "user-defined" || echo "default/derived"))"
    echo "WAN_DNS_SERVERS : ${WAN_DNS_SERVERS:-None} ($( [ "$WAN_DNS_SERVERS_SET" = true ] && echo "user-defined" || echo "not set"))"
    echo "WAN_IPADDR : ${WAN_IPADDR:-None} ($( [ "$WAN_IPADDR_SET" = true ] && echo "user-defined" || echo "not set"))"
    echo "WAN_NETMASK : ${WAN_NETMASK:-None} ($( [ "$WAN_NETMASK_SET" = true ] && echo "user-defined" || echo "not set"))"
    echo "WAN_GATEWAY : ${WAN_GATEWAY:-None} ($( [ "$WAN_GATEWAY_SET" = true ] && echo "user-defined" || echo "not set"))"
    echo "WAN_PPPOE_USER : ${WAN_PPPOE_USER:-None} ($( [ "$WAN_PPPOE_USER_SET" = true ] && echo "user-defined" || echo "not set"))"
    echo "WAN_PPPOE_PASSWORD : $( [ "$WAN_PPPOE_PASSWORD_SET" = true ] && echo "<set>" || echo "None" ) ($( [ "$WAN_PPPOE_PASSWORD_SET" = true ] && echo "user-defined" || echo "not set"))"
    echo "WAN_PPPOE_SERVICE_NAME : ${WAN_PPPOE_SERVICE_NAME:-None} ($( [ "$WAN_PPPOE_SERVICE_NAME_SET" = true ] && echo "user-defined" || echo "not set"))"
    echo "LAN_DHCP_CLIENT_ID : ${LAN_DHCP_CLIENT_ID:-None} ($( [ "$LAN_DHCP_CLIENT_ID_SET" = true ] && echo "user-defined" || echo "not set"))"
    echo "LAN_IPADDR : ${LAN_IPADDR:-None} ($( [ "$LAN_IPADDR_SET" = true ] && echo "user-defined" || echo "not set"))"
    echo "LAN_NETMASK : ${LAN_NETMASK:-None} ($( [ "$LAN_NETMASK_SET" = true ] && echo "user-defined" || echo "not set"))"
  fi
  echo "STORAGE : ${STORAGE:-Auto-detect} ($( [ "$STORAGE_SET" = true ] && echo "user-defined" || echo "auto-detect"))"
  if [ -z "$IMG_NAME_LOCAL" ]; then
    echo "IMG_URL : $IMG_URL ($( [ "$IMG_URL_SET" = true ] && echo "user-defined" || echo "auto-generated"))"
    echo "IMG_PATH: $IMG_PATH"
  fi
  echo "----------------------------------------"
}

# Display the variables and their sources
display_variables

# Derived Variables
VMID=$(get_next_vmid)           # Automatically assign the next available VMID

# Get storage pool - use user-specified or auto-detect
if [ -z "$STORAGE" ]; then
  STORAGE=$(get_storage)
  STORAGE_SOURCE="auto-detected"
else
  STORAGE_SOURCE="user-specified"
  # Validate that the user-specified storage exists and supports images
  if ! pvesm status --content images | grep -q "^$STORAGE "; then
    echo "❌ Storage pool '$STORAGE' not found or does not support disk images."
    echo "Available storage pools that support disk images:"
    pvesm status --content images | awk 'NR>1 {print "   - " $1 " (Type: " $2 ")"}'
    exit 1
  fi
fi

# Check if STORAGE is found
if [ -z "$STORAGE" ]; then
  echo "❌ No suitable storage pool found that supports disk images."
  echo "Available storage pools that support disk images:"
  pvesm status --content images | awk 'NR>1 {print "   - " $1 " (Type: " $2 ")"}'
  exit 1
fi

# Display selected storage
STORAGE_TYPE=$(pvesm status | grep "^$STORAGE " | awk '{print $2}')
echo "📦 Using storage: $STORAGE (Type: $STORAGE_TYPE, Source: $STORAGE_SOURCE)"

# Handle image source - either local or download
if [ -n "$IMG_NAME_LOCAL" ]; then
  if [ -f "$IMG_NAME_LOCAL" ]; then
    echo "✅ Using local image: $IMG_NAME_LOCAL"
    IMG_PATH="$IMG_NAME_LOCAL"
  else
    echo "❌ Local image file not found: $IMG_NAME_LOCAL"
    exit 1
  fi
else
  # Create the image directory if it doesn't exist
  mkdir -p "$IMG_DIR" || { echo "❌ Failed to create directory '$IMG_DIR'."; exit 1; }
  # Download the RAW image if it doesn't already exist or is zero bytes
  download_image "$IMG_URL" "$IMG_PATH"
fi

# Create a new VM
create_vm "$VMID" "$VM_NAME" "$MEMORY" "$CORES" "$NETWORK" "$OS_TYPE"

# Import and attach the RAW disk image to the VM
attach_disk "$VMID" "$IMG_PATH" "$STORAGE"

# Configure the VM boot options
configure_boot "$VMID"

# If LICENSE or cloud-init network settings are provided, generate Cloud-init ISO.
if [ -n "$LICENSE" ] || has_any_cloud_init_network_arg; then
  if [ -n "$CI_ISO" ]; then
    echo "ℹ️  Ignoring --CI_ISO because generated cloud-init content takes precedence."
  fi
  CI_USER_DATA="$(build_cloud_init_user_data)"
  CI_ISO=$(create_cloud_init_iso "$CI_USER_DATA" "$VMID" "$VM_NAME")
  CI_ISO_SET=true
fi

# If CI_ISO is provided, attach it and start the VM
if [ -n "$CI_ISO" ]; then
  attach_iso_and_start "$VMID" "$CI_ISO"
else
  echo "✅ VM with ID $VMID ('$VM_NAME') created and RAW image attached successfully."
fi
