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
        
        my %metrics = %{ $metrics };  # Dereference the HASHref

        if( $verbose ){
            my @metricIds =   keys( %{ $metrics } );
            my @metrics     = values( %{ $metrics } );
            print scalar @metricIds, " Named Metrics:\n";
            print "\t", join( ", ", @metricIds ), "\n\n";
        }

        foreach my $metricId ( keys( %{ $metrics } ) ){
            my $metric = $metrics->{ $metricId };

            $metrics{ $metricId } = Metrics->new( 'name' => $metricId );

            foreach my $propertyName ( keys %{ $metric } ){
                my $propertyVal = $metric->{ $propertyName };

                if( $verbose ){
                    print "metricId: $metricId, ";
                    if( ref( $propertyVal ) ){
                        print "Property '$propertyName' not a SCALAR: $propertyVal\n";
                    }
                    else{ 
                        print "Property Name: $propertyName, Val: $propertyVal\n";
                    }
                }
                $metrics{ $metricId }->property( $propertyName => $propertyVal );
            }
            print "\n";
        }
    }
    
         
    #   
    #   Find the JSON 'Metrics' Object list. 
    #   Iterate over each JSON Metric Object, creating Perl Metrics Objects.
    #
    if( defined( $brokers ) ){
        
        my %brokers = %{ $brokers };  # Dereference the HASHref

        if( $verbose ){
            my @brokerIds =   keys( %{ $brokers } );
            my @brokers   = values( %{ $brokers } );
            print scalar @brokerIds, " Named Brokers:\n";
            print "\t", join( ", ", @brokerIds ), "\n\n";
        }

        foreach my $brokerId ( keys( %{ $brokers } ) ){
            my $broker = $brokers->{ $brokerId };

            $metrics{ $brokerId } = Brokers->new( 'name' => $brokerId );

            foreach my $propertyName ( keys %{ $broker } ){
                my $propertyVal = $broker->{ $propertyName };

                if( $verbose ){
                    print "brokerId: $brokerId, ";
                    if( ref( $propertyVal ) ){
                        print "Property '$propertyName' not a SCALAR: $propertyVal\n";
                    }
                    else{ 
                        print "Property Name: $propertyName, Val: $propertyVal\n";
                    }
                }
            }
            print "\n";
        }
    }
    
exit( 0 );
    

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

