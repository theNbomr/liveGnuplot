#! /usr/bin/perl -w
use strict;
#
# plotLogs.pl
#
# --------------------------------------------------------------------
#
#	Plot parameter data files with gnuplot. Continuously update 
#	plot data, reading from new data files at the beginning of 
#       each calendar day.
#       Generalized version of the original plotSolar.pl & plotTemp.pl scripts.
# --------------------------------------------------------------------


use Getopt::Long;
use constant REVISION => 'CVS Tags obsoleted by Git/Github';
use constant DEFAULT_LOG_DIR    => '/mnt/delldeb8/usr1/data/';
use constant DEFAULT_BASENAME   => '_ADS1115_data';
use constant DEFAULT_SUFFIX     => '.log';
use constant DATE_FORMAT        => '%Y-%m-%d';
use constant DATA_SERVER        => "192.168.0.5";
use constant PLOT_TITLE         => "-- data --";

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
    'set grid',
    'set key on left top box opaque textcolor variable width 2 spacing 1.2 title "-- data --"',
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
my $gnuplotTitle = PLOT_TITLE;
my $dataServer = DATA_SERVER;
my $dataLogDir = DEFAULT_LOG_DIR;
my $logBaseName = DEFAULT_BASENAME;

my %optArgs = (
    "help"          =>  \$help,
    "verbose"       =>  \$verbose,
    "dataLogs=s"    =>  \$dataLogs,
    "recent=i"      =>  \$recent,
    "repeat=i"      =>  \$repeat,
    "output=s"      =>  \$gnuplotOutput,
    "plotTitle=s"   =>  \$gnuplotTitle,
    "logBaseName=s" =>  \$logBaseName,
    "dataLogDir=s"  =>  \$dataLogDir,
);

my %optHelp = (
    "help"        =>  "This helpful message",
    "verbose"     =>  "Report activities to console",
    "dataLogs"    =>  "List of specific data files to plot",
    "recent"      =>  "Number of days of most recent data to plot",
    "repeat"      =>  "Time in minutes between updates",
    "output"      =>  "Filename for plot image file (implies repeat=0)",
    "plotTitle"   =>  "Key titlebar content",
    "logBaseName" =>  "base name of log files, without date prefix",
    "dataLogDir"  =>  "Where the data logs are stored",
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
    
    if( ! defined( $gnuplotTitle ) || $gnuplotTitle eq '' ){
        $gnuplotTitle = $logBaseName;
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
        $gnuplotCommand =~ s/-- data --/-- $gnuplotTitle --/;
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
#              Check for new day. If new day, grab yesterday's last data file
#             
#             $today = `date \"+%w\"`;
#             
#               See if this is a new day on the temperature server. Failed 
#               copy from the server probably means inconsistency between
#               temp server TZ (DST) and this host in the hour after midnight.
#             
#             if( $today ne $yesterday && $recent > 1 ){
#                 
#                  New day. Grab one last copy of yesterday's data
#                 
#                 my $dateStr = `TZ=PST+8 date \"+%Y-%m-%d\" --date=\"1 days ago\"`;
#                 chomp $dateStr;
#                 my $localFile = $dataLogDir.$dateStr.$logBaseName.DEFAULT_SUFFIX;
#             }

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

