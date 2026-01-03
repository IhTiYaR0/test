yay -S linux-headers nvidia-dkms qt5-wayland qt5ct libva libva-nvidia-driver-git
sudo mkinitcpio --config /etc/mkinitcpio.conf --generate /boot/initramfs-custom.img
sudo sh -c 'echo "options nvidia-drm modeset=1" > /etc/modprobe.d/nvidia.conf'
sudo reboot