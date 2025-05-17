#! /usr/bin/perl -w
#===================================================================
#       Supervisory script to manage data logged by 'Tasmota Solar ADS1115'
#       This code is a MQTT subscriber which listens for messages posted with
#       ADC converter data from a Tasmota controlled ADS1115 ADC.
#
#  Tasmota rules related to this script:
# Rule3
#     ON ADS1115#A0 DO backlog
#         var8=((%value%*0.15)+(%var8%*0.85));
#         var9=%value%;
#         var10=((%var8%/32768)*4.096);
#         event publishSettings3=%var9%;
#     ENDON
# 
#     ON var8#STATE<=%Var1% DO backlog0
#         publish RN_IOT_DAQ/D1Mini/A0 {"Time":"%timestamp%","DeltaSign":"-1",A0-Live":%var9%,"A0-Smooth":%var8%,"A0-SmoothV":%var10%};
#         event SetPublishAIBounds=%var12%;
#     ENDON
# 
#     ON var8#STATE>%Var2% DO backlog0
#         publish RN_IOT_DAQ/D1Mini/A0   {"Time":"%timestamp%","DeltaSign":"+1","A0-Live":%var9%,"A0-Smooth":%var8%,"A0-SmoothV":%var10%};
#         event SetPublishAIBounds=%var12%;
#     ENDON
#     
#     ON event#SetPublishAIBounds DO backlog
#         var1=(%var8%-%value%);
#         var2=(%var8%+%value%);
#     ENDON
#  
#
#       $Id: tasmota2MQTTscan.pl,v 1.1 2024/05/11 00:52:45 bomr Exp $
#
#       $Log: tasmota2MQTTscan.pl,v $
#       Revision 1.1  2024/05/11 00:52:45  bomr
#       Initial test release
#
#
#===================================================================

use strict;
use Getopt::Long;
# use JSON::Parser;
use JSON::Path;
use IO::Handle;

# Obsolete unless using CVS (deprecated; moving to git/github)
use constant REVISION => '$Id: tasmota2MQTTscan.pl,v 1.1 2024/05/11 00:52:45 bomr Exp $';

use constant MQTT_CLIENT => 'mosquitto_sub';
use constant MQTT_BROKER => '192.168.0.19';    
use constant MQTT_TOPIC => 'tele/tasmota_F74C1D/STATE';
use constant MQTT_OPTIONS => "-v ";
use constant MQTT_JPATH => "\$";
use constant MQTT_TIME_JPATH => '$.Time';

# use constant JSON_VOLTAGE => "VAR10";

use constant LOGFILE_BASENAME => '111-ESP01_RN2-DS18B20.log';
use constant LOGFILE_DIRNAME => '/tmp';

sub usage($$);

my $help = undef;
my $verbose = undef;
my $logBaseName = LOGFILE_BASENAME;
my $logDirName = LOGFILE_DIRNAME;

my $mqttClient = MQTT_CLIENT;
my $mqttBroker = MQTT_BROKER;
my $mqttTopic = MQTT_TOPIC;
my $mqttOptions = MQTT_OPTIONS;
my $mqttJPath = MQTT_JPATH;
my $mqttTimeJPath = MQTT_TIME_JPATH;

my %optArgs = (
    "help"          =>  \$help,
    "verbose"       =>  \$verbose,
    "logBaseName=s" =>  \$logBaseName,
    "logDirName=s"  =>  \$logDirName,
    "mqttBroker=s"  =>  \$mqttBroker,
    "mqttTopic=s"   =>  \$mqttTopic,
    "mqttOptions=s" =>  \$mqttOptions,
    "mqttJPath=s"   =>  \$mqttJPath,
);

my %optHelp = (
    "help"        =>  "This helpful message",
    "verbose"     =>  "Report activities to console",
    "logBaseName" =>  "base filename, without date stamp or directory",
    "logDirName"  =>  "directory name to store output logs",
    "mqttBroker"  =>  "host name/IP of MQTT broker",
    "mqttTopic"   =>  "MQTT topic to subscribe for periodic updates",
    "mqttOptions" =>  "Command options to MQTT Client app",
    "mqttJPath"   =>  "JSON Path notation to desired sensor data",
);

