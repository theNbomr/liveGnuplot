#! /usr/bin/perl -w
use strict;
#
# plotdata.pl
#
#   This program is to copy data panel log files 
#   from a CANbus dump file and continuously update 
#   a gnuplot rendering of the data cell voltage data.
#
#
# $Author: bomr $
# $Log: plotdata.pl,v $
# Revision 1.9  2024/10/22 16:16:02  bomr
# Added 'noraise' to gnuplot X11 term
#
# Revision 1.8  2024/06/20 17:00:11  bomr
# Make compatible with Tasmota MQTT messages logged by perl script to log files :
#   - uses T date-time separator
#   - uses columns 2:3 to plot data
#
# Revision 1.7  2023/10/15 17:52:14  bomr
# Added check for no trailing '/' on log directory name
#
# Revision 1.6  2023/10/15 16:08:11  bomr
# Code cleanup - no functional change
#
# Revision 1.5  2023/10/15 15:45:59  bomr
# Improved legend formatting and added mouseformat to show time/date
#
# Revision 1.4  2023/08/21 16:30:05  bomr
# Added option to set log file base name. Minor cleanups.
#
# Revision 1.3  2023/08/06 15:08:38  bomr
# Added more command line parameters to better specify logfile names and locations
#
# Revision 1.2  2023/08/03 22:10:46  bomr
# Added commandline argument to specify log directory
#
# Revision 1.1  2023/07/19 19:09:16  bomr
# New script slightly modified and simplified from plotTemp.pl
# Plots data panel voltage acquired from Arduino and cpatured in Linux candump
# related utility: runcandump.pl wrapper around candump, processes the data into
# gnuplot compatible data logs, one per day.
#
#

use Getopt::Long;
use constant REVISION => '$Id: plotdata.pl,v 1.9 2024/10/22 16:16:02 bomr Exp $';
use constant DEFAULT_LOG_DIR    => '/mnt/delldeb8/usr1/data/';
use constant DEFAULT_BASENAME   => '_ADS1115_data';
use constant DEFAULT_SUFFIX     => '.log';
use constant DATE_FORMAT        => '%Y-%m-%d';
use constant DATA_SERVER       => "192.168.0.5";

sub usage($$);

my @gnuplotCommands = (
    'set term x11 noraise size 1080,720',
    'set datafile separator " T"',
    'set xdata time',
    'set timefmt "%H:%M:%S"',
    'set xrange ["00:00:00":"24:00:00"]',
    'set xtics "00:00:00",3600,"23:59:59"',
    'set format x "%H:%M"',
    'set mouse mouseformat 3',
    'set timestamp bottom',
    'set key on left top box opaque textcolor variable width 2 spacing 1.2 title "-- data --"',
    'set grid',
);

my $gnuplotPID;
my $gnuplot;

my @weekDays = ( "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" );

my $help = undef;
my $verbose = undef;
my $dataLogs = undef;
my $recent = 1;
my $repeat = 0;
my $gnuplotOutput = undef;
my $dataServer = DATA_SERVER;
my $logDir = DEFAULT_LOG_DIR;
my $logBaseName = DEFAULT_BASENAME;

my %optArgs = (
    "help"          =>  \$help,
    "verbose"       =>  \$verbose,
    "dataLogs=s"    =>  \$dataLogs,
    "recent=i"      =>  \$recent,
    "repeat=i"      =>  \$repeat,
    "output=s"      =>  \$gnuplotOutput,
    "logBaseName=s" =>  \$logBaseName,
    "logDir=s"      =>  \$logDir,
);

my %optHelp = (
    "help"        =>  "This helpful message",
    "verbose"     =>  "Report activities to console",
    "dataLogs"    =>  "List of specific data files to plot",
    "recent"      =>  "Number of days of most recent data to plot",
    "repeat"      =>  "Time in minutes between updates",
    "output"      =>  "Filename for plot image file (implies repeat=0)",
    "logBaseName" =>  "base name of log files, without date prefix",
    "logDir"      =>  "Where the data logs are stored",
);

