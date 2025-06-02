package Files;

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
    return( $self );
}

sub property($$){
my $self = shift;
my $property = shift;

    if( @_ ){
        $self->{$property} = shift;
        return $self->{$property};
    }
    elsif( exists( $self->{$property} ) ){
        return( $self->{$property} );
    }
    else{
        print "No File Property '$property' found\n";
        return undef;
    }
}


1;

