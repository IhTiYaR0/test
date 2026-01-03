cp -r cod.sh ~/

sudo pacman -Syu
sudo pacman -S nvidia-dkms nvidia-utils

sudo mkinitcpio -P
