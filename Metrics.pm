package Metrics;

sub new {

my $proto = shift;
my $class = ref( $proto ) || $proto;
my $self = {};

    bless $self, $class;

    my %params = @_;
    foreach my $key ( keys %params ){
        my $value = $params{ $key };
        $self->{ $key } = $value;
        print "Key: $key, Value: $value\n";
    }
    $self->{ stores } = [];

    # Create a curried version of the object method 
    # to use as a callback by non-object code
    # RN does not really understand HOW this works,
    # although I understand why it's needed.
    $self->{ CALLBACK } = $self->curry( 'handler' );
    return $self;
}

#
#   This is some dark-assed voodoo majick. 
#   It allows an arbitrary non-object non-instance code 
#   to make callbacks to the curried object method.
#   See the links in the comments at the top of this file.
#
sub curry { 
    my ( $self, $method_name, @args ) = @_;
    my $method = $self->can( $method_name ) || die "No $method_name method found";
    return sub { $self->$method( @args, @_ ) };
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

sub store {
my $self = shift;
my $storeId = shift;

    if( @_ ){
        # Create a new storage property composed of the type (file, db) and Id.
        if( 2 == scalar( @_ ) ){
            my( $storeType, $storeId ) = @_;
            my @stores = $self->{ stores };
            push @stores, ( $storeType, $storeId );
            return( $self->s)
        }
    }
    return( \$self->{ stores } );
}


#
#   Establish a connection to the specified MQTT Broker, and then
#   build a subscription to the specified topic on the connected broker.
#
sub mqttClientInit {
my $self = shift;
my $callback = shift;

    #
    #   Connect to the specified broker.
    #
    my $mqttClient = Net::MQTT::Simple->new( $self->{ mqttIp } );
    
    #
    #   Create a subscription on the already connected broker,
    #   to the specified topic. The callback will be invoked
    #   on each new data event.
    #
    my $ip    = $self->{ mqttIp };
    my $topic = $self->{ topic };
    print "Subscribing to $topic on broker '$ip'\n";
    $mqttClient->subscribe( $topic, $self->{ CALLBACK } );
    return( $mqttClient );
}

#
#  For this test case, the topic and message looks like this 
#           (newlines added to JSON for clarity):
#
#  tele/tasmota_F74C1D/SENSOR, {
#         "Time":"2025-05-26T11:58:51",
#         "DS18B20":{
#             "Id":"0000005CBBBA",
#             "Temperature":20.8
#         },
#         "TempUnit":"C"
#     }
#
sub handler($$$){
my $self = shift;

# ----------------------------------------------------
#   These are undefined when this sub is called 
#   as a callback for an MQTT subscriber.
# ----------------------------------------------------
my $topic = shift;
my $message = shift;
# my ($topic, $message) = @_;

    my $filespec = $self->{ 'logfile' };
    print "Metric '", $self->{ name }, "' :: '$topic' : \"$message\" ==> $filespec\n";
    
    open( LOG, ">>$filespec" ) || die "Cannot open $filespec for writing: $!\n";
    print( LOG "'$topic' : $message\n" );
    close( LOG );
    return 2;
}
1;
