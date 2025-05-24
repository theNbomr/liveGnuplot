#! /usr/bin/perl -w

use strict;

use Net::MQTT::Simple;
use Getopt::Long;

sub subscriptionHandler($$);
sub usage($$);

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

my %optArgs = (
    "help"          =>  \$help,
    "verbose"       =>  \$verbose,
    "logBaseName=s" =>  \$logBaseName,
    "dataLogDir=s"  =>  \$logDir,
);

my %optHelp = (
    "help"        =>  "This helpful message",
    "verbose"     =>  "Report activities to console",
    "logBaseName" =>  "base name of log files, without date prefix",
    "dataLogDir"  =>  "Where the data logs are stored",
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
    print $logfileSpec,"\n";
    open( LOGFILE, ">>$logfileSpec" ) || die "Cannot open $logfileSpec for writing : $!\n";
    print( LOGFILE '# Data log created by mqttClientTest $timeDateStamp\n"' );
    close( LOGFILE );

    # die;
    
    
    my $mqttClient = Net::MQTT::Simple->new( MQTT_BROKER_IP
                                            );
                                            
    $mqttClient->subscribe( MQTT_TOPIC, \&subscriptionHandler );
    $mqttClient->subscribe( 'RN_IoT/Heartbeat', \&subscriptionHandler );
    
    
    #  Hmmm. how do we get this to run as a background thread...?
    $mqttClient->run();

                                            
#
#   This subroutine gets called asynchronously as a callback from the MQTT Client code.
#   It gets called with two arguments: The MQTT topic and the MQTT Message
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

