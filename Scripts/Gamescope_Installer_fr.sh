#!/bin/bash
# ==============================================================================
# Script d'installation automatisé : Bascule GNOME <-> Steam (Fedora 45 PS5)
# ==============================================================================

set -e

TARGET_USER="ps5"

echo "[1/8] Vérification de la configuration AccountsService pour '$TARGET_USER'..."
if [ -f "/var/lib/AccountsService/users/$TARGET_USER" ]; then
    sudo sed -i 's/^Session=.*/Session=gnome/' "/var/lib/AccountsService/users/$TARGET_USER"
fi
sudo passwd -u "$TARGET_USER" 2>/dev/null || true

echo "[2/8] Configuration de l'auto-connexion GDM (/etc/gdm/custom.conf)..."
sudo tee /etc/gdm/custom.conf > /dev/null << EOF
# GDM configuration storage

[daemon]
AutomaticLoginEnable=True
AutomaticLogin=$TARGET_USER

[security]

[xdmcp]

[chooser]

[debug]
# Uncomment the line below to turn on debugging
#Enable=true
EOF

echo "[3/8] Configuration du facteur d'échelle GDM (1.5) via dconf..."
sudo mkdir -p /etc/dconf/profile /etc/dconf/db/gdm.d
sudo tee /etc/dconf/profile/gdm > /dev/null << 'EOF'
user-db:user
system-db:gdm
EOF
sudo tee /etc/dconf/db/gdm.d/00-scaling > /dev/null << 'EOF'
[org/gnome/desktop/interface]
text-scaling-factor=1.5
EOF
sudo dconf update

echo "[4/8] Installation de git et des fichiers de session Steam/Gamescope..."
sudo dnf install -y git
if [ ! -d "/tmp/gamescope-guide" ]; then
    git clone https://github.com/shahnawazshahin/steam-using-gamescope-guide.git /tmp/gamescope-guide
fi
(
    cd /tmp/gamescope-guide
    sudo ./installer.sh
)

echo "[5/8] Configuration des règles sudoers sans mot de passe (/etc/sudoers.d/ps5-session)..."
sudo tee /etc/sudoers.d/ps5-session > /dev/null << EOF
$TARGET_USER ALL=(ALL) NOPASSWD: /usr/local/bin/switch-session, /usr/bin/steamos-session-select, /usr/bin/systemd-run *
EOF
sudo chmod 440 /etc/sudoers.d/ps5-session
sudo visudo -c -f /etc/sudoers.d/ps5-session

echo "[6/8] Création du script de bascule détaché (/usr/local/bin/switch-session)..."
sudo tee /usr/local/bin/switch-session > /dev/null << EOF
#!/bin/bash
USER_ID=\$(id -u $TARGET_USER)
CURRENT=\$(busctl get-property org.freedesktop.Accounts /org/freedesktop/Accounts/User\$USER_ID org.freedesktop.Accounts.User Session | awk -F'"' '{print \$2}')

if [ "\$CURRENT" = "steam" ]; then
    TARGET="gnome"
else
    TARGET="steam"
fi

sudo systemd-run --quiet --collect bash -c "busctl call org.freedesktop.Accounts /org/freedesktop/Accounts/User\$USER_ID org.freedesktop.Accounts.User SetSession s '\$TARGET' && loginctl terminate-user $TARGET_USER && sleep 2 && systemctl restart gdm"
EOF
sudo chmod +x /usr/local/bin/switch-session

echo "[7/8] Configuration du retour au bureau Steam (/usr/bin/steamos-session-select)..."
sudo tee /usr/bin/steamos-session-select > /dev/null << EOF
#!/bin/bash
USER_ID=\$(id -u $TARGET_USER)
sudo systemd-run --quiet --collect bash -c "busctl call org.freedesktop.Accounts /org/freedesktop/Accounts/User\$USER_ID org.freedesktop.Accounts.User SetSession s 'gnome' && loginctl terminate-user $TARGET_USER && sleep 2 && systemctl restart gdm"
EOF
sudo chmod +x /usr/bin/steamos-session-select

echo "[8/8] Création des raccourcis sur le bureau et dans le menu des applications..."
mkdir -p ~/.local/share/applications ~/Bureau ~/Desktop
cat << 'EOF' > ~/.local/share/applications/switch-session.desktop
[Desktop Entry]
Type=Application
Name=Basculer Session (GNOME / Steam)
Comment=Basculer entre GNOME et Steam Big Picture
Exec=/usr/local/bin/switch-session
Icon=steam
Terminal=false
Categories=Game;Utility;
EOF

chmod +x ~/.local/share/applications/switch-session.desktop
cp ~/.local/share/applications/switch-session.desktop ~/Bureau/ 2>/dev/null || true
cp ~/.local/share/applications/switch-session.desktop ~/Desktop/ 2>/dev/null || true
update-desktop-database ~/.local/share/applications/

echo ""
echo "Installation terminée ! Veuillez redémarrer votre console (sudo reboot) pour appliquer tous les changements."
echo ""
