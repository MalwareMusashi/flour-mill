# Flour Mill

auto recon tool - runs nmap, parses results, checks for vulns, suggests tools

## what it does

1. checks what tools you got
2. offers to install netexec if missing
3. runs nmap (your choice of scan type)
4. parses open ports/services
5. checks CVEs and github for exploits
6. suggests tools for each service
7. runs them interactively
8. logs everything

## requirements

**need:**
- nmap
- sudo
- curl (for vuln checks)

**optional (script checks these):**
- netexec (script can install this for you via pipx)
- kerbrute, impacket tools
- enum4linux, smbclient
- hydra, medusa
- nikto, gobuster, dirb, sqlmap
- ssh-audit, msfconsole, responder
- ldapsearch, dig, dnsenum
- searchsploit (for exploit-db lookups)

more tools installed = more suggestions

## setup

**quick setup:**
```bash
chmod +x flour_mill.sh
./flour_mill.sh
```

**install to PATH (run from anywhere):**
```bash
# clone or download
git clone https://github.com/yourusername/flour_mill.git
cd flour_mill

# make executable
chmod +x flour_mill.sh

# copy to local bin
sudo cp flour_mill.sh /usr/local/bin/flour_mill

# now run from anywhere
flour_mill
```

**or symlink it:**
```bash
# from the repo directory
sudo ln -s $(pwd)/flour_mill.sh /usr/local/bin/flour_mill
```

**uninstall:**
```bash
sudo rm /usr/local/bin/flour_mill
```

## usage

```bash
./flour_mill.sh
```

or

```bash
TARGET=192.168.1.100 ./flour_mill.sh
```

### scan types

1. quick - top 1k ports
2. standard - all ports + versions (recommended)
3. full - aggressive, OS detection
4. stealth - SYN scan, slow timing
5. udp - top 1k udp ports
6. udp full - all udp ports (slow af)
7. custom - your own flags

### where stuff saves

picks one:
1. Documents folder - `~/Documents/scans/` (default)
2. current dir - `./scans/`
3. custom path - wherever you want

### netexec auto install

if netexec isnt found:
```
[!] netexec not found
install netexec via pipx? (y/n): y

[*] installing netexec...
[*] pipx not found, installing pipx first...
[installs pipx and netexec]
[+] netexec installed successfully
```

### vuln checking

for each service with version info:
```
port 22 - ssh
version: OpenSSH 7.4

check vulns? (y/n): y

[*] checking vulns...
[*] nvd: OpenSSH 7.4
[!] found cves:
    → CVE-2018-15473 - https://nvd.nist.gov/vuln/detail/CVE-2018-15473

[*] github...
[!] repos:
    → github.com/username/openssh-exploit

[*] exploit-db...
[!] found:
OpenSSH 7.4 - User Enumeration
```

checks:
- NVD (NIST vuln database)
- github (for public exploits)
- exploit-db (if searchsploit installed)

### example run

```
$ ./flour_mill.sh

[shows flour mill art]

[*] checking for tools...
[+] nmap
[+] enum4linux
[-] netexec
...

[!] netexec not found
install netexec via pipx? (y/n): n

target ip/hostname: 10.10.10.3

scan type:
1) quick (top 1k)
2) standard (all ports + versions)
3) full aggressive
4) stealth
5) udp scan (top 1k udp ports)
6) udp full (all udp ports - slow)
7) custom
> 2

verbosity:
1) normal
2) -v
3) -vv
> 1

save scans to:
1) Documents folder
2) current directory
3) custom path
> 1

[+] configured
    flags: -sS -sV -sC -p-
    output: /home/user/Documents/scans/10.10.10.3_20241001_143022

[*] running nmap...
...

open ports:
139/tcp  open  netbios-ssn  Samba 3.0.20
445/tcp  open  smb          Samba 3.0.20

============================================
port 445 - smb
version: Samba 3.0.20
============================================

check vulns? (y/n): y

[*] checking vulns...
[!] found cves:
    → CVE-2007-2447

[!] repos:
    → github.com/amriunix/CVE-2007-2447

tool: netexec
desc: smb attacks
example: netexec smb 10.10.10.3 -u '' -p ''
[-] not installed

tool: enum4linux
desc: smb enum
example: enum4linux -a 10.10.10.3
[+] available
run? (y/n): y
...
```

## output structure

```
~/Documents/scans/
└── 10.10.10.3_20241001_143022/
    ├── nmap.txt
    ├── nmap.xml
    ├── nmap.gnmap
    ├── ports.txt
    └── logs/
        ├── enum4linux_p445_20241001_143022.txt
        ├── gobuster_p80_20241001_143022.txt
        └── ssh-audit_p22_20241001_143022.txt
```

## port -> tool mappings

| port | service | tools |
|------|---------|-------|
| 88, 464 | kerberos | kerbrute, GetNPUsers, GetUserSPNs |
| 139, 445 | smb | enum4linux, smbclient, netexec |
| 3389 | rdp | hydra |
| 22 | ssh | ssh-audit, hydra |
| 21 | ftp | hydra |
| 80, 443, 8080, 8443 | http/https | nikto, gobuster, sqlmap |
| 389, 636 | ldap | ldapsearch |
| 53 | dns | dig, dnsenum |

## tips

- need sudo for syn scans
- have wordlists in `/usr/share/wordlists/`
- can edit commands before running
- everything auto-logs
- vuln checks need internet
- searchsploit optional but useful

## issues

**"need nmap installed"**
```bash
sudo apt install nmap
```

**"scan failed"**
- check sudo
- ping target first
- try stealth scan

**"no internet" for vuln checks**
- need curl: `sudo apt install curl`
- need working internet connection
- skips vuln check if offline

**tools not showing**
- check PATH
- `which <tool>` to verify
- install missing ones

**netexec install fails**
```bash
# manual install
sudo apt install pipx
pipx install git+https://github.com/Pennyw0rth/NetExec
```

## notes

- only suggests installed tools
- you control what runs
- logs timestamped
- vuln checks optional per service
- works on tcp and udp
- netexec replaces crackmapexec

made for ctfs and quick pentests. speeds up the boring enum phase.

---

**changelog:**
- replaced crackmapexec with netexec
- added auto-install for netexec
- added cve/exploit checking (nvd, github, exploit-db)
- added udp scan options
- output defaults to Documents folder
