#! /usr/bin/perl -w
use strict;
use Net::MQTT::Simple;
use Getopt::Long;

    # =====================================================================
    #
    #   This is testbed code to figure out how to get the 
    #   object method for a 'metric' object to be used as the
    #   callback from a Subscription event in an MQTT Client.
    #   This is needed in order to allow the received message to 
    #   be correctly associated with the instance data of the
    #   metric, such a log file spec, parser directive, etc.
    #
    #   Prsently trying to follow the logic in
    #     <https://www.perlmonks.org/?node_id=654663>
    #
    #   Maybe this exercise is better handled with the AnyEvent module/framework
    #    <https://metacpan.org/pod/AnyEvent::MQTT>
    #
    # =====================================================================
    
    #
    #   Build up two 'metric' objects. In the real use case,
    #   arbitrary numbers of these will be built up at runtime according to a JSON
    #   notation config file.
    #
    print "======<metric1>=========\n";
    my $metric1 = metric->new( name => 'temperature',
                            logfile => '/tmp/temperature.log',
                              topic => 'tele/tasmota_F74C1D/SENSOR',
                              ydata => '$.DS18B20.Temperature',
                             # mqttIp => '123.123.123.123:18883'
                             mqttIp => '207.216.254.31:18883'
                            );
    print "=======<metric2>========\n";
    my $metric2 = metric->new( name => 'heartbeat',
                            logfile => '/tmp/heartbeat.log',
                              topic => 'RN_IoT/Heartbeat',
                              ydata => '',
                             mqttIp => '192.168.1.100:1883'
                            );

    #
    #   Somehow, this seems to work. See the following link to maybe help understand it...
    #   <https://www.perlmonks.org/?node_id=654701>
    #
    print "Initializing MQTT Connections and subscriptions\n";
    my $callback = $metric1->curry( 'handler' );
    my $mqttClient1 = $metric1->mqttClientInit( $callback );

    $callback = $metric2->curry( 'handler' );
    my $mqttClient2 = $metric2->mqttClientInit( $callback );
    
    print "=======< busy wait calling tick() >======\n";
    while( 1 ){
        $mqttClient1->tick();
        $mqttClient2->tick();
    }
;


package metric;

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
    # Create a curried version of the object method 
    # to use as a callback by non-object code
    # RN does not really understand HOW this works,
    # although I understand why it's needed.
    $self->{ CALLBACK } = $self->curry( 'handler' );
    return $self;
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

