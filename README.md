# VPS Setup with WireGuard VPN, Pi-hole, and Unbound

This repository contains an **Ansible playbook** that automates the setup of a secure VPS with:
- **WireGuard VPN** (for secure remote access)
- **Pi-hole** (for ad-blocking DNS)
- **Unbound** (for private, recursive DNS resolution)
- **Basic Linux security setup** (firewall, SSH hardening, sudo user creation)

## 📌 Prerequisites
1. A **VPS with Ubuntu 22.04 or Debian 12**.
2. **Ansible installed** on your local machine:
   - **macOS (via Homebrew):**
     ```bash
     brew install ansible
     ```
   - **Linux (Debian/Ubuntu):**
     ```bash
     sudo apt update && sudo apt install ansible -y
     ```
3. SSH access to your VPS with a sudo user.
4. A private SSH key for authentication.

---

## 🚀 Deployment Steps

### 1️⃣ **Clone the Repository**
```bash
git clone https://github.com/your-repo/vps-setup.git
cd vps-setup
```

### 2️⃣ **Set Up Inventory**
Create a file called `inventory.ini` in the same folder:
```ini
[vps]
your_vps_ip ansible_user=root 
ansible_ssh_private_key_file=~/.ssh/your_key.pem
```
Replace:
- `your_vps_ip` → Your VPS IP address
- `your_key.pem` → Your SSH key file

### 3️⃣ **Run the Ansible Playbook**
```bash
ansible-playbook -i inventory.ini ansible_vpn_pihole_unbound.yml
```

### 4️⃣ **Retrieve WireGuard Client Configuration**
Once the playbook completes, retrieve the **WireGuard client configuration** using:
```bash
cat /root/wg0-client.conf
```
Copy the contents of this file to your Mac.

### 5️⃣ **Connect to WireGuard VPN on macOS**
#### **Install WireGuard Client**
1. Download **WireGuard** from the [Mac App Store](https://apps.apple.com/us/app/wireguard/id1451685025?mt=12).

2. **Import the configuration file**:
   - Open the WireGuard app on macOS.
   - Click **"Import tunnel from file"**.
   - Select the `wg0-client.conf` file you copied from your VPS.
   - Click **Save**.

3. **Activate the VPN**:
   - Click **Activate** in the WireGuard app.

4. **Verify VPN Connection**:
   ```bash
   curl ifconfig.me
   ```
   If the IP matches your VPS, you are connected!

5. **To disconnect**, toggle **Deactivate** in the WireGuard app.

---

## 🔧 Additional Notes
- **SSH Security:**
  - Root login is disabled
  - Password authentication is disabled
  - A new sudo user (`newuser`) is created

- **Pi-hole Logging Disabled**
  - Pi-hole logging is turned off for privacy

- **Firewall Rules:**
  - **SSH (port 22)** is kept open for remote access
  - **WireGuard (UDP 51820)** is open
  
---

## 🎯 Summary
✅ **Fully automated setup** of WireGuard VPN, Pi-hole, and Unbound

✅ **Secure & private** with ad-blocking and no third-party DNS

✅ **Simple Ansible playbook** for repeatable deployments

Enjoy your **private, ad-free, and secure internet connection!** 🚀
