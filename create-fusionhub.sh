#!/bin/bash

# Function to display usage information
usage() {
  echo "Usage: $0 [--VM_NAME name] [--MEMORY memory_in_MB] [--CORES number_of_cores] [--NETWORK network_config] [--OS_TYPE os_type] [--IMG_NAME image_name] [--IMG_DIR image_directory] [--CI_ISO iso_name]"
  echo ""
  echo "Options:"
  echo "  --VM_NAME     Name of the new VM (default: FusionHub)"
  echo "  --MEMORY      Memory for the VM in MB (default: 1024)"
  echo "  --CORES       Number of CPU cores (default: 2)"
  echo "  --NETWORK     Network configuration (default: virtio,bridge=vmbr0)"
  echo "  --OS_TYPE     Operating system type (default: l26)"
  echo "  --IMG_NAME    Name of the RAW image (default: fusionhub_sfcn-8.5.1-build5246.raw)"
  echo "  --IMG_DIR     Directory to store the downloaded image (default: /var/lib/vz/template/iso/)"
  echo "  --CI_ISO      Name of the ISO file for automated setup (optional)"
  echo "  --help, -h    Display this help message"
  exit 1
}

# Function to get the next available VMID
get_next_vmid() {
  pvesh get /cluster/nextid
}

# Function to get the LVM storage pool
get_lvm_storage() {
  pvesm status | grep lvm | awk '{print $1}'
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
  qm importdisk "$vmid" "$img_path" "$storage" || { echo "❌ Disk import failed."; exit 1; }
  qm set "$vmid" --scsihw virtio-scsi-pci --scsi0 "${storage}:vm-${vmid}-disk-0" || { echo "❌ Setting disk failed."; exit 1; }
}

# Function to configure the VM boot options
configure_boot() {
  local vmid=$1

  echo "🔄 Configuring boot options for VM $vmid..."
  qm set "$vmid" --boot c --bootdisk scsi0 || { echo "❌ Boot configuration failed."; exit 1; }
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

# Default Variables
VM_NAME="FusionHub"                                # Name of the new VM
CORES=2                                            # Number of CPU cores
MEMORY=1024                                        # Memory for the VM (in MB)
NETWORK="virtio,bridge=vmbr0"                      # Network configuration
OS_TYPE="l26"                                      # Operating system type (change accordingly)
IMG_NAME="fusionhub_sfcn-8.5.1-build5246.raw"       # Name of the downloaded image
IMG_URL="https://download.peplink.com/firmware/fusionhub/$IMG_NAME" # URL of the RAW image
IMG_DIR="/var/lib/vz/template/iso/"                # Directory to store the downloaded image
IMG_PATH="$IMG_DIR/$IMG_NAME"                      # Full path to the image
CI_ISO=""                                          # Optional ISO for automated setup

# Flags to track if variables are set via arguments
VM_NAME_SET=false
MEMORY_SET=false
CORES_SET=false
NETWORK_SET=false
OS_TYPE_SET=false
IMG_NAME_SET=false
IMG_DIR_SET=false
CI_ISO_SET=false

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
      IMG_URL="https://download.peplink.com/firmware/fusionhub/$IMG_NAME" # Update IMG_URL if IMG_NAME changes
      IMG_PATH="$IMG_DIR/$IMG_NAME"
      IMG_NAME_SET=true
      shift
      shift
      ;;
    --IMG_DIR)
      IMG_DIR="$2"
      IMG_PATH="$IMG_DIR/$IMG_NAME"
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
    --help|-h)
      usage
      ;;
    *)
      echo "❌ Unknown option: $1"
      usage
      ;;
  esac
done

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
  echo "IMG_URL : $IMG_URL"
  echo "IMG_PATH: $IMG_PATH"
  echo "----------------------------------------"
}

# Display the variables and their sources
display_variables

# Derived Variables
VMID=$(get_next_vmid)           # Automatically assign the next available VMID
STORAGE=$(get_lvm_storage)      # Get the LVM storage pool dynamically

# Check if STORAGE is found
if [ -z "$STORAGE" ]; then
  echo "❌ No LVM storage found. Exiting."
  exit 1
fi

# Create the image directory if it doesn't exist
mkdir -p "$IMG_DIR" || { echo "❌ Failed to create directory '$IMG_DIR'."; exit 1; }

# Download the RAW image if it doesn't already exist or is zero bytes
download_image "$IMG_URL" "$IMG_PATH"

# Create a new VM
create_vm "$VMID" "$VM_NAME" "$MEMORY" "$CORES" "$NETWORK" "$OS_TYPE"

# Import and attach the RAW disk image to the VM
attach_disk "$VMID" "$IMG_PATH" "$STORAGE"

# Configure the VM boot options
configure_boot "$VMID"

# If CI_ISO is provided, attach it and start the VM
if [ -n "$CI_ISO" ]; then
  attach_iso_and_start "$VMID" "$CI_ISO"
else
  echo "✅ VM with ID $VMID ('$VM_NAME') created and RAW image attached successfully."
fi