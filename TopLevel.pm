# ===============< Master Class... >========================
package TopLevel;

sub new {
my $proto = shift;
my $class = ref( $proto ) || $proto;
my $self = {};

    bless $self, $class;

    my %params = @_;
    $self->parse( \%params );
    return $self;   
}

sub parse{
my $self = shift;
my $jsonObj = shift;

    foreach my $key ( keys %{ $jsonObj } ){
        my $value = $jsonObj->{ $key };
        if( ! ref( $value ) ){
            print "Key => $key, Value=> $value\n";
            $self->{ $key } = $value;
        }
        else{
            if( ref( $value ) =~ m/^ARRAY/ ){
                # print "$key is ARRAYref Type\n";
                print "$key ARRAY: ", join( " | ", @{ $value } ), "\n";
                $self->{ $key } = $value;
            }
            elsif( ref( $value ) =~ m/HASH/ ){
                # print "$key is HASHref Type\n";
                $self->{ $key } = $value;
            }
        }
    }
    return( $self );
}

1;
