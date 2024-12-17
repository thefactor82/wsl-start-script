# wsl-start-script

Bash script to speed up access to Ansible on WSL

Execute the following command to add START alias:
`echo "alias start='cd /home/mario; . ./start.sh'" >> .bashrc`

## Usage:

`start`

will list folders under the Sources directory set in the variable "base_dir"
and will enable ansible9.2.0 virtualenv (default set in the variable "base_ansible")

`start X.X.X`

will list folders under the Sources directory set in the variable "base_dir"
and will enable ansibleX.X.X virtualenv.