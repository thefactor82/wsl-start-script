# wsl-start-script

Bash scripts to speed up access to various tools on WSL

Execute the following command to add START alias:
`echo "alias start='cd /home/mario; . ./start.sh'" >> .bashrc`

Execute the following command to add AWS-SWITCH alias:
`echo "source /home/mario/aws-switch.sh" >> .bashrc`

## Usage:

# start

`start`

will list folders under the Sources directory set in the variable "base_dir"
and will enable ansible9.2.0 virtualenv (default set in the variable "base_ansible") only if ansible.cfg file is found in the directory.

`start X.X.X`

will list folders under the Sources directory set in the variable "base_dir"
and will enable ansibleX.X.X virtualenv only if ansible.cfg file is found in the directory.

# aws-switch

requires AWS-CLI v2, fzf, unzip

`aws-switch`

will log on aws SSO if necessary, then lists all accounts, and when one account is selected, lists all roles available. When the role is selected, it exports automatically access keys and token for that account

`aws-switch-clear`

will remove exported variables to clear the shell.