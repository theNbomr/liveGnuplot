#! /bin/perl -w
#===================================================================
#	Supervisory script to manage data logged by 'Tasmota Solar ADS1115'
#	This code is a MQTT subscriber which listens for messages posted with
#	ADC converter data from a Tasmota controlled ADS1115 ADC.
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
#	$Id: tasmota2MQTTscan.pl,v 1.1 2024/05/11 00:52:45 bomr Exp $
#
#	$Log: tasmota2MQTTscan.pl,v $
#	Revision 1.1  2024/05/11 00:52:45  bomr
#	Initial test release
#
#
#===================================================================

use strict;
use Getopt::Long;
use IO::Handle;

use constant REVISION => '$Id: tasmota2MQTTscan.pl,v 1.1 2024/05/11 00:52:45 bomr Exp $';
use constant MQTT_BROKER => 'mosquitto_sub -h 192.168.0.19 -v -t RN_IOT_DAQ/D1Mini/A0';
use constant JSON_VOLTAGE => "VAR10";

use constant LOGFILE_BASENAME => 'd1MiniADS1115.log';
use constant LOGFILE_DIRNAME => '/tmp';

sub usage($$);

my $help = undef;
my $verbose = undef;
my $logBaseName = LOGFILE_BASENAME;
my $logDirName = LOGFILE_DIRNAME;


my %optArgs = (
    "help"          =>  \$help,
    "verbose"       =>  \$verbose,
    "logBaseName=s" =>  \$logBaseName,
    "logDirName=s"  =>  \$logDirName,
);

my %optHelp = (
    "help"        =>  "This helpful message",
    "verbose"     =>  "Report activities to console",
    "logBaseName" =>  "base filename, without date stamp or directory",
    "logDirName"  =>  "directory name to store output logs",
);

my $timeStamp = "";
my $voltage = "-1e6";
my $logfileDate = "";
my $signalHappened = undef;

#
#	Trap Ctrl-C, so we can allow a complete record to be written
#	without cutting off any of the last record 
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
	#	Open log file for appending, to allow for re-starts without losing 
	#	any existing records.
	#
	open( LOG, ">>$fileName" ) || die "Cannot open '$fileName' for writing: $!\n"; 
	print( LOG "#    $fileName\n# ".localtime( time )."\n" );
	print( LOG "#    Created by: ".REVISION."\n" );

    open( MQTT, MQTT_BROKER." |" );
    while( <MQTT> ){
        if( $verbose ){
            print $_;
        }

        my $payload = $_;
        ($payload) = $payload =~ m/\{.+\}/g;
        $payload =~ s/[\{\}]//g;
        $payload =~ s/":/"^/g;
        $payload =~ s/"//g;
        my @jsonParams = split( /[,^]/, $payload );
        my %json = @jsonParams;

        $timeStamp = $json{ "Time" };
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
            if( $verbose ){
                print "New day. Filename = $fileName\n"; 
            }
        }

        if( $voltage != $json{ "A0-SmoothV" } ){
            $voltage = $json{ "A0-SmoothV" };
            if( $verbose ){
                print "$timeStamp $voltage\n";
            }
            print LOG "$timeStamp $voltage\n";
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
    foreach my $option ( keys %options ){
        my $value = $options{$option};
        $option =~ s/=.+//;
        my $text = "\t--";

        if( defined( ${$value}) ){
            if( $option =~ m/canMsgId/ ){
                $text .= sprintf( "%s (default 0x%X )", $option, ${$value} );
            }
            else{
                $text .= "$option (default ${$value})";
            }
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
