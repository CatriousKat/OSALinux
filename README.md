# OSALinux
A port of the OSAScript utility on macOS to Linux. <br>
# How to run
Requirements: zenity, espeak-ng, xdg-utils, xclip <br>
1. Run ```sudo chmod +x osalinux.sh``` and enter your password
2. Run ```./osalinux.sh <script.osal>```
<br>
# Troubleshooting
Run ```sed -i 's/\r$//' osalinux.sh``` and make sure osalinux.sh is in the current directory.
