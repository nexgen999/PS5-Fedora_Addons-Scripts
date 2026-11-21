#!/bin/bash
# ==============================================================================
# Script de désinstallation de la bascule de session GNOME <-> Steam (PS5)
# ==============================================================================

set -e

TARGET_USER="${SUDO_USER:-$USER}"
if [ "$TARGET_USER" = "root" ] || [ -z "$TARGET_USER" ]; then
    TARGET_USER="ps5"
fi
USER_ID=$(id -u "$TARGET_USER")

echo "[*] Désinstallation de la configuration de bascule pour l'utilisateur : $TARGET_USER"

# 1. Suppression des scripts de bascule et de retour
echo "[*] Suppression des scripts système..."
sudo rm -f /usr/local/bin/switch-session /usr/bin/steamos-session-select

# 2. Suppression de la règle sudoers
echo "[*] Suppression de la règle sudoers..."
sudo rm -f /etc/sudoers.d/ps5-session

# 3. Suppression des raccourcis (.desktop) sur le bureau et dans le menu
echo "[*] Suppression des raccourcis graphiques..."
rm -f ~/.local/share/applications/switch-session.desktop       ~/Bureau/switch-session.desktop       ~/Desktop/switch-session.desktop       ~/.local/share/applications/mode-gaming.desktop

update-desktop-database ~/.local/share/applications/ 2>/dev/null || true

# 4. Réinitialisation de la session par défaut sur GNOME dans AccountsService
echo "[*] Restauration de la session GNOME par défaut..."
sudo busctl call org.freedesktop.Accounts /org/freedesktop/Accounts/User$USER_ID org.freedesktop.Accounts.User SetSession s "gnome" 2>/dev/null || true

# 5. Nettoyage optionnel de /etc/gdm/custom.conf (retrait de DefaultSession s'il existe)
if [ -f /etc/gdm/custom.conf ]; then
    sudo sed -i '/^DefaultSession=/d' /etc/gdm/custom.conf
fi

echo "[*] Désinstallation terminée avec succès ! Le système est revenu à son état d'origine (session GNOME)."
