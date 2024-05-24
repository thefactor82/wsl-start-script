cd /mnt/c/Users/mmatteis/Documents/Sources/IT/ansible
echo $PWD
if [ -z "$1" ]
then
    workon ansible9.2.0
else
    workon ansible$1
fi
kinit mmatteis@TOPTIERRA.IT