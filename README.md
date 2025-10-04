# flour mill v2.0

automated recon tool - scans, checks vulns, runs tools

## what it does

scans ports, detects OS, checks for CVEs/exploits, suggests tools based on what's open, installs missing stuff, logs everything

## requirements

**need:**
- nmap
- sudo  
- curl
- git
- internet

**optional (auto-installs if you want):**
- netexec, kerbrute, impacket
- enum4linux, smbclient
- hydra, medusa
- nikto, gobuster, ffuf, dirsearch, nuclei
- sqlmap, ssh-audit, msfconsole, responder
- ldapsearch, dig, dnsenum, searchsploit
- go (for ffuf/nuclei)

## install

```bash
git https://github.com/MalwareMusashi/flour-mill
cd flour_mill
chmod +x flour_mill.sh
./flour_mill.sh
```

**global install:**
```bash
sudo cp flour_mill.sh /usr/local/bin/flour_mill
# or symlink it
sudo ln -s $(pwd)/flour_mill.sh /usr/local/bin/flour_mill
```

**uninstall:**
```bash
sudo rm /usr/local/bin/flour_mill
```

## update

```bash
flour_mill --update
```

or

```bash
cd ~/flour_mill
git pull
```

## usage

three ways to run:

```bash
# 1. pass target as arg
flour_mill 192.168.1.100

# 2. export first
export TARGET=192.168.1.100
flour_mill

# 3. let it ask
flour_mill
```

### scan types

1. quick - top 1k
2. standard - all ports + versions
3. full - aggressive 
4. stealth - slow and quiet
5. quick stealth - htb safe
6. quick aggressive - htb fast
7. udp - top 1k udp
8. udp full - all udp (slow)
9. custom - your flags

### naming scans

can name your scans for better organization:

```
scan name (optional):
name (or enter for default): htb-box-recon
```

creates: `htb-box-recon_192.168.1.100_20241003_143022/`

or just hit enter for: `192.168.1.100_20241003_143022/`

### output dirs

1. ~/Documents/scans (default)
2. ./scans  
3. custom path

### auto install

if tools missing:

```
missing 6 tools
install? (y/n): y

go not found, needed for ffuf
install go? (y/n): y

[installs everything]

done: 21 available
```

handles pipx, go, github releases, apt

### os detection

pings target, checks TTL:

```
[+] probably windows (ttl=128)
```

- 250-256: bsd/cisco
- 120-130: windows  
- 60-70: linux

### vuln checks

for each service asks if you want vuln check:

```
check vulns? (y/n): y

╔════════════════════════════════════════════════════════╗
║        CVEs FOUND - POTENTIAL VULNERABILITIES          ║
╚════════════════════════════════════════════════════════╝

  ▶ CVE-2007-2447
    https://nvd.nist.gov/vuln/detail/CVE-2007-2447

╔════════════════════════════════════════════════════════╗
║            EXPLOITS AVAILABLE ON GITHUB                ║
╚════════════════════════════════════════════════════════╝

  ▶ https://github.com/amriunix/CVE-2007-2447
```

searches nvd, github, exploit-db

saves everything to vulns.txt

## output

```
~/Documents/scans/htb-initial_192.168.1.100_20241003/
├── nmap.txt
├── nmap.xml
├── nmap.gnmap
├── ports.txt
├── vulns.txt
└── logs/
    ├── nuclei_p80_timestamp.txt
    ├── gobuster_p80_timestamp.txt
    └── enum4linux_p445_timestamp.txt
```

## port mappings

| port | service | tools |
|------|---------|-------|
| 88, 464 | kerberos | kerbrute, GetNPUsers, GetUserSPNs |
| 139, 445 | smb | enum4linux, smbclient, netexec |
| 3389 | rdp | hydra |
| 22 | ssh | ssh-audit, hydra |
| 21 | ftp | hydra |
| 80, 443, 8080, 8443 | web | nikto, gobuster, ffuf, dirsearch, nuclei, sqlmap |
| 389, 636 | ldap | ldapsearch |
| 53 | dns | dig, dnsenum |

## tools

**nikto** - web vuln scanner  
**gobuster** - dir bruteforce  
**ffuf** - fast fuzzer  
**dirsearch** - web scanner  
**nuclei** - vuln templates (1000+ checks)  
**sqlmap** - sqli testing  
**enum4linux** - smb enum  
**smbclient** - smb client  
**netexec** - multi-protocol testing  
**ssh-audit** - ssh config check

### nuclei

first time setup:
```bash
nuclei -update-templates
```

use it:
```bash
nuclei -u http://target.com -severity critical,high
```

## independent usage

all tools work outside flour mill after install:

```bash
nmap -sV 192.168.1.100
gobuster dir -u http://site.com -w wordlist.txt
ffuf -w wordlist.txt -u http://site.com/FUZZ
nuclei -u http://site.com
netexec smb 192.168.1.100 -u admin -p pass
```

flour mill just installs them, suggests when to use them, logs output

## tips

- need sudo for scans
- name scans to stay organized
- nuclei needs template update first time
- all tools stay after install
- symlink install = easy updates
- wordlists in /usr/share/wordlists/

## issues

**no nmap:**
```bash
sudo apt install nmap
```

**scan fails:**
- check sudo
- ping target first
- try stealth scan

**vuln check fails:**
```bash
sudo apt install curl
```

**tool install fails:**
```bash
sudo apt install pipx golang-go
pipx install git+https://github.com/Pennyw0rth/NetExec
go install github.com/ffuf/ffuf@latest
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
```

**nuclei no templates:**
```bash
nuclei -update-templates
```

## flags

```bash
flour_mill --update        # update
flour_mill --version       # version
flour_mill 192.168.1.100   # run
```

## changelog

**v2.0**
- nuclei scanner added
- scan naming
- go auto-install
- 6 web tools now (added nuclei)

**v1.5**  
- quick stealth/aggressive scans
- ffuf, dirsearch added
- unicode vuln boxes
- better target handling

**v1.0**
- initial release

---

made for ctfs and pentests. automates boring enum.

update: `flour_mill --update`
