# External Facing DNS with DNSSEC
The script is written to run only on CentOS or RedHat Systems, also note that script can run only as a root or sudo user.
The complete details of the script is given in the IEEE document attached. Here i'm describing an overview of the script.
## Script Details
The script consists of two phases; 
1. BIND server and its related packages are installed 
2. Domain will be added to DNS along with DNSSEC is configured. 

In first phase, BIND server and its related packages are installed and in the second phase domain will be added to DNS along with it DNSSEC is configured. First argument enter as `install`  will install bind server. Argument enter as `add domain  domain name` domain name will added.
### BIND Instalation
In the first phase, the BIND server installation is done.   the first argument is given as parameter `install`for installing BIND in the supported machine. The configuration for the BIND server is saved under the file `/etc/named.conf `. The script will check whether this file is already existing in the machine or not, if it is existing it will not further install the package and generate error alert. If the file is not found then, the script will check whether the machine is running on RHEL or Fedora-based system. If these conditions are satisfied, then the script will instruct to install BIND based on the type of operating type.
###  DNS make as External Facing
       `sed -i  's/listen-on port.*127.0.0.1; };/listen-on { any; };/' /etc/named.conf;
        sed -i  's/listen-on-v6 port.*::1; };/listen-on-v6 { any; };/' /etc/named.conf;
        sed -i  's/allow-query.*localhost; };/allow-query     { any; };/' /etc/named.conf;`
script tells BIND to listen on which port and network interface. This is done through the command` listen-on port 53 {127.0.0.1; ip-address;};` where port 53 is default port number to accept client queries. For dealing with IPv6 client queries we use the command` listen-on-v6 port 53 {any; };` .  And finally, for defining the network through which the client can raise DNS queries is enabled using the command `allowquery {127.0.0.1; net; }; `. But in our script the above mentioned three configurations are replaced their value as any in the conf file, this is because our DNS server is external facing.
### Enabling DNSSEC on BIND
       ` if [ -z "$(grep -w 'dnssec-enable yes;' /etc/named.conf)" ]; then 
            sed -i '40 i dnssec-enable yes;' /etc/named.conf;
        fi;
        if [ -z "$(grep -w 'dnssec-validation yes;' /etc/named.conf)" ]; then 
            sed -i '40 i dnssec-validation yes;' /etc/named.conf;
        fi;
            sed -i '42 i dnssec-lookaside auto;' /etc/named.conf;
            sed -i '43 i key-directory "/var/named";' /etc/named.conf;`
`named.conf `is enabled with different DNS security statements such as dnssec-enable, dnssec-validation by default otherwise we must deploy these DNS security extensions. So, the script will check whether the `named.conf` is enabled with enable option or not. If it is not enabled, the script will add dnssec-enable to the 40th line of `named.conf`. Same as the case of dnnsec-validation. But the DNS mechanism such as dnssec-lookaside is not included as default, so we must add dnssec-lookaside in 42nd line of `named.conf` fileAlso maps the key directory to the` named.conf`.

### Firewall Rule Setting
`if [ -d /etc/firewalld/zones/ ] && [[ $(systemctl is-active named) = "active" ]]; then
         firewall-cmd --permanent --add-service=dns;
         firewall-cmd --permanent --add-port=53/tcp;
         firewall-cmd --permanent --add-port=53/udp;
         firewall-cmd --reload;
 fi;`

`firewalld`is a default option by CentOS but it won’t be active. So, in the script once the `firewalld` status is checked it will add certain rules as per the requirement. the script will certain rules such as; adding DNS service using the command `firewall-cmd --permanent --add-service=dns`. DNS uses port 53 as its default port which is working on UDP and it should open using the command` firewall-cmd --permanent --addport=53/udp`;. If the response is more than 512 bytes then the request is sent through tcp port 53.

### Key Generation and Zone Signing
           `ZSK=$(dnssec-keygen -a NSEC3RSASHA1 -b 2048 -n ZONE $domain );
            KSK=$(dnssec-keygen -f KSK -a NSEC3RSASHA1 -b 4096 -n ZONE $domain);
            cat $ZSK.key  $KSK.key >> /var/named/$domain ;
            cd /var/named/ ;`
            dnssec-signzone -A -3 $(head -c 1000 /dev/random | sha1sum | cut -b 1-16) -N INCREMENT -o $domain -t $domain ;
DNSSEC operation requires two pairs of keys. Where zone signing key will created for the domain with different attributes and a size of  2048 ZSK=$(dnssec-keygen -a NSEC3RSASHA1 -b 2048 -n ZONE $domain ); and a key signing key will created a size of 4096 KSK=$(dnssec-keygen -f KSK -a NSEC3RSASHA1 -b 4096 -n ZONE $domain);. Those two keys will be added to the corresponding zone file of the domain. The dnssec-signzone is a tool in the BIND to sign the zones and the parameter O specifies the origin of the zone. The signing is done only after fetching and evaluating these keys from the key-directory. And thus, zone will be signed using the script and stored under /var/named as a new signed file.
        


