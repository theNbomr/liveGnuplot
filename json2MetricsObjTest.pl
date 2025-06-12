#! /usr/bin/perl -w
use strict;

use JSON::Path;
use Data::Dumper;
use Getopt::Long;
use Net::MQTT::Simple;

use lib ".";
use Metrics;
use Brokers;
use Files;
use Dbs;


sub debugPrint;
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
#             "broker"  : "orangepi3",  <== BrokerId mustr match a Broker top-level ID
#             "topic"   : "tele/tasmota_F74C1D/SENSOR",
#             "ydata"   : "$.DS18B20.Temperature",
#             "yformat" : "number",
#             "xdata"   : "$.Time",
#             "xformat" : "timedate",
#             "sink" : [
#                 { "file" : "111_esp01_temperature" }  <== Each Sink Object must match the 
#                                                         File/Db Id in the respective top-level section
#             ]
#         },
#         
#         "111_esp01_signal" : {
#             "broker" : "orangepi3",
#             "topic"  : "tele/tasmota_F74C1D/STATE",
#             "ydata"  : "$.Wifi.Signal",
#             "yformat" : "number",
#             "xdata"  : "$.Time",
#             "xformat" : "timedate",
#             "sink" : [
#                 { "file" : "111_esp01_signal" }
#             ]
#         },
#         
#         "111_esp32_signal" : {
#             "broker" : "orangepi3",
#             "topic"  : "tele/tasmota_F74C1D/STATE",
#             "ydata"  : "$.Wifi.Signal",
#             "yformat" : "number",
#             "xdata"  : "$.Time",
#             "xformat" : "timedate",
#             "sink" : [
#                 { "file" : "111_esp32_signal" },
#                 { "db"   : "esp32_signal" }
#             ]
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

# my @weekDays = ( "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" );

my $help = undef;
our $verbose = undef;       # One verbose flag for all modules 
# my $logDir = LOGFILE_DIR;
# my $logBaseName = LOGFILE_BASENAME;
# my $mqttBrokerIp = MQTT_BROKER_IP;
# my $mqttBrokerPort = MQTT_BROKER_PORT;
# my $mqttTopic = MQTT_TOPIC;

my %optArgs = (
    "help"          =>  \$help,
    "verbose"       =>  \$verbose,
    # "logBaseName=s" =>  \$logBaseName,
    # "dataLogDir=s"  =>  \$logDir,
    # "mqttBrokerIp=s"  =>  \$mqttBrokerIp,
    # "mqttBrokerPort=i" => \$mqttBrokerPort,
    # "mqttTopic=s"   => \$mqttTopic,
);

