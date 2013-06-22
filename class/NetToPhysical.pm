# Class NetToPhysical: Contains data connected to one specific row in database table, where device holds information about mapping of IP to MAC address.
package NetToPhysical;
sub new {
    my $class = shift;
    my $self = {
        id => undef,                # DB primary key.
        id_device => undef,         # DB foreign key to the Device table.
        id_interface => undef,      # Identifier of the network interface in DB.
        index_interface => undef,   # Interface index.
        id_address_type => undef,   # Type of network address.
        id_type => undef,           # Type of mapping.
        id_state => undef,          # State of accessiblity of neighbor on given interface.
        mac_address => undef,       # MAC address value.
        ip_address => undef,        # IP address value.
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
