# Class Mac: Data describing one row of CAM table of given network device.
package Mac;
sub new {
    my $class = shift;
    my $self = {
        id => undef,                # DB primary key.
        id_device => undef,         # Identifier of network device in DB. 
        id_interface => undef,      # DB foreign key to the Interface table.
        port => undef,              # Port number from which was this value learnt.
        index_interface => undef,   # = port number.
        vlan_id => undef,           # VLAN_ID.
        id_status => undef,         # Value of SNMP dot1qTpFdbPort.
        mac_address => undef,       # Value of MAC address.
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
