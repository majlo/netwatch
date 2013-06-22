#! /usr/bin/perl
# Script collects data (using SNMP) from all devices defined in database.
# Status messages are written into file "messages".
# Error messages are written into file "errors".
use strict;
use warnings;
use Net::SNMP qw(:snmp);
use DBI;
use Parallel::ForkManager;
use class::Device;
use class::Interface;
use class::Ip;
use class::Mac;
use class::NetToPhysical;

# Database connection configuration.
my $db_host = "localhost";      # DB server address.
my $db_port = 5432;             # DB server port.
my $db_name = "netwatch";       # DB name.
my $db_user = "netwatchuser";   # DB Login.
my $db_pass = "netwatchpass";   # DB Password.
my $dbh;
my $sth;
my $SQL;


my @devices;                    # List of devices for monitoring (selected from database).
my $max_processes = 10;         # Maximum of processes running parallel.

my $file_errors = "errors";     # Error messages.
my $file_messages = "messages"; # Status messages.


open (ERRORS, ">>$file_errors");
open (MESSAGES, ">>$file_messages");

# Connection to database.
$dbh = DBI->connect("dbi:Pg:dbname=$db_name;host=$db_host;port=$db_port",
                        $db_user,
                        $db_pass,
                        {AutoCommit => 1, RaiseError => 0, PrintError => 0}
                    );
if(!$dbh) {
    printf (ERRORS "%s: DB_ERROR: %s.\n", get_time(), "Database connection failed");
    close (ERRORS);
    close (MESSAGES);
    exit 1;
};

$dbh->{HandleError} = sub {
    printf (ERRORS "%s: DB_ERROR: %s.\n", get_time(), $dbh->errstr);
    $dbh->disconnect;
    close (ERRORS);
    close (MESSAGES);
    exit 1;
};

# OID of specific companies.
my $OID_hp =    '1.3.6.1.4.1.11';
my $OID_3com =  '1.3.6.1.4.1.43';

# OID of system group.
my $OID_system =        '1.3.6.1.2.1.1';
    my $OID_sysDescr =      '1.3.6.1.2.1.1.1';
    my $OID_sysObjectId =   '1.3.6.1.2.1.1.2';
    my $OID_sysUpTime =     '1.3.6.1.2.1.1.3';
    my $OID_sysContact =    '1.3.6.1.2.1.1.4';
    my $OID_sysName =       '1.3.6.1.2.1.1.5';
    my $OID_sysLocation =   '1.3.6.1.2.1.1.6';
    my $OID_sysServices =   '1.3.6.1.2.1.1.7';

# OID interfaces group.
my $OID_interfaces =    '1.3.6.1.2.1.2';
    my $OID_ifTable =       '1.3.6.1.2.1.2.2';
            my $OID_ifIndex =       '1.3.6.1.2.1.2.2.1.1';
            my $OID_ifDescr =       '1.3.6.1.2.1.2.2.1.2';
            my $OID_ifType =        '1.3.6.1.2.1.2.2.1.3';
            my $OID_ifMtu =         '1.3.6.1.2.1.2.2.1.4';
            my $OID_ifSpeed =       '1.3.6.1.2.1.2.2.1.5';
            my $OID_ifPhysAddress ='1.3.6.1.2.1.2.2.1.6';
            my $OID_ifAdminStatus ='1.3.6.1.2.1.2.2.1.7';
            my $OID_ifOperStatus =  '1.3.6.1.2.1.2.2.1.8';
            my $OID_ifLastChange =  '1.3.6.1.2.1.2.2.1.9';
            my $OID_ifInOctets =    '1.3.6.1.2.1.2.2.1.10';
            my $OID_ifInUcastPkts ='1.3.6.1.2.1.2.2.1.11';
            my $OID_ifInNUcastPkts ='1.3.6.1.2.1.2.2.1.12';
            my $OID_ifInDiscards =  '1.3.6.1.2.1.2.2.1.13';
            my $OID_ifInErrors =    '1.3.6.1.2.1.2.2.1.14';
            my $OID_ifInUnknownProtos ='1.3.6.1.2.1.2.2.1.15';
            my $OID_ifOutOctets =   '1.3.6.1.2.1.2.2.1.16';
            my $OID_ifOutUcastPkts ='1.3.6.1.2.1.2.2.1.17';
            my $OID_ifOutNUcastPkts ='1.3.6.1.2.1.2.2.1.18';
            my $OID_ifOutDiscards ='1.3.6.1.2.1.2.2.1.19';
            my $OID_ifOutErrors =   '1.3.6.1.2.1.2.2.1.20';
            my $OID_ifOutQLen = '1.3.6.1.2.1.2.2.1.21';
            my $OID_ifSpecific =    '1.3.6.1.2.1.2.2.1.22';

