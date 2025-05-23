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
my $metricsPath = JSON::Path->new( '$.metrics' );
my $brokersPath = JSON::Path->new( '$.mqtt_brokers' );
my $filesPath   = JSON::Path->new( '$.files' );

my $metrics = $metricsPath->value( $jsonText );
my $brokers = $brokersPath->value( $jsonText );
my $files   = $filesPath->value( $jsonText );

#
        #   JSON notation has the property that arrays of objects 
        #   results in the (annoying) case that each object becomes 
        #   a Perl hash with only a single key/value.
        #
        #     'mqtt_brokers' => [
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

if( defined( $brokers ) ){      # Normally, an ARRAY Ref.
    print "BROKERS:\n";
    print "\tRef:", ref( $brokers ), "\n";
    my %brokers = %{ $brokers };
    my $brokerCount = scalar keys %brokers;
    print ref( $brokers ), "($brokerCount) => ", join( ", ", keys %brokers ), "\n";
    
    foreach my $broker ( keys %brokers ){
        print "\tBROKER:\n";
        
        if( ref( $broker ) eq 'HASH' ){     # A JSON Object; (the key is the Object name?)
            my %broker = %{ $broker };
            #  print join( ", ", keys %broker ),"\n";
            foreach my $brokerParam ( keys %broker ){
                print "\tBroker Id: $brokerParam\n";
                my @brokerParams = $broker{ $brokerParam };
                my %brokerParams = %{ shift @brokerParams };
                print "\t\tParameters: ", join( ", ", keys %brokerParams ),"\n";
                
                my $brokerId = $brokerParam;
                my $brokerPort;
                my $brokerIp;
                foreach my $key ( sort keys %brokerParams ){
                    print "$key : ", $brokerParams{ $key };
                    if( $key eq 'port' ){
                        $brokerPort = $brokerParams{ $key };
                    }
                    elsif( $key eq 'ip' ){
                        $brokerIp = $brokerParams{ $key };
                    }
                }
                # open( \$broker{ $brokerID }, "mosquitto_sub -h $brokerIp -p $brokerPort -
            }
        }
        else{
            print "Not a HASH ref\n";
        }
    }
}
else{
    print "BROKERS undefined\n";
}

if( defined( $metrics ) ){
    print "METRICS:\n";
    print "\tRef:", ref( $metrics ), "\n";
    my %metricsParams = %{ $metrics };
    foreach my $metric ( keys %metricsParams ){
        print "\tMETRIC: $metric: (", join( ", ", sort keys %{ $metricsParams{ $metric } } ), ")\n";
        my %metricParam = %{ $metricsParams{ $metric } };
        foreach my $metricKey ( sort keys %metricParam ){  #  Actually only one key/value pair per parameter
            my $metricParamValue = $metricParam{ $metricKey };
            print "\t\t$metricKey  ", $metricParamValue, "\n";

            if( $metricKey eq 'broker' ){
                my $brokerJPath = '$.mqtt_brokers.'.$metricParamValue;
                print "\t\t\tLookup broker using '$brokerJPath'\n";
            
                #
                #   Do a lookup of the specified parameter
                #
                my $brokerPath = JSON::Path->new( $brokerJPath );
                my $brokerObject = $brokerPath->value( $jsonText );
                if( defined( $brokerObject ) ){
                    print "\t\t\tbroker Object: $brokerObject\n";
                    if( 'HASH' eq ref( $brokerObject ) ){
                        print "\t\t\tFound a broker object referenced by $brokerObject\n";
                        
                        # get the names and values of all broker parameters
                        my %broker = %{ $brokerObject };
                        foreach my $brokerProperty ( sort keys %broker ){
                            print "\t\t\t\tbroker $brokerProperty : $broker{ $brokerProperty }\n";
                        }
                    }
                }
                else{
                    print "No broker object '$metricParamValue' found\n";
                }
            }
            
            elsif( $metricKey eq 'storage' ){
                my $filesJPath = '$.files.'.$metricParamValue;
                print "\t\t\tLookup file using '$filesJPath'\n";
            
                #
                #   Do a lookup of the specified parameter
                #
                my $filesPath = JSON::Path->new( $filesJPath );
                my $fileObject = $filesPath->value( $jsonText );
                if( defined( $fileObject ) ){
                    print "\t\t\tfile Object: $fileObject\n";
                    if( 'HASH' eq ref( $fileObject ) ){
                        print "\t\t\tFound a file object referenced by $fileObject\n";
                        
                        # get the names and values of all broker parameters
                        my %file = %{ $fileObject };
                        foreach my $fileProperty ( sort keys %file ){
                            print "\t\t\t\tbroker $fileProperty : $file{ $fileProperty }\n";
                        }
                    }
                }
                else{
                    print "No file object '$metricParamValue' found\n";
                }
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
