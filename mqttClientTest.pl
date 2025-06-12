#! /usr/bin/perl -w

use strict;

use Net::MQTT::Simple;
use Getopt::Long;

sub subscriptionHandler($$);
sub usage($$);

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
    "dataLogDir"  =>  "Where the data logs are sinkd",
    "mqttBrokerIp" => "IP address or name of the MQTT broker",
    "mqttBrokerPort" => "IP Port of the MQTT broker",
    "mqttTopic"   =>  "MQTT Topic to subscribe to",
);

    GetOptions( %optArgs );
    if( defined( $help ) ){
        usage( \%optArgs, \%optHelp );
        exit( 0 );
    }

    if( $verbose ){
        print REVISION,"\n";
    }
    
    my $timeDateStamp = `date "+%Y-%m-%d_%H:%M"`;
    $timeDateStamp =~ s/\n//g;
    my $logfileSpec = "$logDir/$timeDateStamp"."_"."$logBaseName".".log";
    if( $verbose ){
        print $logfileSpec,"\n";
    }
    open( LOGFILE, ">>$logfileSpec" ) || die "Cannot open $logfileSpec for writing : $!\n";
    print( LOGFILE "# Data log created by $0 $timeDateStamp\n" );
    close( LOGFILE );
    
    #
    #   How to use non-standard IP Port numbers...?
    #
    # my %sockOptions = ( 'port' => 1883 );  # Nope...  
    my %sockOptions = ( SO_REUSEADDR => 1 );
    my $mqttClient = Net::MQTT::Simple->new( $mqttBrokerIp.":$mqttBrokerPort"
                                             , \%sockOptions 
                                            );
                                        
    $mqttClient->subscribe( $mqttTopic, \&subscriptionHandler );
    $mqttClient->subscribe( 'RN_IoT/Heartbeat', \&subscriptionHandler );
        
    #  Hmmm. how do we get this to run as a background thread...?
    # $mqttClient->run();
    
    # Maybe we just tight-loop, calling tick()...
    while( 1 ){
        $mqttClient->tick();    # Problem solved!!!
        
        #
        #   Do other stuff...
        #
    }

                                            
#
#   This subroutine gets called asynchronously as a callback from the MQTT Client code.
#   It gets called with two arguments: The MQTT Topic and the MQTT Message
#
sub subscriptionHandler($$){

my ( $topic,$message ) = @_;

    print "TOPIC: $topic, MESSAGE: $message\n";
    open( LOGFILE, ">>$logfileSpec" ) || die "Cannot open $logfileSpec for writing : $!\n";
    print( LOGFILE "$topic $message\n" );
    close( LOGFILE );

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