# OID ip group
my $OID_ip =    '1.3.6.1.2.1.4';
    my $OID_ipAddressTable =    '1.3.6.1.2.1.4.34';         # this replaces deprecated ipAddrTable, contains IPv4 as well as IPv6 addresses
        my $OID_ipAddressEntry =    '1.3.6.1.2.1.4.34.1';
            my $OID_ipAddressAddrType = '1.3.6.1.2.1.4.34.1.1';     # !NOT ACCESSIBLE!, type of address (0:unknown, 1:ipv4, 2:ipv6, 3:ipv4z, 4:ipv6z, 16:dns)
            my $OID_ipAddressAddr =     '1.3.6.1.2.1.4.34.1.2';     # !NOT ACCESSIBLE!, value of address
            my $OID_ipAddressIfIndex =  '1.3.6.1.2.1.4.34.1.3';     # interface index
            my $OID_ipAddressType =     '1.3.6.1.2.1.4.34.1.4';     # type of ipv4 (1:anycast, 2:unicast, 3:broadcast)
            my $OID_ipAddressPrefix =   '1.3.6.1.2.1.4.34.1.5';     # pointer to the row in the prefix table
            my $OID_ipAddressOrigin =   '1.3.6.1.2.1.4.34.1.6';     # method of setup of address (1:other, 2:manual, 4:dhcp, 5:linklayer, 6:random)
            my $OID_ipAddressStatus =   '1.3.6.1.2.1.4.34.1.7';     # status of address (1:preferred, 2:deprecated, 3:invalid, 4:inaccessible, 5:unknown, 6:tentative, 7:duplicate, 8:optimistic)
            my $OID_ipAddressCreated =  '1.3.6.1.2.1.4.34.1.8';     # sysUpTime from address configuration (0 if was already existing before last startup)
            my $OID_ipAddressChanged =  '1.3.6.1.2.1.4.34.1.9';     # sysUpTime of last update
    my $OID_ipAddrTable =       '1.3.6.1.2.1.4.20';         # for devices which don't support ipAddressTable
        my $OID_ipAddrEntry =       '1.3.6.1.2.1.4.20.1';
            my $OID_ipAdEntAddr =       '1.3.6.1.2.1.4.20.1.1';     # value of address
            my $OID_ipAdEntIfIndex =    '1.3.6.1.2.1.4.20.1.2';     # interface index
            my $OID_ipAdEntNetMask =    '1.3.6.1.2.1.4.20.1.3';     # network mask

# OID bridge of port mapping table
my $OID_dot1qTpFdbTable =   '1.3.6.1.2.1.17.7.1.2.2';
    my $OID_dot1qTpFdbPort =        '1.3.6.1.2.1.17.7.1.2.2.1.2';       # MAC to port mapping.
    my $OID_dot1qTpFdbStatus =      '1.3.6.1.2.1.17.7.1.2.2.1.3';       # Status of learned MAC address (1:other, 2:invalid, 3:learned, 4:self, 5:mgmt).

# OID of table which maps identifier of vlan to the VLAN_ID (HP devices only)
my $OID_dot1qVlanFdbId = '1.3.6.1.2.1.17.7.1.4.2.1.3';              # HP devices don't allow to get VLAN_ID from dot1qTpFdbTable directly, it contains only pointer to this table.

# OID of table mapping VLAN id to VLAN name for network interface (ifDescr) - HP devices only, 3com allows retrieve VLAN_ID from ifDescr directly.
my $OID_dot1qVlanStaticName = '1.3.6.1.2.1.17.7.1.4.3.1.1';

# OID of table mapping IP address MAC address
my $OID_ipNetToPhysicalTable = '1.3.6.1.2.1.4.35';
    my $OID_ipNetToPhysicalPhysAddress =    '1.3.6.1.2.1.4.35.1.4';     # MAC address value.
    my $OID_ipNetToPhysicalType =           '1.3.6.1.2.1.4.35.1.6';     # Type of mapping (1:other, 2:invalid, 3:dynamic, 4:static, 5:local).
    my $OID_ipNetToPhysicalState =          '1.3.6.1.2.1.4.35.1.7';     # Status of neighbor (1:reachable, 2:stale, 3:delay, 4:probe, 5:invalid, 6:unknown, 7:incomplete).
my $OID_ipNetToMediaTable =     '1.3.6.1.2.1.4.22';         # Used for devices which don't support ipNetToPhysicalTable.
    my $OID_ipNetToMediaIfIndex =           '1.3.6.1.2.1.4.22.1.1';     # Interface index.
    my $OID_ipNetToMediaPhysAddress =       '1.3.6.1.2.1.4.22.1.2';     # MAC address value.
    my $OID_ipNetToMediaNetAddress =        '1.3.6.1.2.1.4.22.1.3';     # IPv4 address value.
    my $OID_ipNetToMediaType =              '1.3.6.1.2.1.4.22.1.4';     # Type of mapping (1:other, 2:invalid, 3:dynamic, 4:static).


