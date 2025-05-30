package Dbs;

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
            print "dbs: Key: $key, Value: $value\n";
        }
    }
    return( $self );
}


sub property($$){
my $self = shift;
my $property = shift;

    if( @_ ){
        $self->{$property} = @_;
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


1;

