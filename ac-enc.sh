pkgs=(
  ccrypt chntpw cryptcat cryptsetup cupp discord dsniff gpa gpg gtkhash
  hashcat hexchat hydra hydra-gtk iodine john keepassxc linphone linphone-desktop
  medusa ncrack ophcrack ophcrack-cli outguess pidgin pinentry-curses pinentry-gtk2
  qtox signal-desktop slack ssh-import-id sshpass ssl-cert stegcracker steghide
  stegosuite stegsnow telegram-desktop whatweb zoom zulucrypt-gui zulumount-gui
  zulupolkit zulusafe-cli veracrypt aespipe scrypt wireguard hashid fcrackzip
  pdfcrack encfs kleopatra tomb
)

found=0; missing=0
for p in "${pkgs[@]}"; do
  if apt-cache show "$p" >/dev/null 2>&1; then
    found=$((found + 1))
  else
    echo "MISSING in apt-cache: $p"
    missing=$((missing + 1))
  fi
done
echo "Total: ${#pkgs[@]} | In APT cache: $found | Missing: $missing"
