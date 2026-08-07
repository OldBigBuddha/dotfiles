# Linux-specific git configuration

# 1Password SSH signing.
#
# Linux has no Secure Enclave equivalent, so commit signing stays on the
# 1Password-managed ed25519 key. Keep this key registered on GitHub as a
# signing key alongside the per-Mac Secure Enclave keys.
[user]
	signingkey = ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDvQze+HOHpQPzD5Uv6yu+wtUh+Zpe9I2HXn1KwadphZ

[gpg "ssh"]
	program = /opt/1Password/op-ssh-sign