# Get list of network devices for scanning from DB.
$sth = $dbh->prepare('SELECT id, ip_address, hostname, community, object_id FROM device');
$sth->execute();

while (my $data = $sth->fetchrow_hashref()) {
    my $device = new Device;
    $device->set(id => $data->{id});
    $device->set(ip_address => $data->{ip_address} || "");
    $device->set(hostname => $data->{hostname} || "");
    $device->set(community => $data->{community});
    $device->set(object_id => $data->{object_id});
    push(@devices, $device);
}

$dbh->disconnect;
my $pm = new Parallel::ForkManager($max_processes);     # Prepare to run parallel processes.

foreach my $device (@devices) {
    my $pid = $pm->start and next;      # Run a new process.
    $dbh = $dbh->clone();               # New process creates its own connection to database.
    $dbh->{HandleError} = sub {         # A hook method to handle database errors.
        printf (ERRORS "%s: DB_ERROR: %s.\n", get_time(), $dbh->errstr);
        $dbh->disconnect;
        $pm->finish;
    };

    print (MESSAGES "Querying started: ".get_time()." at device: ".$device->get('hostname')."\n");

    # Variables used during processing of results from SNMP query.
    my %table;                  # Hash to store result of SNMP query.
    my @interfaces;             # List of all interfaces of queried device (class Interface).
    my %interface_index2id;     # To get DB ID of interface based of its index retrieved from SNMP.
    my %vlan_index2vlan_id;     # To get correct VLAN_ID value of HP device (HP have it stored in table dot1qVlanFdbId).
    my %interface2vlan_id;      # To get VLAN_ID of specific interface of HP device.
    my @ips;                    # List of all IP addresses of given device (class Ip).
    my @macs;                   # List of all learned MAC addresses of given device (class Mac).
    my @net_to_physicals;       # List of mapping IP->MAC.
    my @varbindlist;            # OID queried SNMP variables.
    my $result;                 # Status of SNMP query.

    # Get ID of last scan on given device (0 if none yet).
    my $id_device_last_check = $dbh->selectrow_hashref('SELECT MAX(id) AS id FROM device_check WHERE id_status = 1 AND id_device = ?', {}, $device->get_id());
    if($id_device_last_check) { $device->set(id_device_last_check => $id_device_last_check->{id}); }

    # Create connection with SNMP client.
    my ($session, $error) = Net::SNMP->session(
        -hostname    => $device->get('ip_address') || $device->get('hostname'),
        -community   => $device->get('community'),
        -nonblocking => 1,
        -translate   => [-octetstring => 0],
        -version     => 'snmpv2c',
        -timeout     => 15,
        -retries     => 2,
    );

    if (!defined $session) {
        print (ERRORS get_time().": ERROR: $error.\n");
        $dbh->disconnect;
        $pm->finish;
    }

    # Prepare a SNMP request to "system" and "interface" groups and insert it to queue.
    $result = $session->get_bulk_request(
        -varbindlist    => [
            $OID_sysDescr,
            $OID_sysObjectId,
            $OID_sysUpTime,
            $OID_sysContact,
            $OID_sysName,
            $OID_sysLocation,
            $OID_sysServices,
            $OID_ifTable
        ],
        -callback       => [ \&table_callback, \%table ],
        -nonrepeaters   => 7,
        -maxrepetitions => 100,
    );

    # Prepare a SNMP request to "ipAddressTable" group and insert it to queue.
    if (!oid_base_match($OID_3com, $device->get('object_id'))) {         # 3com devices don't know table ipAddressTable.
        $result = $session->get_bulk_request(
            -varbindlist    => [ $OID_ipAddressIfIndex ],
            -callback       => [ \&table_callback, \%table ],
            -maxrepetitions => 100,
        );
        $result = $session->get_bulk_request(
            -varbindlist    => [ $OID_ipAddressPrefix ],
            -callback       => [ \&table_callback, \%table ],
            -maxrepetitions => 100,
        );
    } else {                                                             # This is 3com device, we need to query table ipAddrTable.
        $result = $session->get_bulk_request(
            -varbindlist    => [ $OID_ipAdEntAddr ],
            -callback       => [ \&table_callback, \%table ],
            -maxrepetitions => 100,
        );
        $result = $session->get_bulk_request(
            -varbindlist    => [ $OID_ipAdEntIfIndex ],
            -callback       => [ \&table_callback, \%table ],
            -maxrepetitions => 100,
        );
        $result = $session->get_bulk_request(
            -varbindlist    => [ $OID_ipAdEntNetMask ],
            -callback       => [ \&table_callback, \%table ],
            -maxrepetitions => 100,
        );
    }
    
    # Prepare a SNMP request to "dot1qTpFdbTable" group and insert it to queue.
    $result = $session->get_bulk_request(
        -varbindlist    => [ $OID_dot1qTpFdbTable ],
        -callback       => [ \&table_callback, \%table ],
        -maxrepetitions => 100,
    );
    
    # This is HP device, we need to get VLAN_ID from table dot1qVlanFdbId and create reference between interface and VLAN_ID.
    if (oid_base_match($OID_hp, $device->get('object_id'))) {
        $result = $session->get_bulk_request(
            -varbindlist    => [ $OID_dot1qVlanFdbId ],
            -callback       => [ \&table_callback, \%table ],
            -maxrepetitions => 100,
        );
        
        $result = $session->get_bulk_request(
            -varbindlist    => [ $OID_dot1qVlanStaticName ],
            -callback       => [ \&table_callback, \%table ],
            -maxrepetitions => 100,
        );
    }

    # Create a SNMP request to "OID_ipNetToPhysicalTable" group and insert it to queue.
    if (!oid_base_match($OID_3com, $device->get('object_id'))) {         # 3com devices don't know table ipNetToPhysicalTable.
        $result = $session->get_bulk_request(
            -varbindlist    => [ $OID_ipNetToPhysicalPhysAddress ],
            -callback       => [ \&table_callback, \%table ],
            -maxrepetitions => 100,
        );
        $result = $session->get_bulk_request(
            -varbindlist    => [ $OID_ipNetToPhysicalType ],
            -callback       => [ \&table_callback, \%table ],
            -maxrepetitions => 100,
        );
        $result = $session->get_bulk_request(
            -varbindlist    => [ $OID_ipNetToPhysicalState ],
            -callback       => [ \&table_callback, \%table ],
            -maxrepetitions => 100,
        );
    } else {                                                            # This is 3com device, we need to query table ipNetToMediaTable.
        $result = $session->get_bulk_request(
            -varbindlist    => [ $OID_ipNetToMediaPhysAddress ],
            -callback       => [ \&table_callback, \%table ],
            -maxrepetitions => 100,
        );
        $result = $session->get_bulk_request(
            -varbindlist    => [ $OID_ipNetToMediaType ],
            -callback       => [ \&table_callback, \%table ],
            -maxrepetitions => 100,
        );
    };

    my ($check_time) = get_time();

    # Non-blocking loop, requests are sent to client and we wait for results.
    snmp_dispatcher();

    if ($session->error()) {        # Error occured during quering (e.g. timeout).
        printf (ERRORS get_time().": ERROR: %s\n", $session->error());
        $session->close();
        $dbh->disconnect;
        $pm->finish;
    }

    $session->close();

    print (MESSAGES "Querying finished: ".get_time()." at device: ".$device->get('hostname')."\n");

    # Get scalar values from response.
    for my $oid (oid_lex_sort(keys %table)) {
#printf ("%s: %s\n", $oid, $table{$oid});
        if (oid_base_match($OID_sysObjectId, $oid)) {
            $device->set(object_id => $table{$oid});
        } elsif (oid_base_match($OID_sysDescr, $oid)) {
            $device->set(description => $table{$oid});
        } elsif (oid_base_match($OID_sysContact, $oid)) {
            $device->set(contact => $table{$oid});
        } elsif (oid_base_match($OID_sysName, $oid)) {
            $device->set(name => $table{$oid});
        } elsif (oid_base_match($OID_sysLocation, $oid)) {
            $device->set(location => $table{$oid});
        } elsif (oid_base_match($OID_sysServices, $oid)) {
            $device->set(services => $table{$oid});
        } elsif (oid_base_match($OID_ifIndex, $oid)) {      # Index for all interfaces of given device.
            my $interface = new Interface;
            $interface->set(index => $table{$oid});
            push(@interfaces, $interface);
        } elsif (oid_base_match($OID_ipAddressIfIndex, $oid)) {  # IP addresses from table ipAddressTable.
            my $ip = new Ip;
            my $value = $oid;
            $value=~ s/$OID_ipAddressIfIndex\.//;                # Remove parts of oid, which are not necessary for parsing of values for ip and prefix.
            my $prefix = $table{$OID_ipAddressPrefix.'.'.$value};# Get prefix from table by usage of OID prefix.
            $prefix=~ s/.*\.(?=\d+$)//;                          # Remove all except last number, which is prefix.
            my (@values) = split('\.', $value);                  # Split values to get type and address.
            my $id_type = shift(@values);
            shift(@values);                                      # First value is useless, the rest is IP address.
            my $ip_address;
            if(scalar @values == 4) { $ip_address = join('.', @values); }   # This is IPv4.
            else {                                                          # This is IPv6.
                foreach (@values) {                                         # Convert from dec to hex.
                    $_ = dec2hex($_);
                }
                for(my $i = 0; $i < 16; $i+=2) {                            # Compose IPv6 address as x:x:x:x:x:x:x:x
                    $ip_address.= join('', @values[$i..$i+1]).':';
                }
                chop($ip_address);                                          # Remove the last ":" character.
            }
            $ip->set(
                index_interface => $table{$oid},
                id_type => $id_type,
                ip_address => $ip_address."/$prefix"
            );
            push(@ips, $ip);
        } elsif (oid_base_match($OID_ipAdEntAddr, $oid)) {  # Get IP addresses from table ipAddrTable.
            my $ip = new Ip;
            my ($mask) = $table{$OID_ipAdEntNetMask.".".$table{$oid}};  # Convert network mask from format 255.255.255.0 to format /24.
            my ($prefix) = '';
            my (@mask_split) = split('\.', $mask);                      # Convert mask from decimal to binary.
            foreach (@mask_split) {
                $prefix.= dec2bin($_);
            }
            $prefix=~ s/0+$//;                                          # Remove trailing zeroes.
            $prefix = length($prefix);                                  # Get length of prefix.
            $ip->set(
                index_interface => $table{$OID_ipAdEntIfIndex.".".$table{$oid}},
                id_type => 1,
                ip_address => $table{$oid}."/$prefix"
            );
            push(@ips, $ip);
        } elsif (oid_base_match($OID_dot1qTpFdbPort, $oid)) {           # Get MAC address.
            my $mac = new Mac;
            my $value = $oid;
            $value=~ s/$OID_dot1qTpFdbPort\.//;                         # Remove parts of OID which are not necessary to get values of vlan_id and prefix.
            my $id_status = $table{$OID_dot1qTpFdbStatus.'.'.$value};   # Get status from table.
            my (@values) = split('\.', $value);                         # Split values to get vlan_id and addresses.
            my $vlan_id = shift(@values);
            foreach (@values) {                                         # Conversion from dec to hex.
                $_ = dec2hex($_);
            }
            my $mac_address = join(':', @values);                       # Compose MAC address as x:x:x:x:x:x
            $mac->set(
                port => $table{$oid},
                id_interface => 0,
                index_interface => 0,
                vlan_id => $vlan_id,
                id_status => $id_status,
                mac_address => $mac_address
            );
            push(@macs, $mac);
        } elsif (oid_base_match($OID_dot1qVlanFdbId, $oid)) {               # Get values of VLAN_ID (HP devices).
            my $value = $oid;
            $value=~ s/$OID_dot1qVlanFdbId\.0\.//;                          # Remove parts of OID which are not necessary to get values of vlan_id and prefix.
            $vlan_index2vlan_id{$table{$oid}} = $value;                     # Save ID of row in table dot1qVlanFdbId and value of VLAN_ID.
        } elsif (oid_base_match($OID_dot1qVlanStaticName, $oid)) {          # Assign VLAN_ID to interface (HP devices).
            my $value = $oid;
            $value=~ s/$OID_dot1qVlanStaticName\.//;                        # Remove parts of OID which are not necessary to get values of vlan_id and prefix.
            $interface2vlan_id{$table{$oid}} = $value;                      # Save relation between ifDescr and VLAN_ID.
        } elsif (oid_base_match($OID_ipNetToPhysicalPhysAddress, $oid)) {   # Get mapping of IP to MAC from table ipNetToPhysicalTable.
            my $net_to_physical = new NetToPhysical;
            my $value = $oid;
            $value=~ s/$OID_ipNetToPhysicalPhysAddress\.//;                 # Remove parts of OID which are not necessary to get index of interface and IP address.
            my $id_state = $table{$OID_ipNetToPhysicalState.'.'.$value};    # Get status from table based on OID status.
            my $id_type = $table{$OID_ipNetToPhysicalType.'.'.$value};      # Get type of mapping.
            my $mac_address = unpack('H*', $table{$OID_ipNetToPhysicalPhysAddress.'.'.$value}); # Get value of MAC by parsing OID of MAC.
            my(@values) = split('\.', $value);                              # Split values to get index of interface, type of IP and IP address.
            my $index_interface = shift(@values);
            my $id_address_type = shift(@values);
            shift(@values);                                                 # This value stores number of octects of following address (not necessary).
            my $ip_address;
            if(scalar @values == 4) { $ip_address = join('.', @values); }   # This is IPv4.
            else {                                                          # This is IPv6.
                foreach (@values) {                                         # Convert from dec to hex.
                    $_ = dec2hex($_);
                }
                for(my $i = 0; $i < 16; $i+=2) {                            # Compse IPv6 address as format x:x:x:x:x:x:x:x
                    $ip_address.= join('', @values[$i..$i+1]).':';
                }
                chop($ip_address);                                          # Remove last ":" character.
            }
            $net_to_physical->set(
                index_interface => $index_interface,
                id_address_type => $id_address_type,
                id_type => $id_type,
                id_state => $id_state,
                mac_address => $mac_address,
                ip_address => $ip_address
            );
            if($ip_address!~ /^fe80/) {                                     # Save IPv6 (except link local addresses - prefix "fe80").
				push(@net_to_physicals, $net_to_physical);
			}
        } elsif (oid_base_match($OID_ipNetToMediaPhysAddress, $oid)) {  # Get mapping IP->MAC from table ipNetToMediaTable.
            my $net_to_physical = new NetToPhysical;
            my $mac_address = unpack('H*', $table{$oid});
            my $value = $oid;
            $value=~ s/$OID_ipNetToMediaPhysAddress\.//;                # Remove parts of OID which are not necessary to get index of interface and IP address.
            my $id_type = $table{$OID_ipNetToMediaType.'.'.$value};     # Get type of mapping.
            my(@values) = split('\.', $value);                          # Split values to get interface index and IP address.
            my $index_interface = shift(@values);
            my ($ip_address) = join('.', @values);
            $net_to_physical->set(
                index_interface => $index_interface,
                id_address_type => 1,
                id_type => $id_type,
                id_state => 6,
                mac_address => $mac_address,
                ip_address => $ip_address
            );
            push(@net_to_physicals, $net_to_physical);
        }
    }

    # Get results for every interface of given device.
    foreach my $interface (@interfaces) {
        my $i = "." . $interface->get_index();
        my $vlan_id = undef;
        $interface->set(
            description => $table{$OID_ifDescr.$i},
            id_type => $table{$OID_ifType.$i},
            speed => $table{$OID_ifSpeed.$i},
            phys_addr => unpack('H*', $table{$OID_ifPhysAddress.$i}) || undef,
            id_admin_status => $table{$OID_ifAdminStatus.$i},
            id_oper_status => $table{$OID_ifOperStatus.$i},
            in_octets => $table{$OID_ifInOctets.$i},
            in_ucast_pkts => $table{$OID_ifInUcastPkts.$i},
            in_nucast_pkts => $table{$OID_ifInNUcastPkts.$i},
            in_discards => $table{$OID_ifInDiscards.$i},
            in_errors => $table{$OID_ifInErrors.$i},
            in_unknown_proto => $table{$OID_ifInUnknownProtos.$i},
            out_octets => $table{$OID_ifOutOctets.$i},
            out_ucast_pkts => $table{$OID_ifOutUcastPkts.$i},
            out_nucast_pkts => $table{$OID_ifOutNUcastPkts.$i},
            out_discards => $table{$OID_ifOutDiscards.$i},
            out_errors => $table{$OID_ifOutErrors.$i},
            out_qlen => $table{$OID_ifOutQLen.$i},
        );
        if (oid_base_match($OID_hp, $device->get('object_id'))) {                   # Get VLAN_ID from table dot1qVlanStaticName.
            $vlan_id = $interface2vlan_id{$interface->get('description')};
            if (!$vlan_id && $interface->get('description')=~ /^VLAN(\d+)$/) {      # If we didn't get VLAN_ID in previous step but is present in ifDescr get it from there.
                $vlan_id = $1;
            }
        } else {                                                                    # 3com devices have VLAN_ID directly in ifDescr.
            $interface->get('description')=~ /^Vlan-interface(\d+)$/;
            $vlan_id = $1;
        }
        $interface->set(vlan_id => $vlan_id);
    }

    print (MESSAGES "DB update started: ".get_time()." at device: ".$device->get('hostname')."\n");
    
    # Insert information about current scan into DB.
    $dbh->do('INSERT INTO device_check(id_device, id_status, time)
              VALUES(?, ?, ?)', {},
              $device->get_id(), $device->get('id_device_check_status'), $check_time);
    $device->set(id_device_check => $dbh->last_insert_id(undef, undef, 'device_check', undef));

    # Update device information in DB.
    $dbh->do('UPDATE device SET
                object_id = ?,
                description = ?,
                contact = ?,
                name = ?,
                location = ?,
                services = ?
              WHERE id = ?', {},
              $device->get('object_id', 'description', 'contact',
                            'name', 'location', 'services', 'id'));

    # Update information about device interfaces in DB.
    foreach my $interface (@interfaces) {
        my $interface_id = $dbh->selectrow_hashref('SELECT id FROM interface WHERE id_device = ? AND index = ?', {},
                                    $device->get_id(), $interface->get_index());
        if($interface_id) {
            $dbh->do('UPDATE interface SET
                        id_type = ?,
                        speed = ?,
                        phys_addr = ?,
                        mtu = ?,
                        description = ?,
                        vlan_id = ?
                     WHERE id = ?', {},
                     ($interface->get('id_type', 'speed', 'phys_addr', 'mtu', 'description', 'vlan_id'), $interface_id->{id}));
            $interface->set(id => $interface_id->{id});
            $interface_index2id{$interface->get_index()} = $interface_id->{id};
        } else {
            $dbh->do('INSERT INTO interface(id_device, index, id_type, speed, phys_addr, mtu, description, vlan_id)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {},
                     ($device->get_id(), $interface->get('index', 'id_type', 'speed', 'phys_addr', 'mtu', 'description', 'vlan_id')));
            my $id = $dbh->last_insert_id(undef, undef, 'interface', undef);
            $interface->set(id => $id);
            $interface_index2id{$interface->get_index()} = $id;
        }
    }

    # Insert statistics about transferred data of every interface into DB.
    $sth = $dbh->prepare('INSERT INTO interface_statistics(id_interface, id_device_check, id_admin_status, id_oper_status,
                            in_octets, in_ucast_pkts, in_nucast_pkts, in_discards, in_errors, in_unknown_proto,
                            out_octets, out_ucast_pkts, out_nucast_pkts, out_discards, out_errors, out_qlen)
                          VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    foreach (@interfaces) {
        $sth->execute($_->get_id(), $device->get('id_device_check'), $_->get('id_admin_status', 'id_oper_status',
                            'in_octets', 'in_ucast_pkts', 'in_nucast_pkts', 'in_discards', 'in_errors', 'in_unknown_proto',
                            'out_octets', 'out_ucast_pkts', 'out_nucast_pkts', 'out_discards', 'out_errors', 'out_qlen'));
    }

    # Insert/Update information about IP configuration of given interface.
    foreach my $ip (@ips) {
        $ip->set(id_device => $device->get_id(), id_interface => $interface_index2id{$ip->get('index_interface')});     # Assign ID of interface and ID of device to address.
        my $ip_id = $dbh->selectrow_hashref('SELECT id FROM ip WHERE id_device = ? AND id_interface = ?
                                               AND id_type = ? AND ip_address = ? AND id_device_check_to = ?', {},
                                    ($ip->get('id_device', 'id_interface', 'id_type', 'ip_address'), $device->get('id_device_last_check')));
        if($ip_id) {
            $dbh->do('UPDATE ip SET id_device_check_to = ? WHERE id = ?', {}, ($device->get('id_device_check'), $ip_id->{id}));
            $ip->set(id => $ip_id->{id});
        } else {
            $dbh->do('INSERT INTO ip(id_device, id_interface, id_type, ip_address, id_device_check_from, id_device_check_to)
                     VALUES (?, ?, ?, ?, ?, ?)', {},
                     ($ip->get('id_device', 'id_interface', 'id_type', 'ip_address'), $device->get('id_device_check'), $device->get('id_device_check')));
            my $id = $dbh->last_insert_id(undef, undef, 'ip', undef);
            $ip->set(id => $id);
        }
    }

    # Insert/Update information about learned MAC addresses of current device.
    foreach my $mac (@macs) {
        if (oid_base_match($OID_hp, $device->get('object_id'))) {       # If this is HP device we need also update VLAN_ID by value retrieved from table dot1qVlanFdbId.
            $mac->set(vlan_id => $vlan_index2vlan_id{$mac->get('vlan_id')});
        }
        $mac->set(id_device => $device->get_id(), id_interface => $interface_index2id{$mac->get('port')} || 0);     # Assign ID of interface and ID of device to address.
        my $mac_id = $dbh->selectrow_hashref('SELECT id FROM mac WHERE id_device = ? AND port = ? AND vlan_id = ?
                                               AND id_status = ? AND mac_address = ? AND id_device_check_to = ?', {},
                                    ($mac->get('id_device', 'port', 'vlan_id', 'id_status', 'mac_address'), $device->get('id_device_last_check')));
        if($mac_id) {
            $dbh->do('UPDATE mac SET id_device_check_to = ? WHERE id = ?', {}, ($device->get('id_device_check'), $mac_id->{id}));
            $mac->set(id => $mac_id->{id});
        } else {
            $dbh->do('INSERT INTO mac(id_device, id_interface, port, vlan_id, id_status, mac_address, id_device_check_from, id_device_check_to)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {},
                     ($mac->get('id_device', 'id_interface', 'port', 'vlan_id', 'id_status', 'mac_address'), $device->get('id_device_check'), $device->get('id_device_check')));
            my $id = $dbh->last_insert_id(undef, undef, 'mac', undef);
            $mac->set(id => $id);
        }
    }

    # Insert/Update information about mapping IP->MAC.
    foreach my $net_to_physical (@net_to_physicals) {
        $net_to_physical->set(id_device => $device->get_id(), id_interface => $interface_index2id{$net_to_physical->get('index_interface')});     # Assign ID of interface and ID of device to address.
        my $net_to_physical_id = $dbh->selectrow_hashref('SELECT id FROM net_to_physical WHERE id_device = ? AND id_interface = ?
                                                          AND id_type = ? AND id_state = ? AND ip_address = ? AND mac_address = ? AND id_device_check_to = ?', {},
                                  ($net_to_physical->get('id_device', 'id_interface', 'id_type', 'id_state', 'ip_address', 'mac_address'), $device->get('id_device_last_check')));
        if($net_to_physical_id) {
            $dbh->do('UPDATE net_to_physical SET id_device_check_to = ? WHERE id = ?', {}, ($device->get('id_device_check'), $net_to_physical_id->{id}));
            $net_to_physical->set(id => $net_to_physical_id->{id});
        } else {
            $dbh->do('INSERT INTO net_to_physical(id_device, id_interface, id_address_type, id_type, id_state, mac_address, ip_address, id_device_check_from, id_device_check_to)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {},
                     ($net_to_physical->get('id_device', 'id_interface', 'id_address_type', 'id_type', 'id_state', 'mac_address', 'ip_address'), $device->get('id_device_check'), $device->get('id_device_check')));
            my $id = $dbh->last_insert_id(undef, undef, 'net_to_physical', undef);
            $net_to_physical->set(id => $id);
        }
    }

    print (MESSAGES "DB update finished: ".get_time()." at device: ".$device->get('hostname')."\n");

    $dbh->disconnect;
    $pm->finish;        # End of process.
}

