#! /usr/bin/perl -w

use strict;

use Net::MQTT::Simple;

sub subscriptionHandler($$);

use constant MQTT_BROKER_IP => '192.168.1.100';
use constant MQTT_BROKER_PORT => '1883';
use constant MQTT_TOPIC => 'tele/tasmota_F74C1D/SENSOR';

    my $mqttClient = Net::MQTT::Simple->new( MQTT_BROKER_IP
    
                                            );
    $mqttClient->subscribe( MQTT_TOPIC, \&subscriptionHandler );
    
    $mqttClient->run();

                                            
                                            
sub subscriptionHandler($$){

my ( $topic,$message ) = @_;

    print "TOPIC: $topic, MESSAGE: $message\n";

}
