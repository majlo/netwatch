# Class Ip: Contains information about configuration of interface on given network device.
package Ip;
sub new {
    my $class = shift;
    my $self = {
        id => undef,                # DB primary key.
        id_device => undef,         # DB foreign key to the Device table.
        id_interface => undef,      # Identifier of given interface this record is connected to.
        index_interface => undef,   # Index of given interface this record is connected to.
        id_type => undef,           # Value of SNMP ipAddressType.
        ip_address => undef,        # Value of SNMP ipAddressIfIndex.
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
