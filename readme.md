# External Facing DNS with DNSSEC
The script consists of two phases. 
1. BIND server and its related packages are installed 
2. domain will be added to DNS along with it DNSSEC is configured. 

The script is written to run only on CentOS or RedHat Systems also note that script can run only as a root or sudo user.
## Script Details
The script consists of two phases. In first phase, BIND server and its related packages are installed and in the second phase domain will be added to DNS along with it DNSSEC is configured. First argument is given as parameter install; it will install bind server. Argument given as add domain  domain name domain name will add.
### External Facing DNS
       `sed -i  's/listen-on port.*127.0.0.1; };/listen-on { any; };/' /etc/named.conf;
        sed -i  's/listen-on-v6 port.*::1; };/listen-on-v6 { any; };/' /etc/named.conf;
        sed -i  's/allow-query.*localhost; };/allow-query     { any; };/' /etc/named.conf;`
In general, for configuring BIND server, initially script tell BIND to listen on which port and network interface. This is done through the command listen-on port 53 {127.0.0.1; ip-address;}; where port 53 is default port number to accept client queries. The 127.0.0.1 loopback permits requests that are raised from local host. If this field is omitted all public interfaced will be permitted. This is the case for IPv4 client queries. For dealing with IPv6 client queries we use the command listen-on-v6 port 53 {any; }; .  And finally, for defining the network through which the client can raise DNS queries is enabled using the command allow-query {127.0.0.1; net; };.But in our script the above mentioned three configurations are replaced their value as any in the conf file, this is because our DNS server is external facing. This will provide any client to request to any IP in the DNS server

### Firewall Rule Setting
`if [ -d /etc/firewalld/zones/ ] && [[ $(systemctl is-active named) = "active" ]]; then
         firewall-cmd --permanent --add-service=dns;
         firewall-cmd --permanent --add-port=53/tcp;
         firewall-cmd --permanent --add-port=53/udp;
         firewall-cmd --reload;
 fi;`

firewalld is a default option by CentOS but it won’t be active. So, in the script once the firewalld status is checked it will add certain rules as per the requirement. Rules can be designed as either permanent or temporary. Initially by the firewalld, the connections made from outside will be disabled so for our requirement we need to add certain rules. For these reasons, script will certain rules such as; adding DNS service using the command firewall-cmd --permanent --add-service=dns. DNS uses port 53 as its default port which is working on UDP and it should open using the command firewall-cmd --permanent --add-port=53/udp;. If the response is more than 512 bytes then request is sent through tcp port 53. Whenever a rule is updated, firewalld is needs to be restarted otherwise rules will not activated

### Key Generation and Zone Signing
           `ZSK=$(dnssec-keygen -a NSEC3RSASHA1 -b 2048 -n ZONE $domain );
            KSK=$(dnssec-keygen -f KSK -a NSEC3RSASHA1 -b 4096 -n ZONE $domain);
            cat $ZSK.key  $KSK.key >> /var/named/$domain ;
            cd /var/named/ ;`
            dnssec-signzone -A -3 $(head -c 1000 /dev/random | sha1sum | cut -b 1-16) -N INCREMENT -o $domain -t $domain ;
DNSSEC operation requires two pairs of keys. Where zone signing key will created for the domain with different attributes and a size of  2048 ZSK=$(dnssec-keygen -a NSEC3RSASHA1 -b 2048 -n ZONE $domain ); and a key signing key will created a size of 4096 KSK=$(dnssec-keygen -f KSK -a NSEC3RSASHA1 -b 4096 -n ZONE $domain);. Those two keys will be added to the corresponding zone file of the domain. The dnssec-signzone is a tool in the BIND to sign the zones and the parameter O specifies the origin of the zone. The signing is done only after fetching and evaluating these keys from the key-directory. And thus, zone will be signed using the script and stored under /var/named as a new signed file.
        