my %optHelp = (
    "help"        =>  "This helpful message",
    "verbose"     =>  "Report activities to console",
    # "logBaseName" =>  "base name of log files, without date prefix",
    # "dataLogDir"  =>  "Where the data logs are sinkd",
    # "mqttBrokerIp" => "IP address or name of the MQTT broker",
    # "mqttBrokerPort" => "IP Port of the MQTT broker",
    # "mqttTopic"   =>  "MQTT Topic to subscribe to",
);



    ##
    ## ================ Main code starts here =====================
    ##

    GetOptions( %optArgs );
    if( defined( $help ) ){
        usage( \%optArgs, \%optHelp );
        exit( 0 );
    }

    debugPrint REVISION,"\n";

    #
    #  Grab a whole file as specified on commandline
    #
    # print "ARGV[0] = $ARGV[0]\n";
    open( JSON_CFG, $ARGV[0] ) || die "Cannot read $ARGV[0] : $!\n";
    my @jsonText = <JSON_CFG>;
    my $jsonLines = scalar @jsonText;
    close( JSON_CFG );

    #
    #   the JSON standard doens't provide for comments, so we 
    #   delete any embedded comment lines before feeding it to 
    #   Perl packages that read JSON data.
    #
    for( my $i = 0, my $j = 0; $i < $jsonLines; $i++ ){
        if( $jsonText[ $i ] =~ m/^\s*#/ ){
            debugPrint( "Removing line " ,$i+$j, " :$jsonText[$i]" );
            splice( @jsonText, $i, 1 );
            $jsonLines--;
            $i--;
            $j++;
        }
    }

    # Convert the array data to a string 
    my $jsonText = join( "", @jsonText );
    debugPrint $jsonText;

    # NOTE: literal strings expressing a JSON Path contain '$', and 
    # therefore must be crafted as single-quoted strings to 
    # prevent unwanted interpolation of the leading '$'
    #
    my $metricsPath = JSON::Path->new( '$.metrics' );
    my $brokersPath = JSON::Path->new( '$.mqtt_brokers' );
    my $filesPath   = JSON::Path->new( '$.files' );
    my $DBsPath     = JSON::Path->new( '$.dbs' );

    my $metrics = $metricsPath->value( $jsonText );
    my $brokers = $brokersPath->value( $jsonText );
    my $files   = $filesPath->value( $jsonText );
    my $dbs     = $DBsPath->value( $jsonText );

    # Populate these hashes to allow us to find named objects after
    # the JSON data has been fully parsed.
    my %metricObjs;
    my %brokerObjs;
    our %fileObjs;
    my %dbObjs;
    my @mqttClients;

    #   
    #   Find the JSON 'Metrics' Object list. 
    #   Iterate over each JSON Metric Object, creating Perl Metrics Objects.
    #
    if( defined( $brokers ) ){
        
        if( $verbose ){
            my @brokerIds =   keys( %{ $brokers } );
            my @brokers   = values( %{ $brokers } );
            debugPrint scalar @brokerIds, " Named Brokers:\n";
            debugPrint "\t", join( ", ", @brokerIds ), "\n\n";
        }

        foreach my $brokerId ( keys( %{ $brokers } ) ){
            my $broker = $brokers->{ $brokerId };
            $brokerObjs{ $brokerId } = Brokers->new( 'name' => $brokerId );

            debugPrint "Broker ID: $brokerId\n";
            debugPrint "Broker Obj: ", $brokerObjs{ $brokerId },"\n";
            debugPrint "Lookup: ", $brokerObjs{ $brokerId }->property( 'name' ),"\n";

            foreach my $propertyName ( keys %{ $broker } ){
                my $propertyVal = $broker->{ $propertyName };

                if( $verbose ){
                    debugPrint "brokerId: $brokerId, ";
                    if( ref( $propertyVal ) ){
                        debugPrint "Property '$propertyName' not a SCALAR: '$propertyVal'\n";
                    }
                    else{ 
                        debugPrint "Property Name: '$propertyName', Val: '$propertyVal'\n";
                    }
                }
                $brokerObjs{ $brokerId }->property( $propertyName=>$propertyVal );
            }
            debugPrint "\n";
        }
    }

    #   
    #   Find the JSON 'DBs' Object list. 
    #   Iterate over each JSON  Object, creating Perl db Objects.
    #
    if( defined( $dbs ) ){

        if( $verbose ){
            my @dbIds =   keys( %{ $dbs } );
            my @dbs   = values( %{ $dbs } );
            debugPrint scalar @dbIds, " Named Dbs:\n";
            debugPrint "\t", join( ", ", @dbIds ), "\n\n";
        }

        foreach my $dbId ( keys( %{ $dbs } ) ){    # Iterate on DB Ids
            my $db = $dbs->{ $dbId };

            $dbObjs{ $dbId } = Dbs->new( 'name' => $dbId );

            foreach my $propertyName ( keys %{ $db } ){
                my $propertyVal = $db->{ $propertyName };

                if( $verbose ){
                    debugPrint "dbId: $dbId, ";
                    if( ref( $propertyVal ) ){
                        debugPrint "Property '$propertyName' not a SCALAR: $propertyVal\n";
                    }
                    else{ 
                        debugPrint "Property Name: $propertyName, Val: $propertyVal\n";
                    }
                }
            }
            debugPrint "\n";
        }
    }
    
    #   
    #   Find the JSON 'files' Object list. 
    #   Iterate over each JSON  Object, creating Perl File Objects.
    #
    if( defined( $files ) ){

        if( $verbose ){
            my @fileIds =   keys( %{ $files } );
            my @files   = values( %{ $files } );
            debugPrint scalar @fileIds, " Named Files:\n";
            debugPrint "\t", join( ", ", @fileIds ), "\n\n";
        }

        foreach my $fileId ( keys( %{ $files } ) ){
            my $file = $files->{ $fileId };

            $fileObjs{ $fileId } = Files->new( 'name' => $fileId );

            foreach my $propertyName ( keys %{ $file } ){
                my $propertyVal = $file->{ $propertyName };

                if( $verbose ){
                    debugPrint "fileId: $fileId, ";
                    if( ref( $propertyVal ) ){
                        debugPrint "Property '$propertyName' not a SCALAR: $propertyVal\n";
                    }
                    else{ 
                        debugPrint "Property Name: $propertyName, Val: $propertyVal\n";
                    }
                }
                $fileObjs{ $fileId }->property( $propertyName => $propertyVal );
            }
            debugPrint "\n";
        }
    }

    #   
    #   Find the JSON 'Metrics' Object list. 
    #   Iterate over each JSON Metric Object, creating Perl Metrics Objects.
    #
    if( defined( $metrics ) ){
        
        my %metrics = %{ $metrics };  # Dereference the HASHref

        if( $verbose ){
            my @metricIds =   keys( %{ $metrics } );
            my @metrics   = values( %{ $metrics } );
            debugPrint scalar @metricIds, " Named Metrics:\n";
            debugPrint "\t", join( ", ", @metricIds ), "\n\n";
        }

        foreach my $metricId ( keys( %{ $metrics } ) ){
            my $metric = $metrics->{ $metricId };
            debugPrint "---------- $metricId ----------\n";

            my $thisMetricObj = Metrics->new( 'name' => $metricId, 'logfile' => '/home/bomr/tmp/rnJunk.log' );
            $metricObjs{ $metricId } = $thisMetricObj;

            foreach my $propertyName ( keys %{ $metric } ){

                my $propertyVal = $metric->{ $propertyName };
                debugPrint "Metric Property name: $propertyName, val: $propertyVal\n";

                if( $propertyName eq 'broker' ){
                    # 
                    # Lookup/validate specified broker
                    #
                    debugPrint "Validating broker '$propertyVal ... ";
                    if( exists( $brokerObjs{ $propertyVal } ) ){
                        debugPrint " checks out\n";
                        $thisMetricObj->property( 'broker' => $propertyVal );
                    }
                    else{
                        print STDERR "\nError: No such broker '$propertyVal'\n";
                        print STDERR "Brokers: ", join( ", ", keys( %brokerObjs ), ),"\n";
                        next;
                    }
                }

                # "metrics" : { 
                #     "111_esp01_temperature" : {
                #         "broker" : "orangepi3",
                #         "topic"  : "tele/tasmota_F74C1D/SENSOR",
                #         "ydata"  : "$.DS18B20.Temperature",
                #         "yformat" : "number",
                #         "xdata"   : "$.Time",
                #         "xformat" : "timedate",
                #         "sink" : { 
                #             "file" : "111_esp01_temperature",
                #             "db"   : "esp01_temperature" 
                #         }
                #     },
                elsif( $propertyName eq 'sink'){
                    debugPrint "\n=========================\nValidating sink(s) ... ";

                    # PropertyVal is an ARRAYref, so dereference it and iterate over the array.
                    my @metricSinks = @{ $propertyVal };
                    foreach my $metricSink ( @metricSinks ){

                        # metricSink is a HASHRef... => { "file/db" : "fileId/dbId" }
                        foreach my $sinkType ( keys( %{ $metricSink } ) ){
                            my $sinkId = $metricSink->{ $sinkType };
                            debugPrint "SinkType: $sinkType, sinkId: $sinkId\n";

                            if( $sinkType eq 'file' ){
                                my $fileId = $metricSink->{ $sinkType };
                                if( $verbose ){
                                    debugPrint "sink.file: $fileId ";
                                }
                                if( exists( $fileObjs{ $fileId } ) ){
                                    debugPrint " checks out\n";
                                    $thisMetricObj->sink( 'file' => $fileId );
                                }
                                else{
                                    print STDERR "\nNo such File Id: '$fileId'\n";
                                    exit( 1 );
                                }
                            }
                            elsif( $sinkType eq 'db' ){
                                my $dbId = $metricSink->{ $sinkType };
                                if( $verbose ){
                                    debugPrint "sink.db: $dbId ";
                                }
                                if( exists( $dbObjs{ $dbId } ) ){
                                    debugPrint " checks out\n";
                                    $thisMetricObj->sink( 'db' => $dbId );
                                }
                                else{
                                    print STDERR "\nNo such DB Id: '$dbId'\n";
                                    exit( 1 );
                                }
                            }
                            else {
                                print STDERR "Invalid sink Type: '$sinkType'\n";
                                exit( 1 );
                            }
                        }
                    }
                    debugPrint "\n==================< end sink validation >===========\n";
                }
                else{
                    if( $verbose ){
                        debugPrint "metricId: $metricId, ";
                        if( ref( $propertyVal ) ){
                            debugPrint "Property '$propertyName' not a SCALAR: $propertyVal\n";
                        }
                        else{ 
                            debugPrint "Property Name: $propertyName, Val: $propertyVal\n";
                        }
                    }
                    
                    $thisMetricObj->property( $propertyName => $propertyVal );
                }
            }
            debugPrint "\n";
        }
    }

    if( $metrics && $verbose ){
        debugPrint "===========================================================\n",
                   "Successfully parsed JSON input and ready to launch MQTT client listener(s)\n",
                   "===========================================================\n\n";
    }

    #
    #   Iteratively launch all specified MQTT Client subscriptions, and start up
    #   handlers for incoming data.
    #

    foreach my $metricId ( keys( %metricObjs ) ){
        my $metricObj = $metricObjs{ $metricId };
        debugPrint "\n", $metricObj->property( 'name' ), ":\n";
        debugPrint "\t$metricId: ", join( ", ", $metricObj->properties ), "\n";

        foreach my $metricProperty ( $metricObj->properties() ){
            if( $metricProperty ne 'sinks' ){
                debugPrint "Property: ", $metricProperty, 
                            ", Value: ", $metricObj->property( $metricProperty ), "\n";
            }
            else{
                debugPrint "Property (@): ", $metricProperty, 
                            ", Value: ", join( " // ", $metricObj->sink() ), "\n";
            }
        }
        my @metricSinks = $metricObj->sink( );
        print "$metricId Sinks: ", join( " : ", @metricSinks ), "\n\n";

        debugPrint( "\n" );

        my $metricBrokerId = $metricObj->property( 'broker' );
        # debugPrint "MQTT Broker ID $metricBrokerId\n";
        my $metricBroker = $brokerObjs{ $metricBrokerId };
        debugPrint "Broker Properties (main): ", 
                $metricBroker->property( 'ip' ), ", ", 
                $metricBroker->property( 'port' ),"\n";
        my $mqttClient = $metricObj->mqttClientInit( $metricBroker );
        push( @mqttClients, $mqttClient );
    }

    #
    #   Spin around, waiting for callbacks to happen
    #
    while( 1 ){
        foreach my $mqttClient ( @mqttClients ){
            $mqttClient->tick();
        }
    }

exit( 0 );
    
sub debugPrint(){
    if( $verbose ){
        print @_;
    }
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

