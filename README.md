# flour mill

automated recon wrapper for nmap + tools. scans stuff, checks for vulns, runs the right tools based on what's open.

## what is this

basically wraps nmap and a bunch of other pentesting tools into one script. point it at a target, pick a scan type, and it'll:
- scan ports
- detect the OS (roughly)
- check for known CVEs
- suggest tools for whatever's open
- optionally run those tools and log everything

made this because i was tired of running the same commands over and over during CTFs and pentests.

## requirements

you'll need:
- nmap (obviously)
- sudo access
- curl
- git
- internet connection

everything else is optional and the script will offer to install it for you.

## install

```bash
git clone https://github.com/MalwareMusashi/flour-mill
cd flour_mill
chmod +x flour_mill.sh
./flour_mill.sh
```

if you want to run it from anywhere:

```bash
# easier method - symlink it
sudo ln -s $(pwd)/flour_mill.sh /usr/local/bin/flour_mill

# or just copy it
sudo cp flour_mill.sh /usr/local/bin/flour_mill
```

the symlink method is better if you're gonna be pulling updates.

## removing it

```bash
# remove the command
sudo rm /usr/local/bin/flour_mill

# remove the repo
rm -rf ~/flour_mill

# if you want to nuke everything including tools:
pipx uninstall netexec impacket
sudo rm /usr/local/bin/{ffuf,nuclei,kerbrute}
# and whatever else you installed
```

## usage

three ways:

```bash
flour_mill 192.168.1.100              # just pass the target
export TARGET=192.168.1.100; flour_mill  # or export it
flour_mill                             # or let it ask you
```

## scan types

1. quick - just top 1k ports
2. standard - all ports with version detection (my default)
3. full - aggressive scan, everything
4. stealth - slow and quiet
5. quick stealth - for htb when you don't want to trigger stuff
6. quick aggressive - for htb when you want speed
7. udp - top 1k udp ports
8. udp full - all udp (this takes forever)
9. custom - bring your own nmap flags

## naming scans

you can name your scans which helps when you're doing multiple boxes:

```
scan name (optional):
name (or enter for default): htb-boardlight
```

makes a folder like `htb-boardlight_10.10.11.23_20241003_143022/` instead of just the IP and timestamp.

## output

saves everything to `~/Documents/scans` by default (you can change this):

```
~/Documents/scans/htb-boardlight_10.10.11.23_20241003/
├── nmap.txt          # readable output
├── nmap.xml          # for importing
├── nmap.gnmap        # greppable
├── ports.txt         # just the open ports
├── vulns.txt         # any CVEs/exploits found
└── logs/
    ├── nuclei_p80_20241003.txt
    ├── gobuster_p80_20241003.txt
    └── enum4linux_p445_20241003.txt
```

## tools it knows about

depending on what ports are open, it'll suggest:

**web (80/443/8080/8443):**
- nikto
- gobuster
- ffuf
- dirsearch
- nuclei
- sqlmap

**smb (139/445):**
- enum4linux
- smbclient
- netexec

**kerberos (88/464):**
- kerbrute
- GetNPUsers
- GetUserSPNs

**ssh (22):**
- ssh-audit
- hydra

**plus:** ftp/rdp bruteforce, ldap enum, dns queries, etc.

if you don't have something installed, it'll offer to install it. handles apt, pipx, go installs, and github releases.

## vuln checking

for each service with a version, it'll ask if you want to check for vulns. if you say yes it searches:
- NVD database for CVEs
- GitHub for public exploits
- Exploit-DB (if you have searchsploit)

saves everything to vulns.txt.

## updating

```bash
flour_mill --update
```

or just cd into the repo and `git pull`. if you get merge conflicts because you edited the script locally:

```bash
cd ~/flour_mill
git reset --hard HEAD
git pull
```

## common issues

**"flour_mill: command not found"**
you didn't install it globally. either cd to the folder and run `./flour_mill.sh` or follow the install steps above.

**scan fails**
make sure you're running with sudo. also try pinging the target first to make sure it's up.

**nuclei not finding anything**
run `nuclei -update-templates` first. it needs to download the templates.

**tool install fails**
some tools need pipx or go. install those first:
```bash
sudo apt install pipx golang-go
```

## tips

- use scan names, it keeps things organized
- symlink install makes updates easier
- all the tools work independently after install, you can use them outside the script
- wordlists end up in `/usr/share/wordlists/`
- for nuclei, update templates regularly

## why "flour mill"

because it grinds through reconnaissance. also i thought it was funny.

---

v2.0 - added nuclei, scan naming, better tool installs
