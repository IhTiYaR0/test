sudo rm -rf /etc/default/grub
sudo cp -r ~/test/grub /etc/default/

# sudo rm -rf /etc/mkinitcpio.conf
# sudo cp -r ~/test/mkinitcpio.conf /etc/

sudo grub-mkconfig -o /boot/grub/grub.cfg
# sudo mkinitcpio -P

# sudo pacman -Syu nvidia-dkms nvidia-utils lib32-nvidia-utils
