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

### With Specific Storage Pool
```bash
# Create a VM using a specific storage pool (e.g., ZFS storage)
bash -c "$(wget -qLO - https://github.com/larrychannon/Create-FusionHub-on-Proxmox/raw/main/create-fusionhub.sh)" -- --STORAGE "local-zfs"
```

### Using Custom Image URL
```bash
# Create a VM using a custom download URL
bash -c "$(wget -qLO - https://github.com/larrychannon/Create-FusionHub-on-Proxmox/raw/main/create-fusionhub.sh)" -- --IMG_URL "https://example.com/path/to/fusionhub.raw"
```

### Cloud-init WAN DHCP (DNS Auto)
```bash
# Create a VM with license + WAN DHCP and DNS auto
bash -c "$(wget -qLO - https://github.com/larrychannon/Create-FusionHub-on-Proxmox/raw/main/create-fusionhub.sh)" -- \
  --LICENSE "your-license-key-here" \
  --WAN_CONN_METHOD "dhcp"
```

### Cloud-init WAN Static + LAN Static
```bash
# Create a VM with static WAN and static LAN settings
bash -c "$(wget -qLO - https://github.com/larrychannon/Create-FusionHub-on-Proxmox/raw/main/create-fusionhub.sh)" -- \
  --LICENSE "your-license-key-here" \
  --WAN_CONN_METHOD "static" \
  --WAN_IPADDR "10.8.8.8" \
  --WAN_NETMASK "255.255.255.0" \
  --WAN_GATEWAY "10.8.8.1" \
  --WAN_DNS_SERVERS "10.8.8.1 10.9.1.1" \
  --LAN_CONN_METHOD "static" \
  --LAN_IPADDR "192.168.10.1" \
  --LAN_NETMASK "255.255.255.0"
```

### Cloud-init WAN PPPoE + Manual DNS + LAN None
```bash
# Create a VM with WAN PPPoE and manual DNS servers
bash -c "$(wget -qLO - https://github.com/larrychannon/Create-FusionHub-on-Proxmox/raw/main/create-fusionhub.sh)" -- \
  --LICENSE "your-license-key-here" \
  --WAN_CONN_METHOD "pppoe" \
  --WAN_PPPOE_USER "Username" \
  --WAN_PPPOE_PASSWORD "Password" \
  --WAN_PPPOE_SERVICE_NAME "ServiceName" \
  --WAN_DNS_AUTO "no" \
  --WAN_DNS_SERVERS "10.8.8.1 10.9.1.1" \
  --LAN_CONN_METHOD "none"
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
- `--STORAGE`: Proxmox storage pool to use (default: auto-detect)
- `--LICENSE`: License key for FusionHub (optional)
- `--IMG_NAME_LOCAL`: Path to local RAW image file (optional)
- `--CI_ISO`: Existing cloud-init ISO to attach (optional; ignored when generated cloud-init is used)
- `--WAN_CONN_METHOD`: WAN mode (`dhcp`, `static`, `pppoe`)
- `--WAN_DNS_AUTO`: WAN DNS auto (`yes`, `no`) for `dhcp`/`pppoe` (default: `yes`)
- `--WAN_DNS_SERVERS`: Quoted, space-separated DNS IP list (required for static WAN; required when WAN DNS auto is `no`)
- `--WAN_IPADDR`: WAN static IP address (required for static WAN)
- `--WAN_NETMASK`: WAN static netmask (required for static WAN)
- `--WAN_GATEWAY`: WAN static gateway (required for static WAN)
- `--WAN_PPPOE_USER`: WAN PPPoE username (required for PPPoE WAN)
- `--WAN_PPPOE_PASSWORD`: WAN PPPoE password (required for PPPoE WAN)
- `--WAN_PPPOE_SERVICE_NAME`: WAN PPPoE service name (required for PPPoE WAN)
- `--LAN_CONN_METHOD`: LAN mode (`none`, `dhcp`, `static`)
- `--LAN_DHCP_CLIENT_ID`: Optional DHCP client ID (only for DHCP LAN)
- `--LAN_IPADDR`: LAN static IP address (required for static LAN)
- `--LAN_NETMASK`: LAN static netmask (required for static LAN)
- `--help` or `-h`: Display help message

## Cloud-init Network Configuration

Cloud-init network fields are only included if you provide WAN/LAN flags.
If you provide only `--LICENSE`, the generated cloud-init ISO contains only license data (same behavior as before).

When license and/or WAN/LAN flags are provided, the script generates cloud-init user-data in FusionHub format:

- `TYPE="Peplink_User_Data"`
- `VERSION="1"`
- `LICENSE="..."` (only if provided)
- WAN/LAN variables based on selected methods

If generated cloud-init content is requested and `--CI_ISO` is also provided, generated cloud-init takes precedence and `--CI_ISO` is ignored.

## WAN/LAN Method Matrix

### WAN

| WAN_CONN_METHOD | Required Fields | Optional Fields | Not Allowed |
|---|---|---|---|
| `dhcp` | None | `WAN_DNS_AUTO` (`yes`/`no`, default `yes`), `WAN_DNS_SERVERS` (required only when DNS auto is `no`) | Static fields, PPPoE fields |
| `static` | `WAN_IPADDR`, `WAN_NETMASK`, `WAN_GATEWAY`, `WAN_DNS_SERVERS` | None | `WAN_DNS_AUTO`, PPPoE fields |
| `pppoe` | `WAN_PPPOE_USER`, `WAN_PPPOE_PASSWORD`, `WAN_PPPOE_SERVICE_NAME` | `WAN_DNS_AUTO` (`yes`/`no`, default `yes`), `WAN_DNS_SERVERS` (required only when DNS auto is `no`) | Static fields |

### LAN

| LAN_CONN_METHOD | Required Fields | Optional Fields | Not Allowed |
|---|---|---|---|
| `none` | None | None | `LAN_DHCP_CLIENT_ID`, `LAN_IPADDR`, `LAN_NETMASK` |
| `dhcp` | None | `LAN_DHCP_CLIENT_ID` | `LAN_IPADDR`, `LAN_NETMASK` |
| `static` | `LAN_IPADDR`, `LAN_NETMASK` | None | `LAN_DHCP_CLIENT_ID` |
