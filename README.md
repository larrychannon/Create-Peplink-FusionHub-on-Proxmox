# Create FusionHub on Proxmox

This script helps you create a FusionHub VM on Proxmox.

## Quick Start

Run the following command in your Proxmox shell to create a VM with default settings:

```bash
bash -c "$(wget -qLO - https://github.com/larrychannon/Create-FusionHub-on-Proxmox/raw/main/create-fusionhub.sh)"
```

## Usage Examples

### Custom VM Configuration
```bash
# Create a VM with custom name, memory, and CPU cores
bash -c "$(wget -qLO - https://github.com/larrychannon/Create-FusionHub-on-Proxmox/raw/main/create-fusionhub.sh)" -- --VM_NAME "MyFusionHub" --MEMORY 2048 --CORES 4
```

### With License
```bash
# Create a VM with a license key
bash -c "$(wget -qLO - https://github.com/larrychannon/Create-FusionHub-on-Proxmox/raw/main/create-fusionhub.sh)" -- --LICENSE "your-license-key-here"
```

### Complete Example
```bash
# Create a VM with all custom settings
bash -c "$(wget -qLO - https://github.com/larrychannon/Create-FusionHub-on-Proxmox/raw/main/create-fusionhub.sh)" -- \
  --VM_NAME "MyFusionHub" \
  --MEMORY 2048 \
  --CORES 4 \
  --NETWORK "virtio,bridge=vmbr0" \
  --OS_TYPE "l26" \
  --IMG_NAME "fusionhub_sfcn-8.5.1s045-build5258.raw" \
  --LICENSE "your-license-key-here"
```

### Using Local Image
```bash
# Create a VM using a local image file
bash -c "$(wget -qLO - https://github.com/larrychannon/Create-FusionHub-on-Proxmox/raw/main/create-fusionhub.sh)" -- --IMG_NAME_LOCAL "/path/to/your/image.raw"
```

### Using Custom Image URL
```bash
# Create a VM using a custom download URL
bash -c "$(wget -qLO - https://github.com/larrychannon/Create-FusionHub-on-Proxmox/raw/main/create-fusionhub.sh)" -- --IMG_URL "https://example.com/path/to/fusionhub.raw"
```

## Available Arguments

- `--VM_NAME`: Name of the new VM (default: FusionHub)
- `--MEMORY`: Memory for the VM in MB (default: 1024)
- `--CORES`: Number of CPU cores (default: 2)
- `--NETWORK`: Network configuration (default: virtio,bridge=vmbr0)
- `--OS_TYPE`: Operating system type (default: l26)
- `--IMG_NAME`: Name of the RAW image (default: fusionhub_sfcn-8.5.1s045-build5258.raw)
- `--IMG_URL`: URL to download the RAW image (optional)
- `--IMG_DIR`: Directory to store the downloaded image (default: /var/lib/vz/template/iso/)
- `--LICENSE`: License key for FusionHub (optional)
- `--IMG_NAME_LOCAL`: Path to local RAW image file (optional)
- `--help` or `-h`: Display help message
