#! /usr/bin/perl -w

use strict;

use JSON::XS;
use JSON::Path;

use Data::Dumper;


#  Grab a whole file as specified on commandline
#
# print "ARGV[0] = $ARGV[0]\n";
open( JSON_CFG, $ARGV[0] ) || die "Cannot read $ARGV[0] : $!\n";
my @jsonText = <JSON_CFG>;
close( JSON_CFG );

# Convert the array data to a string 
my $jsonText = join( "\n", @jsonText );
# print $jsonText;

# Create a JSON Parser and feed it the JSON string data
my $json = new JSON::XS;
my $jsonData = $json->decode( $jsonText );

# Display the structured result of the parsed JSON string data.
print Dumper( $jsonData );

# find some specified elements in the JSON data.
print $jsonData,"\n";

foreach my $element ( keys %{ $jsonData } ){
    print "JSON Element: $element\n";
    my $jsonDataElement = $jsonData->{ $element };
    # print "\t$jsonDataElement\n";
    # print "\t$jsonData->{ $element }\n";
    if( ref( $jsonDataElement ) eq 'ARRAY' ){
        print "\tType ARRAY\n";
    }
    elsif( ref( $jsonDataElement ) eq 'HASH' ){
        print "\tType HASH\n";
    }
    else{
        print "\tType SCALAR\n";
    }
}

# NOTE: literal strings expressing a JSON Path contain '$', and 
# therefore must be crafted as single-quoted strings to 
# prevent unwanted interpolation of the leading '$'
#
my $metricsPath = JSON::Path->new( '$.mqtt_metrics' );
my $metricsPath = JSON::Path->new( '$.metrics' );
my $metrics = $metricsPath->value( $jsonText );
my $metrics = $metricsPath->value( $jsonText );


        
        #
        #   JSON notation has the property that arrays of objects 
        #   results in the (annoying) case that each object becomes 
        #   a Perl hash with only a single key/value.
        #
        #     'mqtt_metrics' => [
        #                         {
        #                         'delldeb8' => {
        #                                         'ip' => '192.168.0.19',
        #                                         'port' => '1883'
        #                                         }
        #                         },
        #                         {
        #                         'delli3deb11' => {
        #                                             'port' => '18883',
        #                                             'ip' => '192.168.1.101'
        #                                             }
        #                         },
        #                         {
        #                         'orangepi3' => {
        #                                             'ip' => '192.68.1.100',
        #                                             'port' => '18883'
        #                                         }
        #                         }
        #                     ],

if( defined( $metrics ) ){
    print "BROKERS:\n";
    print "\tRef:", ref( $metrics ), "\n";
    foreach my $metric ( @{ $metrics } ){
        print "\tBROKER:\n";
        
        if( ref( $metric ) eq 'HASH' ){     # A JSON Object; (the key is the Object name?)
            my %metric = %{ $metric };
            #  print join( ", ", keys %metric ),"\n";
            foreach my $metricParam ( keys %metric ){
                print "\tBroker Id: $metricParam\n";
                my @metricParams = $metric{ $metricParam };
                my %metricParams = %{ shift @metricParams };
                print "\t\tParameters: ", join( ", ", keys %metricParams ),"\n";
            }
        }
    }
}
else{
    print "BROKERS undefined\n";
}

if( defined( $metrics ) ){
    print "METRICS:\n";
    print "\tRef:", ref( $metrics ), "\n";
    foreach my $metric ( @{ $metrics } ){
        print "\tMETRIC:\n";
        
        if( ref( $metric ) eq 'HASH' ){     # A JSON Object; (the key is the Object name?)
            my %metric = %{ $metric };
            #  print join( ", ", keys %metric ),"\n";
            foreach my $metricParam ( keys %metric ){
                print "\tMetric Id: $metricParam\n";
                my @metricParams = $metric{ $metricParam };
                my %metricParams = %{ shift @metricParams };
                print "\t\tParameters: ", join( ", ", keys %metricParams ),"\n";
            }
        }
    }
}
else{
    print "METRICS undefined\n";
}

# print Dumper $jsonData=>{ "Subscriptions" },"\n";
# print Dumper $jsonData=>{ "Host" },"\n";
    # foreach my $subscription( $jsonData->{ Subscriptions } ){
    #     print Dumper( $subscription );
    # }
