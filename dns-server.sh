#!/bin/bash
#bind installer 
if [[ $(whoami) = 'root' ]]; then

    if [[ $1 = 'install' ]]; then
        
        if [ -f /etc/named.conf ]; then
            echo -e "\n\n Found bind files, please remove them and restart this script again \n\n";
            exit 1;
         fi;
        if [[ -f /usr/bin/yum ]];  then
            echo -e "\n\nFound RHEL based System"; sleep 2;
            yum install vim bash-completion* bind bind-utils wget zip unzip tar haveged -y;
        elif [[ -f /usr/bin/dnf ]];  then
            echo -e "\n\nFound RHEL8/fedora based System"; sleep 2;
            dnf install vim bash-completion bind bind-utils wget zip unzip tar haveged -y;
        else
            echo -e "\n\n\t\tUnsupported OS Found - connot continue : error "; sleep 2;
            echo -e "\n\n\n\t\tExiting script.. Please try manual install.... \n\n\n"; sleep 2;
            exit 1;
        fi ;
    
        sed -i  's/listen-on port.*127.0.0.1; };/listen-on { any; };/' /etc/named.conf;
        sed -i  's/listen-on-v6 port.*::1; };/listen-on-v6 { any; };/' /etc/named.conf;
        sed -i  's/allow-query.*localhost; };/allow-query     { any; };/' /etc/named.conf;
        
        if [ -f '/bin/systemctl' ];  then
            systemctl enable named;
            systemctl enable haveged;
            systemctl start haveged;
            systemctl start named;
        else
            service named start;
            service haveged start;
            chkconfig named on ;
            chkconfig haveged on ;
        fi;
        
        if [ -f /etc/named.conf ] && [[ $(systemctl is-active named) = "active" ]]; then
           echo -e "Named Is active and working \n";
        else 
            echo -e "\nbind not installed / not started \n\t please check logs and fix issues \n";   
        fi;
        if [ -z "$(grep -w 'dnssec-enable yes;' /etc/named.conf)" ]; then 
            sed -i '40 i dnssec-enable yes;' /etc/named.conf;
        fi;
        if [ -z "$(grep -w 'dnssec-validation yes;' /etc/named.conf)" ]; then 
            sed -i '40 i dnssec-validation yes;' /etc/named.conf;
        fi;
            sed -i '42 i dnssec-lookaside auto;' /etc/named.conf;
            sed -i '43 i key-directory "/var/named";' /etc/named.conf;
       

        if [ -d /etc/firewalld/zones/ ] && [[ $(systemctl is-active named) = "active" ]]; then
         firewall-cmd --permanent --add-service=dns;
         firewall-cmd --permanent --add-port=53/tcp;
         firewall-cmd --permanent --add-port=53/udp;
         firewall-cmd --reload;
        fi;
        
        echo 'include "/etc/named.conf.local";' >> /etc/named.conf;
        touch /etc/named.conf.local;
        chown root:named /etc/named.conf.local;
        
        if [ -f '/bin/systemctl' ];  then
            systemctl restart named;
        else
            service named restart;
        fi;
    elif [[ $1 = 'add-domain' ]]; then
        if [ -z "$2" ]; then
            echo -en "\n Incorrect usage, domain name expected : \n\t $0 add-domain domainname.com \n\n\n\n";
            exit 3;
        elif [ -f /etc/named.conf ]; then
            serial=$(date +%Y%m%d)00;
            domain="$2";
            echo -en "\n\t\tEnter Target host IP pf the domain : "; read ip ;
            while [ true ]
            do
                if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    break;
                else
                     echo -en "\n\n\tSeem not a valid IP, try again : "; read ip ;
                fi;
            done
            
            check=$(grep -w $domain /etc/named.conf.local | head -1 |cut -d '"' -f2);
            if [ -z "$check" ]; then
        
                cat << EOF > /var/named/$domain
\$TTL 1h
@       IN      SOA     $domain.    root.$domain. (
                        $serial       ; Serial YYYYMMDDnn
                        24h             ; Refresh
                        2h              ; Retry
                        28d             ; Expire
                        2d              ; Minimum TTL
                        )

;Name Servers
@       IN      NS              ns1.$domain.
@       IN      NS              ns2.$domain.

;Mail Servers
@       IN      MX      0       mail.$domain.

@       IN      A        $ip

;Other Servers
ns1  IN      A               $ip
ns2  IN      A               $ip

;Canonical Names
www     IN      CNAME           $domain.
mail    IN      CNAME           $domain.
EOF


            cd  /var/named/ ;
            ZSK=$(dnssec-keygen -a NSEC3RSASHA1 -b 2048 -n ZONE $domain );
            KSK=$(dnssec-keygen -f KSK -a NSEC3RSASHA1 -b 4096 -n ZONE $domain);
            cat $ZSK.key  $KSK.key >> /var/named/$domain ;
            cd /var/named/ ;
            dnssec-signzone -A -3 $(head -c 1000 /dev/random | sha1sum | cut -b 1-16) -N INCREMENT -o $domain -t $domain ;

            
            cat << EOF >> /etc/named.conf.local
zone "$domain" IN {
         
         type master;
        
         file "/var/named/$domain.signed";

         allow-update { none; };
         # DNSSEC keys Location
            key-directory "/var/named";
          
        # Publish and Activate DNSSEC keys
            auto-dnssec maintain;

        # Use Inline Signing
            inline-signing yes;
            
};
EOF
            chown named:named /var/named/ -R;
            if [ -f '/bin/systemctl' ];  then
                systemctl restart named;
            else
                service named restart;
            fi;
           
            rndc loadkeys $domain ;
            
            if [ -f '/bin/systemctl' ];  then
                systemctl restart named;
            else
                service named restart;
            fi
            echo -e "\n\n$domain is added to the DNS and configured DNSSEC : Success\n\n";
            
            else
                echo "Domain Already existing in the DNS server, please remove it and add again";
            fi;
        else
            echo -e "\n\n\nbind install not found, please install it first using $0 install \n\n\n";
        fi;
    else
        echo -en "\n Incorrect usage, arguments expected :   \n\n\t $0 install   : for install bind\n\t $0 add-domain domainname.com \n\n\n\n";
        exit 3;
    fi;
else
    echo -e "\n\n\n\t\tScript must be executed as root / as sudo user\n\n";

fi;
