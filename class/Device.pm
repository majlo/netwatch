# Class Device: Information about network device.
package Device;
sub new {
    my $class = shift;
    my $self = {
        id => undef,                    # DB primary key.
        ip_address => undef,            # IPv4 or IPv6 address of this device.
        hostname => undef,              # Hostname of device.
        community => undef,             # SNMP password.
        object_id => undef,             # Value of SNMP sysObjectID.
        description => undef,           # Value of SNMP sysDescr.
        contact => undef,               # Value of SNMP sysContact.
        name => undef,                  # Value of SNMP sysName.
        location => undef,              # Value of SNMP sysLocation.
        services => undef,              # Value of SNMP sysServices.
        id_device_check => undef,       # ID of current data collection.
        id_device_last_check => 0,      # ID of previous data collection.
        id_device_check_status => 1,    # Status of current data collection.
    };
    bless $self, $class;
    return $self;
}

sub get {
    my $self = shift;
    if(scalar @_ == 1) {
        my $attr = shift;
        return $self->{$attr};
    }
    my @attr;
    for (@_) {
        push(@attr, $self->{$_});
    }
    return @attr;
}

sub get_id {
    my $self = shift;
    return $self->{id};
}

sub set {
    my $self = shift;
    my %attr = @_;
    for (keys %attr) {
        $self->{$_} = $attr{$_};
    }
}

return 1;
