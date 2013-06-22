# Class Interface: Information connected to network interface of given device.
package Interface;
sub new {
    my $class = shift;
    my $self = {
        id => undef,                    # DB primary key.
        index => undef,                 # Value of corresponding SNMP variable.
        description => undef,           # Value of corresponding SNMP variable.
        id_type => undef,               # Value of corresponding SNMP variable.
        speed => undef,                 # Value of corresponding SNMP variable.
        phys_addr => undef,             # Value of corresponding SNMP variable.
        id_admin_status => undef,       # Value of corresponding SNMP variable.
        id_oper_status => undef,        # Value of corresponding SNMP variable.
        in_octets => undef,             # Value of corresponding SNMP variable.
        in_ucast_pkts => undef,         # Value of corresponding SNMP variable.
        in_nucast_pkts => undef,        # Value of corresponding SNMP variable.
        in_discards => undef,           # Value of corresponding SNMP variable.
        in_errors => undef,             # Value of corresponding SNMP variable.
        in_unknown_proto => undef,      # Value of corresponding SNMP variable.
        out_octets => undef,            # Value of corresponding SNMP variable.
        out_ucast_pkts => undef,        # Value of corresponding SNMP variable.
        out_nucast_pkts => undef,       # Value of corresponding SNMP variable.
        out_discards => undef,          # Value of corresponding SNMP variable.
        out_errors => undef,            # Value of corresponding SNMP variable.
        out_qlen => undef,              # Value of corresponding SNMP variable.
        vlan_id => undef,               # Value of VLAN_ID if this is virtual interface of specific VLAN.
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
sub get_index {
    my $self = shift;
    return $self->{index};
}

sub set {
    my $self = shift;
    my %attr = @_;
    for (keys %attr) {
        $self->{$_} = $attr{$_};
    }
}

return 1;
