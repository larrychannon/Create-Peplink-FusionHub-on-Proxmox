# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Cloud-init WAN/LAN network parameter support via CLI flags:
  - WAN: `dhcp`, `static`, `pppoe` methods with method-specific fields
  - LAN: `none`, `dhcp`, `static` methods with method-specific fields
- Validation rules for required and disallowed WAN/LAN fields based on selected method.
- Automatic cloud-init ISO generation when license and/or WAN/LAN settings are provided.
- Console-based FusionHub WAN static IP setup via `qm sendkey` with new `--CONSOLE_*` CLI flags.
- UEFI VM creation via `--UEFI`, with separate `--IMG_NAME_UEFI` and `--IMG_URL_UEFI` image settings and an EFI disk.

### Changed
- Cloud-init ISO generation now uses generated user-data content and is no longer license-only.
- When generated cloud-init content is requested, generated ISO takes precedence over `--CI_ISO`.
- Expanded `README.md` with WAN/LAN arguments, mode matrix, precedence behavior, and usage examples.
- Cloud-init ISO generation now prints ISO internal file tree layout and full file contents for verification.
- VM startup flow now starts the VM for console static IP setup even without cloud-init and restarts the VM after applying console network settings.
- Updated `README.md` with console static IP examples, flag documentation, and console/cloud-init interaction rules.

### Fixed
- Correctly attaches imported disks on `dir`-type storages (e.g. `local`) by using the volume ID returned by `qm importdisk`.
- Fixed `--IMG_URL` handling so URL-only input derives `IMG_NAME`/`IMG_PATH` from URL basename.
- Normalized `IMG_PATH` join logic to avoid duplicate slashes when `IMG_DIR` ends with `/`.
- Updated README installer commands to use cache-resilient `raw.githubusercontent.com` URL with cache-busting query and added preflight script marker verification.
- Added validation to reject mixing console static IP setup with cloud-init WAN/LAN network flags and to default console DNS to `8.8.8.8`.

## [0.0.2] - 2026-01-20

### Added
- Universal storage pool detection supporting ANY Proxmox storage type (LVM, ZFS, DIR, Ceph, NFS, iSCSI, etc.)
- New `--STORAGE` parameter to manually specify which storage pool to use
- Storage validation to ensure selected storage supports VM disk images ('images' content type)
- Storage space validation requiring minimum 1GB free space
- Auto-start VM on Proxmox boot via `--onboot 1` flag
- Comprehensive error messages showing available storage options when validation fails

### Changed
- Replaced `get_lvm_storage()` with generic `get_storage()` function
- Storage detection now filters by 'images' content type instead of storage type
- Storage selection logic now auto-detects or uses user-specified value
- Enhanced configuration summary display to show storage pool selection

### Fixed
- Storage detection now works on systems without LVM storage
- Script no longer limited to LVM-only environments

## [0.0.1] - 2025-08-14

### Added
- Initial release
- Basic VM creation with configurable parameters
- Automatic RAW image download from Peplink
- License key support via Cloud-init ISO
- Customizable VM settings (name, memory, cores, network)
- Support for local image files
- Custom image URL support
