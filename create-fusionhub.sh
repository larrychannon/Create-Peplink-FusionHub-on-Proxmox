#!/bin/bash

# Function to get the next available VMID
get_next_vmid() {
  pvesh get /cluster/nextid
}

# Function to get the LVM storage pool
get_lvm_storage() {
  pvesm status | grep lvm | awk '{print $1}'
}

# Function to download the RAW image if it doesn't exist
download_image() {
  local img_url=$1
  local img_path=$2

  if [ ! -f "$img_path" ]; then
    echo "Image not found. Downloading..."
    wget -O "$img_path" "$img_url"
  else
    echo "Image already exists. Skipping download."
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
  
  echo "qm create $vmid --name $vm_name --memory $memory --cores $cores --net0 $network --ostype $os_type"
  qm create "$vmid" --name "$vm_name" --memory "$memory" --cores "$cores" --net0 "$network" --ostype "$os_type"
}

# Function to import and attach the RAW disk image to the VM
attach_disk() {
  local vmid=$1
  local img_path=$2
  local storage=$3

  qm importdisk "$vmid" "$img_path" "$storage"
  qm set "$vmid" --scsihw virtio-scsi-pci --scsi0 "$storage:vm-$vmid-disk-0"
}

# Function to configure the VM boot options
configure_boot() {
  local vmid=$1

  qm set "$vmid" --boot c --bootdisk scsi0
}

# Main script logic

# Variables (Modify these as needed)
VM_NAME="FusionHub"             # Name of the new VM
CORES=2                         # Number of CPU cores
MEMORY=1024                     # Memory for the VM (in MB)
NETWORK="virtio,bridge=vmbr0"   # Network configuration
OS_TYPE="l26"                   # Operating system type (change accordingly)
IMG_NAME="fusionhub_sfcn-8.4.1-build5195.raw"            # Name of the downloaded image
IMG_URL="https://download.peplink.com/firmware/fusionhub/$IMG_NAME" # URL of the RAW image
IMG_DIR="/var/lib/vz/template/iso/"    # Directory to store the downloaded image
IMG_PATH="$IMG_DIR/$IMG_NAME"   # Full path to the image

# Derived Variables
VMID=$(get_next_vmid)           # Automatically assign the next available VMID
STORAGE=$(get_lvm_storage)      # Get the LVM storage pool dynamically

# Check if STORAGE is found
if [ -z "$STORAGE" ]; then
  echo "No LVM storage found. Exiting."
  exit 1
fi

# Create the image directory if it doesn't exist
mkdir -p "$IMG_DIR"

# Download the RAW image if it doesn't already exist
download_image "$IMG_URL" "$IMG_PATH"

# Create a new VM
create_vm "$VMID" "$VM_NAME" "$MEMORY" "$CORES" "$NETWORK" "$OS_TYPE"

# Import and attach the RAW disk image to the VM
attach_disk "$VMID" "$IMG_PATH" "$STORAGE"

# Configure the VM boot options
configure_boot "$VMID"

# Optionally, add more configurations here, like setting up a CD-ROM or additional hardware

echo "VM with ID $VMID created and RAW image attached."
