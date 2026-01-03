sudo pacman -Syu
sudo pacman -S nvidia-dkms nvidia-utils

sudo rm -rf /etc/mkinitcpio.conf
sudo cp -r mkinitcpio.conf /etc/
sudo mkinitcpio -P
sudo poweroff
