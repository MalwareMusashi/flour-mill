# flour-mill
# Auto Recon Tool

Quick script to automate the boring recon stuff. Runs nmap, parses results, then suggests tools based on what ports/services are open.

## What it does

1. Checks what pentest tools you have installed
2. Runs nmap scan (you pick the type)
3. Parses open ports/services
4. Suggests relevant tools for each service
5. Lets you run them interactively with custom params
6. Logs everything

## Requirements

**Must have:**
- nmap (obviously)
- sudo access

**Optional tools (script will check and suggest what you have):**
- kerbrute, impacket-GetNPUsers, impacket-GetUserSPNs
- enum4linux, smbclient, crackmapexec
- hydra, medusa
- nikto, gobuster, dirb, sqlmap
- ssh-audit
- msfconsole
- responder
- ldapsearch, dig, dnsenum

The more you have installed, the more suggestions you'll get.

## Setup

```bash
chmod +x flour_mill.sh
```

That's it.

## Usage

```bash
./flour_mill.sh
```

Or set target as env var:

```bash
TARGET=192.168.1.100 ./flour_mill.sh
```

### Scan types

- **Quick**: Top 1000 ports, fast
- **Standard**: All ports + version detection (recommended)
- **Full**: Aggressive scan, OS detection, all the things
- **Stealth**: SYN scan, slow timing
- **Custom**: Enter your own nmap flags

### Example workflow

```
$ ./flour_mill.sh

[*] checking for tools...
[+] nmap
[+] enum4linux
[+] gobuster
...

target ip/hostname: 10.10.10.50

scan type:
1) quick (top 1k)
2) standard (all ports + versions)
3) full aggressive
> 2

verbosity:
1) normal
2) -v
3) -vv
> 1

output dir (default: ./scans): 

[+] configured
    flags: -sS -sV -sC -p-
    output: ./scans/10.10.10.50_20241001_143022

[*] running nmap...
...

open ports:
22/tcp   open  ssh     OpenSSH 8.2p1
80/tcp   open  http    Apache httpd 2.4.41
445/tcp  open  smb     Samba 4.11.6

============================================
port 22 - ssh
============================================

tool: ssh-audit
desc: check config
example: ssh-audit 10.10.10.50
[+] available
run? (y/n): y
command (enter for example): 

running: ssh-audit 10.10.10.50
...
```

## Output

Everything gets saved to `./scans/TARGET_TIMESTAMP/`:

```
scans/
└── 10.10.10.50_20241001_143022/
    ├── nmap.txt          # normal output
    ├── nmap.xml          # xml format
    ├── nmap.gnmap        # greppable
    ├── ports.txt         # just the open ports
    └── logs/
        ├── enum4linux_p445_20241001_143022.txt
        ├── gobuster_p80_20241001_143022.txt
        └── ssh-audit_p22_20241001_143022.txt
```

## Service -> Tool mapping

| Port | Service | Suggested Tools |
|------|---------|----------------|
| 88, 464 | Kerberos | kerbrute, GetNPUsers, GetUserSPNs |
| 139, 445 | SMB | enum4linux, smbclient, crackmapexec |
| 3389 | RDP | hydra |
| 22 | SSH | ssh-audit, hydra |
| 21 | FTP | hydra |
| 80, 443, 8080, 8443 | HTTP/HTTPS | nikto, gobuster, sqlmap |
| 389, 636 | LDAP | ldapsearch |
| 53 | DNS | dig, dnsenum |

If nothing specific matches, it'll suggest searching metasploit.

## Tips

- Run as sudo (nmap needs it for SYN scans)
- Have wordlists ready in `/usr/share/wordlists/` for bruteforce tools
- The script will prompt for custom commands - you can modify the examples on the fly
- All tool output is logged automatically
- If a tool isn't installed, it just skips it and tells you

## Common issues

**"need nmap installed"**
```bash
sudo apt install nmap
```

**"scan failed"**
- Check you have sudo
- Make sure target is reachable
- Try a different scan type (stealth if you're being blocked)

**Tool suggestions not showing up**
- Make sure the tool is actually installed and in your PATH
- Run `which <toolname>` to verify

## Notes

- Script only suggests tools it detects are installed
- You control what runs - it asks before executing anything
- Custom commands are supported for every tool
- Logs are timestamped so you can run multiple scans without overwriting

## Example output structure

After a full run against a Windows box:

```
./scans/192.168.1.50_20241001_150000/
├── nmap.txt
├── nmap.xml
├── nmap.gnmap
├── ports.txt
└── logs/
    ├── enum4linux_p445_20241001_150000.txt
    ├── crackmapexec_p445_20241001_150000.txt
    ├── impacket-GetNPUsers_p88_20241001_150000.txt
    ├── nikto_p80_20241001_150000.txt
    └── gobuster_p80_20241001_150000.txt
```

Clean, organized, easy to grep through later.

---

Made for quick pentests/CTFs. Not meant to replace manual testing, just speeds up the initial enum phase.
