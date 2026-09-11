# ─── SSH Key Pair ──────────────────────────────────────────────────
# Pre-existing key pair name (upload your public key to AWS first, or
# create one via EC2 → Key Pairs in the console).

variable "ssh_key_name" {
  description = "Name of an existing AWS EC2 key pair for SSH access"
  type        = string
  default     = "myshoe"
}