my $timeStamp = "";
my $voltage = "-1e6";
my $logfileDate = "";
my $signalHappened = undef;

#
#       Trap Ctrl-C, so we can allow a complete record to be written
#       without cutting off any of the last record 
#
    $SIG{ INT } = sub{ $signalHappened = 1; };

    GetOptions( %optArgs );
    if( defined( $help ) ){
        usage( \%optArgs, \%optHelp );
        exit( 0 );
    }


    my( $sec,$min,$hour,$day,$month,$year,@other ) = localtime( time );
    my $dayOfMonth = $day;
    $logfileDate = sprintf( "%04d-%02d-%02d", $year+1900, $month+1, $day );
    my $fileName = sprintf( "%s/%s_%s", $logDirName, $logfileDate, $logBaseName );
    if( $verbose ){
        print "Logfile: $fileName\n";
    }

    # 
    #       Open log file for appending, to allow for re-starts without losing 
    #       any existing records.
    #
    open( LOG, ">>$fileName" ) || die "Cannot open '$fileName' for writing: $!\n"; 
    print( LOG "#    $fileName\n" );
    print( LOG "#    ".localtime( time )."\n" );
    print( LOG "#    Created by: ".REVISION."\n" );

    my $jPath = JSON::Path->new( $mqttJPath );
    my $timeJPath = JSON::Path->new( $mqttTimeJPath );
    
    my $mqttCommand = "$mqttClient -h $mqttBroker -t $mqttTopic $mqttOptions ";
    if( $verbose ){
        print "MQTT Command: $mqttCommand\n";
    }
    
    print( LOG "#     MQTT Command: $mqttCommand\n" );
    print( LOG "#     JSON Paths: $mqttTimeJPath, $mqttJPath\n" );
    
    open( MQTT, "$mqttCommand |" ) || die "Cannot launch $mqttCommand: $!\n";

    while( <MQTT> ){
        if( $verbose ){
            print $_;
        }
         
        #
        #   Process the MQTT payload, stripping any leading topic header
        #
        my $payload = $_;
        ($payload) = $payload =~ m/\{.+\}/g;
        my $payloadJSON = $payload;
        if( $verbose ){
            print "payload: $payload\n";
            print "payload JSON: $payloadJSON\n";
        }
        
        $timeStamp = $timeJPath->value( $payloadJSON );
        my ( $ymd,$tod ) = split( /T/, $timeStamp );

        #
        #   Time/date stamps extracted from MQTT JSON timestamps, 
        #   rather than local host times.  Hmmmm ?
        #
        if( $ymd ne $logfileDate ){
            if( $verbose ){
                print "New logfile:\n";
                print "JSON YMD: $ymd, Host logfileDate: $logfileDate\n";
            }
            $logfileDate = $ymd;
            #
            # Close the existing logfile, and open a new one
            #
            close( LOG );

            # Compose a new log file name, and then open it for writing 
            # (overwrite any previos data! )
            $fileName = sprintf( "%s/%s_%s", $logDirName, $logfileDate, $logBaseName );
            open( LOG, ">$fileName" ) || die "Cannot open '$fileName for writing: $!\n"; 

            #
            #  Start the new logfile with a simple header
            #
            print( LOG "#    $fileName   ".scalar localtime( time )."\n" );
            print( LOG "#    Created by: ".REVISION."\n" );
            print( LOG "#    MQTT Command: $mqttCommand\n" );
            print( LOG "#    JSON Paths: $mqttTimeJPath, $mqttJPath\n" );
            if( $verbose ){
                print "New day. Filename = $fileName\n"; 
            }
        }

        #
        #   Extract specified parameter from JSON encoded data
        #        
        my $jsonParam = $jPath->value( $payloadJSON );
        print LOG "$timeStamp $jsonParam\n";
        if( $verbose ){
            print "LOG $timeStamp $jsonParam\n";
        }
        
        LOG->flush();
        
        if( $signalHappened ){
            if( $verbose ){
                print "Trapped SIGINT. Exiting\n";
            }
            last;
        }

    }
    close( LOG );
    close( MQTT );
    exit( 0 );

sub usage($$){

my  %options    = %{$_[0]};
my  %optionHelp = %{$_[1]};

    print "Usage:\n$0 <options>\n";
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