$pm->wait_all_children; # Wait for all processes to finish.

close (ERRORS);
close (MESSAGES);


exit 0;

# Callback for SNMP response.
sub table_callback
{
    my ($session, $table) = @_;

    my $list = $session->var_bind_list();

    if (!defined $list) {
#        printf (ERRORS get_time().": ERROR: %s\n", $session->error());
        return;
    }

    # Go through all results and insert them into hash.
    # It is necessary to check whether we exceeded the range of queried OIDs.
    my @names = $session->var_bind_names();
    my $next  = undef;

    while (@names) {
        $next = shift @names;
        if (!oid_base_match($OID_system, $next) && !oid_base_match($OID_interfaces, $next)
         && !oid_base_match($OID_ipAddressIfIndex, $next) && !oid_base_match($OID_ipAddressPrefix, $next)
         && !oid_base_match($OID_dot1qTpFdbTable, $next) && !oid_base_match($OID_dot1qVlanFdbId, $next) && !oid_base_match($OID_dot1qVlanStaticName, $next)
         && !oid_base_match($OID_ipAdEntAddr, $next) && !oid_base_match($OID_ipAdEntIfIndex, $next) && !oid_base_match($OID_ipAdEntNetMask, $next)
         && !oid_base_match($OID_ipNetToPhysicalPhysAddress, $next)&& !oid_base_match($OID_ipNetToPhysicalType, $next)&& !oid_base_match($OID_ipNetToPhysicalState, $next)
         && !oid_base_match($OID_ipNetToMediaPhysAddress, $next) && !oid_base_match($OID_ipNetToMediaType, $next)) {
            return; # We already got all results.
        }
        $table->{$next} = $list->{$next};
    }

    # We didn't get all results yet, send another request to get all remaining values.
    # The request begins by last retrieved value.
    my $result = $session->get_bulk_request(
        -varbindlist    => [ $next ],
        -maxrepetitions => 100,
    );


    return;
}

# Get current time in SQL format.
sub get_time
{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $mon++;
    my ($time) = sprintf ('%d-%02d-%02d %02d:%02d:%02d', $year+1900, $mon, $mday, $hour, $min, $sec);
    return $time;
}

# Convert from dec to hex.
# Used to convert values of MAC a IPv6 from SNMP result.
sub dec2hex
{
    my ($value) = @_;
    $value = unpack("H*", pack("N", $value));               # dec->hex.
    $value=~ s/^0+(?=[0-9a-f]{2})//;                        # Remove leading zeros.
    return $value;
}

# Convert from dec to binary.
# Used to get length of mask (e.g. from 255.255.255.0).
sub dec2bin
{
    my ($value) = @_;
    $value = unpack("B32", pack("N", $value));              # dec->bin
    $value =~ s/^0+(?=\d)//;                                # Remove leading zeros.
    return $value;
}

