package Brokers;

sub new {

my $proto = shift;
my $class = ref( $proto ) || $proto;
my $self = {};

    bless $self, $class;

    my %params = @_;
    foreach my $key ( keys %params ){
        my $value = $params{ $key };
        $self->{ $key } = $value;
        if( $verbose ){
            print "Key: $key, Value: $value\n";
        }
    }
    return $self
}


sub property {
my $self = shift;
my $property = shift;

    # print "** Brokers property setter/getter ($property) **\n";
    if( @_ ){
        my $value = shift;
        if( $verbose ){
            print "\tSetting Broker Property: $property, => Value: $value\n";
        }
        $self->{$property} = $value;
        return $self->{$property};
    }
    else{
        if( exists( $self->{$property} ) ){
            return( $self->{$property} );
        }
        else{
            return undef;
        }
    }
}


sub properties {
my $self = shift;
    my @properties = keys( %{$self} );
    return @properties;
}

1;

