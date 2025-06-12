#! /usr/bin/perl -w
use strict;
#
#Record:
#tele/tasmota_F74C1D/SENSOR {"Time":"2025-05-13T09:50:50","DS18B20":{"Id":"0000005CBBBA","Temperature":19.9},"TempUnit":"C"}
# 
#JSON: {"Time":"2025-05-13T09:50:50","DS18B20":{"Id":"0000005CBBBA","Temperature":19.9},"TempUnit":"C"}
#
#$VAR1 = {
#          'Time' => '2025-05-13T09:50:50',
#          'TempUnit' => 'C',
#          'DS18B20' => {
#                         'Id' => '0000005CBBBA',
#                         'Temperature' => '19.9'
#                       }
#        };
#
#
use JSON::Parse 'parse_json', 'valid_json';
use Getopt::Long;
use Data::Dumper;

use constant REVISION => 'mqttLog.pl rev 0.9.0 2025-May-13 RN';

use constant MQTT_BROKER => "mosquitto_sub -t '#' -v -h localhost |";

use constant LOGFILE_BASENAME => 'ds18b20Temp111.log';
use constant LOGFILE_DIRNAME => '/home/bomr/data';

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
    "logDirName"  =>  "directory name to sink output logs",
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
        print( LOG "#    $fileName\n# ".localtime( time )."\n" );
        print( LOG "#    Created by: ".REVISION."\n" );


	open( my $mqttBroker, MQTT_BROKER ) || die "Cannot open MQTT broker : $! \n";

	while( my $record = <$mqttBroker> ){

		if( $record =~ m/$ARGV[0]/ ){

			# print "Record:\n$record \n";
			$record =~ s/.+? //;
			if( valid_json( $record ) ){
				# print "JSON: $record\n";
				my $json = parse_json( $record );
				my %json = %{$json};
				if( defined( $json{ 'DS18B20' } ) ){
					# print Dumper( $json );
					my $ds18b20 = %{$json}{ 'DS18B20' };
					my $temperature = %{$ds18b20}{ 'Temperature' };
					my $timeDate = $json{ 'Time' };
					print "$timeDate $temperature\n";
					print LOG "$timeDate $temperature\n";
				}
			}
		}
	}

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
}

