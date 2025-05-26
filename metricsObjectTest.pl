#! /usr/bin/perl -w
use strict;
use Net::MQTT::Simple;
use Getopt::Long;

    print "======<metric1>=========\n";
    my $metric1 = metric->new( name => 'temperature',
                            logfile => '/tmp/temperature.log',
                              topic => 'tele/tasmota_F74C1D/SENSOR',
                              ydata => '$.DS18B20.Temperature',
                             # mqttIp => '123.123.123.123:18883'
                             mqttIp => '207.216.254.31:18883'
                            );
    print "Initializing MQTT Connections and subscriptions\n";
    my $callback = sub{ $metric1->handler() };
    my $mqttClient1 = $metric1->mqttClientInit( $callback );

    print "=======<metric2>========\n";
    my $metric2 = metric->new( name => 'heartbeat',
                            logfile => '/tmp/heartbeat.log',
                              topic => 'RN_IoT/Heartbeat',
                              ydata => '',
                             mqttIp => '192.168.1.100:1883'
                            );
    print "Initializing MQTT Connections and subscriptions\n";
    $callback = sub{ $metric1->handler() };
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
    my $handler = sub{ $self->handler(); };
    $self->{ 'CALLBACK' } = $handler;

    return $self;
}

#
#   Establish a connection to the specified MQTT Broker, and then
#   build a subscription to the specified topic on the connected broker.
#
sub mqttClientInit {
my $self = shift;
my $callback = shift;
my $ip = $self->{ mqttIp };

    #
    #   Connect to the specified broker.
    #
    my $mqttClient = Net::MQTT::Simple->new( $ip );
    
    #
    #   Create a subscription on the already connected broker,
    #   to the specified topic. The callback will be invoked
    #   on each new data event.
    #
    my $topic = $self->{ topic };
    print "Subscribing to $topic on broker '$ip'\n";
    $mqttClient->subscribe( $topic, $callback );
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
sub handler($$){
# ----------------------------------------------------
#   These are undefined when this sub is called 
#   as a callback for an MQTT subscriber.
# ----------------------------------------------------
my $self = shift;
my $topic = shift;
my $message = shift;
# my ($topic, $message) = @_;

    # print "Metric '", $self->{ name }, "' :: '$topic' : \"$message\"\n";
    print "Metric :: '$topic' : \"$message\"\n";
    
    my $filespec = $self->{ 'logfile' };
    open( LOG, ">>$filespec" ) || die "Cannot open $filespec for writing: $!\n";
    print( LOG "'$topic' : $message\n" );
    close( LOG );
    return 2;
}


