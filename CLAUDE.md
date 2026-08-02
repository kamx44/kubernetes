# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Terraform + shell/PowerShell automation that provisions a small Kubernetes homelab cluster on a
Proxmox VE hypervisor. It clones cloud-init VM templates, installs containerd/kubeadm/kubelet on
them, runs `kubeadm init` on the master, and joins a worker node — all via Terraform provisioners
(no Ansible/config-management layer).

## Repo layout

- `home_lab/terraform/` — the only real Terraform root module.
  - `main.tf` — defines everything: `proxmox_virtual_environment_vm.master` (single
    control-plane VM) and `proxmox_virtual_environment_vm.worker` (for_each over
    `local.workers`), wired together with
    `null_resource` provisioners and `time_sleep` resources to sequence: clone VM → wait →
    install qemu-guest-agent → copy/run `scripts/init_node.sh` → (master only) `kubeadm init` +
    install CNI → generate join token → pull token to the local machine → (worker only) copy the
    join command and run it. Order is entirely encoded in `depends_on` chains, not modules.
  - `provider.tf` — configures the `bpg/proxmox` provider (`>= 0.66.0`). Endpoint is
    derived from `pm_api_url` (the `/api2/json` suffix is stripped), and the API token is
    assembled as `"<pm_api_token_id>=<pm_api_token_secret>"`.
  - `variables.tf` / `test.tfvars` — VM credentials, SSH key/private key path, and Proxmox API
    connection details. `test.tfvars` is a real, filled-in tfvars file checked into the repo (see
    Secrets note below), not an example/template.
  - `scripts/init_node.sh` — remote-exec script run on both master and worker: enables IP
    forwarding, installs containerd + runc + CNI plugins from GitHub release binaries, configures
    `SystemdCgroup`, then installs `kubelet`/`kubeadm`/`kubectl` from the pinned
    `pkgs.k8s.io/core:/stable:/v1.32` apt repo and holds those package versions.
  - `scripts/fetch_join_command.ps1` — standalone helper (not currently invoked from `main.tf`)
    that SSHes to the master and emits the join command as JSON, for use as a Terraform `external`
    data source pattern.
  - `modules/kube_node/` — an incomplete, **unused** scaffold (partial copy of the master-node
    logic from `main.tf`, referencing undeclared resources). It is not called via any `module`
    block from the root; treat it as a work-in-progress, not live infrastructure.
- `home_lab/local/` — a scratch area mirroring some terraform files (`commands.txt`,
  `test.tfvars`, `secrets`) with real hypervisor credentials and one-off notes/commands (e.g.
  clearing the ARP cache after redeploying a VM with the same MAC/imagePullSecrets, enabling the
  QEMU guest agent serial console). Not wired into Terraform; it's a notes/staging folder.

There is no application source code, package manifest, linter, or test suite in this repo —
"building" and "testing" mean applying/planning Terraform against the Proxmox host.

## Common commands

Run from `home_lab/terraform/`:

```powershell
terraform init
terraform plan  -var-file="test.tfvars"
terraform apply -var-file="test.tfvars"
terraform destroy -var-file="test.tfvars"
```

There's no CI, formatter check, or test runner configured — validate changes with
`terraform validate` / `terraform plan` against the tfvars file.

## Architecture notes for making changes

- **Everything is sequenced by hand.** Adding a new node or step means adding another
  `null_resource` + `depends_on` chain (and usually a matching `time_sleep`) rather than editing a
  reusable module — `modules/kube_node` was a start at extracting this but isn't finished or used.
  If you pick that refactor back up, remember to add a `module` block in `main.tf` and reconcile
  the duplicated/undeclared resource references in `modules/kube_node/main.tf`.
- **The join token hands off through the local machine.** The master generates a join command,
  Terraform pulls it down to `C:\Users\Kamil\.ssh\join_command.sh` via a `local-exec` SSH call, and
  the worker's `join_worker` resource pushes that same file back up. Any change to how/where the
  join command is stored needs to update both the `get_token` (master side) and `join_worker`
  (worker side) resources together.
- **IPs, VMIDs, and MAC addresses are hardcoded** in the `locals` blocks in `main.tf` (e.g. master
  `192.168.137.20`/vmid 110, worker `192.168.137.26`/vmid 120) and must stay consistent with the
  static DHCP/ARP setup on the `192.168.137.0/24` network described in `home_lab/local/commands.txt`.
- Windows-style paths (`scripts\\init_node.sh`, `C:\\Users\\Kamil\\.ssh\\...`) are used directly in
  `main.tf` provisioners — this project is developed and applied from a Windows host.
- Kubernetes/containerd/runc/CNI versions in `scripts/init_node.sh` are pinned explicitly (e.g.
  containerd v2.0.2, runc v1.2.4, CNI plugins v1.6.2, Kubernetes 1.32 apt repo) and downloaded
  straight from GitHub/`pkgs.k8s.io` — bumping a version means editing the URL/version string in
  that script directly.

## Secrets

`provider.tf`, `test.tfvars`, and `home_lab/local/*` contain real Proxmox API tokens, VM passwords,
and SSH key paths committed in plaintext (there is no `.gitignore`). Treat any credentials in this
repo as already-rotated-on-sight if you're reusing this as a template elsewhere, and avoid adding
further live secrets to tracked files.
