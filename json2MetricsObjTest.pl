#! /usr/bin/perl -w
use strict;

use JSON::Path;
use Data::Dumper;
use Getopt::Long;

use lib ".";
use Metrics;
use Brokers;
# use Files;
# use DBs;


sub usage($$);

# ============================================================================
#
#   Read the specified JSON config file, and break it down into 
#   Perl Objects. The Config file contains a small number of 
#   top-level object types:
#       1. Metrics - describes the sensor/real-world data being acquired
#       2. Brokers - the MQTT Brokers that can be monitored
#       3. Files - The filespec info for filesystem storage
#       4. DBs - (not implemented yet) RDMS data capture specifications
#
#   Each of the top-level data are represented as Perl Objects, and the
#   Perl Objects are instantiated and populated with instsance data as
#   the JSON configuration data are read.
#   For each top-level JSON Object, there is a name, whihc can be used 
#   for easy lookup of a specific Object Instance, and can also be used
#   as an indentifier for reference by other Objects. Specifically, 
#   Metrics Objects make reference to Brokers and Files by name. This is
#   conceptually similar to Relational DB Primary Key semantics.
#
#
#
#
#     "metrics" : {   <============= jsonPath lookup '$.metrics': hash ref with one key: 'metrics'
#                                         we dereference the HASH ref, to get:
#         "111_esp01_temperature" : { <=== A HASH ref with one key per broker. Each key is the broker 'name'
#                                               and becomes a Perl Object with name <==> key. The value of 
#                                           the HASH is a series of HASHes (by reference), each one with a named property 
#                                           and a value.
#             "broker"  : "orangepi3",  
#             "topic"   : "tele/tasmota_F74C1D/SENSOR",
#             "ydata"   : "$.DS18B20.Temperature",
#             "yformat" : "number",
#             "xdata"   : "$.Time",
#             "xformat" : "timedate",
#             "storage" : {
#                 "file" : "111_esp01_temperature"
#             }
#         },
#         
#         "111_esp01_signal" : {
#             "broker" : "orangepi3",
#             "topic"  : "tele/tasmota_F74C1D/STATE",
#             "ydata"  : "$.Wifi.Signal",
#             "yformat" : "number",
#             "xdata"  : "$.Time",
#             "xformat" : "timedate",
#             "storage" : {
#                 "file" : "111_esp01_signal"
#             }
#         },
#         
#         "111_esp32_signal" : {
#             "broker" : "orangepi3",
#             "topic"  : "tele/tasmota_F74C1D/STATE",
#             "ydata"  : "$.Wifi.Signal",
#             "yformat" : "number",
#             "xdata"  : "$.Time",
#             "xformat" : "timedate",
#             "storage" : {
#                 "file" : "111_esp32_signal",
#                 "db"   : "esp32_signal"
#             }
#         }
#     },
# 
# ============================================================================

#
#   Change these constants to sane values for your installation. 
#   This will probably allow your version to run without any commandline options.
#
use constant REVISION => "No Revision tags in Git VCS...";
use constant MQTT_BROKER_IP => '192.168.1.100';
use constant MQTT_BROKER_PORT => '1883';
use constant MQTT_TOPIC => 'tele/tasmota_F74C1D/SENSOR';

use constant LOGFILE_DIR => '/home/bomr/tmp';
use constant LOGFILE_BASENAME => 'junkRN';

my @weekDays = ( "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" );

my $help = undef;
my $verbose = undef;
my $logDir = LOGFILE_DIR;
my $logBaseName = LOGFILE_BASENAME;
my $mqttBrokerIp = MQTT_BROKER_IP;
my $mqttBrokerPort = MQTT_BROKER_PORT;
my $mqttTopic = MQTT_TOPIC;

my %optArgs = (
    "help"          =>  \$help,
    "verbose"       =>  \$verbose,
    "logBaseName=s" =>  \$logBaseName,
    "dataLogDir=s"  =>  \$logDir,
    "mqttBrokerIp=s"  =>  \$mqttBrokerIp,
    "mqttBrokerPort=i" => \$mqttBrokerPort,
    "mqttTopic=s"   => \$mqttTopic,
);