# Need this so we can kill all of the 
# children and grandchildren.
# See endPlot() subroutine.
my $pgid = getpgrp(); 

    #
    #   No commandline arguments is a call for help.
    #   (not all programs will be correct to use this assumption)
    #
    if( @ARGV == 0 ){
        usage( \%optArgs, \%optHelp );
        exit( 0 );
    }


    GetOptions( %optArgs );
    if( defined( $help ) ){
        usage( \%optArgs, \%optHelp );
        exit( 0 );
    }

    if( $verbose ){
        print REVISION,"\n";
    }

    #  Make sure directory name has trailing '/'
    if( $dataLogDir !~ m/\/$/ ){
        $dataLogDir .= "//";
    }
            
    #
    #  If static data specified, modify gnuplot commands
    #
    if( defined( $gnuplotOutput ) ){
        $repeat = 0;
        $gnuplotCommands[0] = 'set term png size 1080,720';
        splice( @gnuplotCommands, 1, 0, "set output \"$gnuplotOutput\"" );
        #
        # Modify x axis to accomodate larger PNG font
        #
        $gnuplotCommands[5] = 'set xtics "00:00:00",7200,"23:59:59"';


        #
        #  Launch gnuplot. 
        #  We will use the pipe to write commands to it's stdin
        #
        $gnuplotPID = open( $gnuplot, "|/usr/bin/gnuplot" ) or die "Cannot open gnuplot : $!\n";
        use FileHandle;
        $gnuplot->autoflush(1);
    }
    else{

        #
        #  Launch gnuplot in persistant mode. We will
        #  use the pipe to write commands to it's stdin
        #
        $gnuplotPID = open( $gnuplot, "|/usr/bin/gnuplot -persist" ) or die "Cannot open gnuplot : $!\n";
        # $gnuplotPID = open( $gnuplot, "|/usr/bin/gnuplot -persist -raise" ) or die "Cannot open gnuplot : $!\n";
        use FileHandle;
        $gnuplot->autoflush(1);
        $SIG{ INT } = \&endPlot;
    
    }

    foreach my $gnuplotCommand ( @gnuplotCommands ){
        print $gnuplot "$gnuplotCommand\n";
        if( $verbose ){
            print "$gnuplotCommand\n";
        }
    }

    if( defined( $recent ) && $recent > 1 ){
        for( my $i = 1; $i < $recent; $i++ ){
            my $dateStr = `TZ=PST+8 date \"+%Y-%m-%d\" --date=\"$i days ago\"`;
            chomp $dateStr;
            my $dow = `date \"+%w\" --date=\"$i days ago\"`;
            $dow = $weekDays[ $dow ];
            my $localFile = $dataLogDir.$dateStr.$logBaseName.DEFAULT_SUFFIX;
        }
    }
    my $yesterday = "";
    my $today = undef;
    my @dataLogs = ();
    do{
        #
        #       
        #
        if( defined( $dataLogs ) ){

            print "--dataLogs: \"$dataLogs\"\n";   
            @dataLogs = split( /[ ,:;\n]+/, $dataLogs );
            for( my $i = 0; $i < @dataLogs; $i++ ){
                system( "scp -q -p '$dataServer:$dataLogs[$i]'' . > /dev/null" );
                $dataLogs[$i] = "'$dataLogs[$i]' using 1:2 with steps";
                print $dataLogs[$i],"\n";
            }
        }
        elsif( defined( $recent ) ){

            #
            #   Grab today's latest data 
            #
            my $dateStr = `TZ=PST+8 date \"+%Y-%m-%d\"`;
            chomp $dateStr;
            
            my $localFile = $dataLogDir.$dateStr.$logBaseName.DEFAULT_SUFFIX;

            #
            #  Check for new day. If new day, grab yesterday's last data file
            #
            $today = `date \"+%w\"`;
            #
            #   See if this is a new day on the temperature server. Failed 
            #   copy from the server probably means inconsistency between
            #   temp server TZ (DST) and this host in the hour after midnight.
            #
            if( $today ne $yesterday && $recent > 1 ){
                #
                #  New day. Grab one last copy of yesterday's data
                #
                my $dateStr = `TZ=PST+8 date \"+%Y-%m-%d\" --date=\"1 days ago\"`;
                chomp $dateStr;
                my $localFile = $dataLogDir.$dateStr.$logBaseName.DEFAULT_SUFFIX;
            }

            #
            #  Compose a list of all files to plot
            #
            @dataLogs = ();
            for( my $i = 0; $i < $recent; $i++ ){
                my $dateStr = `TZ=PST+8 date \"+%Y-%m-%d\" --date=\"$i days ago\"`;
                chomp $dateStr;
                my $dow = `date \"+%w\" --date=\"$i days ago\"`;
                $dow = $weekDays[ $dow ];

                $localFile = $dataLogDir.$dateStr.$logBaseName.DEFAULT_SUFFIX;
#                push @dataLogs, "'$localFile' using 1:2 with steps title '($dow) $dateStr'";
                push @dataLogs, "'$localFile' using 2:3 with steps title '($dow) $dateStr'";
            }
        }

        my $plotFiles = join( ",\\\n", sort @dataLogs );  #  Use 'trailing backslash' notation
        if( $verbose ){
            print "plot $plotFiles\n";
        }
        print $gnuplot "plot $plotFiles\n";

        sleep( $repeat * 60 );

    }while( $repeat );
    
    exit( 0 );

sub endPlot() {
    kill -9, $pgid;
    wait;
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

