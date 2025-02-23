#!/data/data/com.termux/files/usr/bin/sh
# This script installs required packages, sets up storage access,
# creates a boot script for auto-starting SSH, and starts SSH immediately.

read -p "Set password for termux: " pin 
# pin="sefghai"

# Update package list and upgrade packages first
apt update -y && apt upgrade -y

# Install required packages
apt install -y python openssl openssh wget

#defualt password for ssh
passwd <<EOF
$pin
$pin
EOF
echo "default password has been set"
echo "password: $pin"

# Set up storage access (only needed once)
termux-setup-storage
# Create the Termux:Boot directory if it doesn't exist
mkdir -p $HOME/.termux/boot
# Create a boot script for starting ssh on boot
BOOT_SCRIPT="$HOME/.termux/boot/AutoSSh.sh"
cat > "$BOOT_SCRIPT"<< 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# Prevent device from sleeping
termux-wake-lock

# Kill any existing sshd instance (if needed)
pkill sshd

# Start the SSH daemon
sshd

# Inform that SSH has started
echo "SSHD started at $(date)"
echo ip of device is:
ifconfig wlan0 | grep 'inet ' | awk '{print $2}'
EOF

# Make the boot script executable
chmod +x "$BOOT_SCRIPT"

# Start the SSH daemon immediately
cd ~/.termux/boot/
./AutoSSh.sh
cd ~ #goto home

echo "Setup complete. The SSH server will auto-start on boot."

pkg update
pkg upgrade -y

# Installing Termux Desktop Interface
# curl -Lf https://raw.githubusercontent.com/shiva1485/Server-In-Phone/refs/heads/main/setup-termux-desktop.sh -o setup-termux-desktop
# chmod +x setup-termux-desktop
# ./setup-termux-desktop
curl -Lf https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/setup-termux-desktop -o setup-termux-desktop
chmod +x setup-termux-desktop
./setup-termux-desktop

#updating after installation
pkg update && pkg upgrade -y
pkg install x11-repo -y
pkg install tigervnc xrdp -y
pkg install tsu -y #sudo in termux 
pkg install xfce4 -y

# Set up VNC
cd ~  # Go to home directory
rm -f ~/.vnc/xstartup  # Remove existing xstartup if it exists
touch ~/.vnc/xstartup  # Create a new xstartup file

# Write to xstartup file to launch XFCE4
echo "#!/data/data/com.termux/files/usr/bin/sh" > ~/.vnc/xstartup  # Correct shebang for Termux
echo "xfce4-session &" >> ~/.vnc/xstartup  # Append to xstartup file, not overwrite
chmod +x ~/.vnc/xstartup  # Make the xstartup file executable

# Set up XRDP
echo "xfce4-session" > ~/.xsession  # Create a .xsession file for XRDP
chmod +x ~/.xsession  # Make the .xsession file executable

#modify xrdp.ini file
# Define the path to the xrdp.ini file
XRDP_CONFIG_FILE="$PREFIX/etc/xrdp/xrdp.ini"

# Check if the file exists
if [ -f "$XRDP_CONFIG_FILE" ]; then
  # Use sed to change the port only in the [Xvnc] section
  sed -i '/^\[Xvnc\]/,/^\[.*\]/s/^port=.*/port=5901/' "$XRDP_CONFIG_FILE"
  echo "Port in the [Xvnc] section changed to 5901 successfully!"
else
  echo "xrdp.ini file not found at $XRDP_CONFIG_FILE"
fi

#rdp script
XRDPSTART_SCRIPT="/data/data/com.termux/files/usr/bin/rdp"
# Check if the script already exists
if [ ! -f "$XRDPSTART_SCRIPT" ]; then
  # Create the xrdpstart script
  cat > "$XRDPSTART_SCRIPT" << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh

# Function to start XRDP Server
start_rdp() {
    if pgrep -x "xrdp" > /dev/null; then
        echo "RDP is already running!"
        exit 1
    fi

    echo "Starting XRDP..."
    xrdp &  # Run xrdp in the background
    sleep 2 # Allow time for xrdp to start

    if ! pgrep -x "xrdp" > /dev/null; then
        echo "Failed to start XRDP."
        exit 1
    fi

    #start the rdp since its first time to run this command
    ps aux | grep '[x]rdp'  # List only xrdp process (avoid grep showing itself)
    echo "Verify XRDP is running above."
    vncserver -xstartup /usr/bin/startxfce4 -listen tcp :1
    echo "RDP started successfully"
}

# Function to stop XRDP and VNC Server
kill_rdp() {
    if ! pgrep -x "xrdp" > /dev/null; then
        echo "RDP is not running!"
        exit 1
    fi

    echo "Stopping RDP..."
    pkill xrdp

    if vncserver -list 2>/dev/null | grep -q ":1"; then
        vncserver -kill :1
        echo "RDP stopped!"
 else
        echo "No active RDP session found on :1"
    fi
}

# Check if an argument is provided
if [ "$1" = "-kill" ]; then
    kill_rdp
else
    start_rdp
fi
EOF

  # Make the script executable
  chmod +x "$XRDPSTART_SCRIPT"

  echo "rdp script created and made executable."
else
  echo "rdp script already exists at $XRDPSTART_SCRIPT"
fi

# ip? script
ip_script="/data/data/com.termux/files/usr/bin/ip?"

# Check if the script already exists
if [ ! -f "$ip_script" ]; then
  # Create the xrdpstart script
  bash -c "cat > $ip_script << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
ifconfig wlan0 | grep 'inet' | awk '{print $2}'
EOF"

  # Make the script executable
  chmod +x $ip_script

  echo "ip? script created and made executable."
else
  echo "ip? script already exists at $ip_script"
fi


vncpasswd <<EOF
$pin
$pin
n
EOF
echo "\nvnc password set sucessfully"
echo "password: $pin"

#adding ssh,vnc,xrdp to autostart when a new session is opened
cd ~
echo "sshd" >> .zshrc
echo "rdp" >> .zshrc
echo "vncserver" >> .zshrc
echo "vncserver password is your rdp session password!!" >> .zshrc
echo "ip?" >> .zshrc
echo "termux-wake-lock" >> .zshrc