my %optHelp = (
    "help"        =>  "This helpful message",
    "verbose"     =>  "Report activities to console",
    "logBaseName" =>  "base name of log files, without date prefix",
    "dataLogDir"  =>  "Where the data logs are stored",
    "mqttBrokerIp" => "IP address or name of the MQTT broker",
    "mqttBrokerPort" => "IP Port of the MQTT broker",
    "mqttTopic"   =>  "MQTT Topic to subscribe to",
);



    ##
    ## ================ Main code starts here =====================
    ##

    GetOptions( %optArgs );
    if( defined( $help ) ){
        usage( \%optArgs, \%optHelp );
        exit( 0 );
    }

    if( $verbose ){
        print REVISION,"\n";
    }

    #
    #  Grab a whole file as specified on commandline
    #
    # print "ARGV[0] = $ARGV[0]\n";
    open( JSON_CFG, $ARGV[0] ) || die "Cannot read $ARGV[0] : $!\n";
    my @jsonText = <JSON_CFG>;
    close( JSON_CFG );

    # Convert the array data to a string 
    my $jsonText = join( "", @jsonText );
    if( $verbose ){
        print $jsonText;
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

    # Populate these hashes to allow us to find named objects after
    # the JSON data has been fully parsed.
    my %metrics;
    my %brokers;
    my %files;
    my %dbs;
    
    #   
    #   Find the JSON 'Metrics' Object list. 
    #   Iterate over each JSON Metric Object, creating Perl Metrics Objects.
    #

    if( defined( $metrics ) ){
        if( $verbose ){
            print "METRICS:\n";
            print "\tRef:", ref( $metrics ), "\n";
        }

        if( $verbose ){
            my @metricPropertyNames =   keys( %{ $metrics } );
            my @metricProperties    = values( %{ $metrics } );
            print scalar @metricPropertyNames, " Named Metrics:\n";
            print "\t", join( ", ", @metricPropertyNames ), "\n";
        }
        
        my %metrics = %{ $metrics };  # Dereference the HASHref
        print "Metrics: ", join( ", ", values %metrics ),"\n";
        my @metricProperties = values %metrics;
        foreach my $metricProperty ( @metricProperties ){
            my %metricProperty = %{ $metricProperty };
            foreach my $propertyName ( keys %metricProperty ){   # Should be one key/value pair
                print "PropertyName : $propertyName, PropertyValue: ", $metricProperty{ $propertyName },"\n";
                
            }
        }
        
        #
        #   This should have one Key with a HASHref value that will
        #   resolve to a list of metrics, each named by its hash key.
        #
        foreach my $metric ( keys %metrics ){
        
            my $metricId = $metric;
            my $metricObj = Metrics->new( name => $metricId );
            $metrics{ $metricId } = $metricObj;

            my %metricParams = %{ $metrics{ $metric } };  # Drill down to list of metric properties
            
            if( $verbose ){
                print "\tMETRIC: $metricId: (", join( ", ", sort keys %{ $metrics{ $metric } } ), ")\n";
            }
            
            my %metricParam = %{ $metrics{ $metric } };
            
            foreach my $metricKey ( sort keys %metricParam ){  #  Actually only one key/value pair per parameter

                my $metricParamValue = $metricParam{ $metricKey };
                if( $verbose ){
                    print "\t\t$metricKey  ", $metricParamValue, "\n";
                }
                $metricObj->param( $metricKey, $metricParamValue );
                
                if( $metricKey eq 'broker' ){
#                     my $brokerJPath = '$.mqtt_brokers.'.$metricParamValue;
#                     if( $verbose ){
#                         print "\t\t\tLookup broker using '$brokerJPath'\n";
#                     }
#                     
#                     
#                       Do a lookup of the specified parameter
#                     
#                     my $brokerPath = JSON::Path->new( $brokerJPath );
#                     my $brokerObject = $brokerPath->value( $jsonText );
#                     
#                     
#                       brokerObject --> a specific broker...??
#                     
#                     if( defined( $brokerObject ) ){
#                         if( $verbose ){
#                             print "\t\t\tbroker Object: $brokerObject\n";
#                         }
#                         
#                         
#                           A broker should be a HASH reference.
#                           Extract all of the has elements, which will be the 
#                           properties of the broker and their respective property values.
#                         
#                         if( 'HASH' eq ref( $brokerObject ) ){
#                             if( $verbose ){
#                                 print "\t\t\tFound a broker object referenced by $brokerObject\n";
#                             }
#                             
#                             get the names and values of all broker properties
#                             my %broker = %{ $brokerObject };
#                             if( $verbose ){
#                                 foreach my $brokerProperty ( sort keys %broker ){
#                                     print "\t\t\t\tbroker $brokerProperty : $broker{ $brokerProperty }\n";
#                                 }
#                             }
#                         }
#                     }
#                     else{
#                         print STDERR "No broker object '$metricParamValue' found\n";
#                     }
                }
                
                elsif( $metricKey eq 'storage' ){
                
                    #
                    #   The metric's storage parameter is a list (hash) of files and/or dbs and/or...
                    #   First, find out how many objects are present in the storage parameter.
                    #
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
        
    

    
    

sub usage($$){

my  %options    = %{$_[0]};
my  %optionHelp = %{$_[1]};

    print "Usage:\nplotTemp.pl <options>\n";
    print "options:\n";
    foreach my $option ( sort keys %options ){
        my $value = $options{$option};
        $option =~ s/=.+//;
        my $text = "\t--";

        if( defined( ${$value}) ){
            $text .= "$option (default ${$value})";
        }
        else{
            $text .= "$option (undefined)";
        }

        if ($optionHelp{$option}) {
                $text .= ' -- '.$optionHelp{$option};
        }
        print "$text\n";
    }
    print "Most options should have sane defaults, but adjustments can be made\n",
          "for non-standard or alternative use cases\n";
    print "Revision: ", REVISION, "\n";
}

