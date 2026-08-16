# macOS-specific git configuration

# Secure Enclave SSH signing.
#
# The key lives inside the Secure Enclave and never leaves the machine, so it
# cannot be synced between machines. ~/.ssh/id_git_sign is only a reference to
# it, not the private key itself. Run `setup-git-signing-key` once per Mac to
# create the key and these files.
[user]
	signingkey = ~/.ssh/id_git_sign

[gpg]
	format = ssh

[gpg "ssh"]
	program = ~/.local/bin/ssh-sign
	allowedSignersFile = ~/.config/git/allowed_signers

[commit]
	gpgsign = true

[tag]
	gpgSign = true

[safe]
	directory = /Users/pc0038/work_dir/puchisunaba/phase2
