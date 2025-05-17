#! /usr/bin/perl -w
use strict;
#
# plotTemp.pl
#
#   This program is to copy temperature log files 
#   from a network-attached host (BeagleBone Black),
#   and continuously update a gnuplot rendering of the
#   temperature data.
#
# $Author: bomr $
# $Log: plotTemp.pl,v $
# Revision 1.11  2024/10/22 21:36:01  bomr
# Added noraise to gnuplot X11 term config
#
# Revision 1.10  2024/10/22 20:59:52  bomr
# Added noresize to gnuplot x11
#
# Revision 1.9  2023/10/14 16:50:59  bomr
# Refine key, add mouseformat to time/date
#
# Revision 1.8  2023/07/12 16:21:14  bomr
# Added colour coded legend text
#
# Revision 1.7  2019/10/10 17:45:45  bomr
# Added TZ=PST+8 to all date commands
#
# Revision 1.6  2019/09/08 17:58:06  bomr
# Added -q (quiet) to scp commands
#
# Revision 1.5  2019/08/13 20:58:08  bomr
# Changed file copy command to always use Standard Time for file naming
#
# Revision 1.4  2017/09/01 13:49:29  bomr
# Improved checking for successful retrieval of data
# and added support for PNG output (for web based display)
#
# Revision 1.3  2017/08/22 15:29:50  bomr
# Fixed option help hash keys
#
# Revision 1.2  2017/08/22 15:25:32  bomr
# Added usage() help function and CVS tags
#
#

use Getopt::Long;
use constant REVISION		=> '$Id: plotTemp.pl,v 1.11 2024/10/22 21:36:01 bomr Exp $';
use constant DEFAULT_LOG_DIR    =>  '/home/bomr/Downloads/Data/';
use constant DEFAULT_BASENAME   => '_27161_116_Ave';
use constant DEFAULT_SUFFIX     => '.log';
use constant DATE_FORMAT        => '%Y-%m-%d';
use constant TEMP_SERVER        => "192.168.0.5";

sub usage($$);

my @gnuplotCommands = (
    'set term x11 noraise size 1080,720',
    'set xdata time',
    'set timefmt "%H:%M:%S"',
    'set xrange ["00:00:00":"24:00:00"]',
    'set xtics "00:00:00",3600,"23:59:59"',
    'set format x "%H:%M"',
    'set mouse mouseformat 3',
    'set timestamp bottom',
    'set key on left top box opaque textcolor variable width 2 spacing 1.2 title "Temperatures (C)"',
    'set grid',
);

my $gnuplotPID;
my $gnuplot;

my @weekDays = ( "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" );

my $help = undef;
my $verbose = undef;
my $tempLogs = undef;
my $recent = 1;
my $repeat = 0;
my $gnuplotOutput = undef;
my $tempServer = TEMP_SERVER;

my %optArgs = (
    "help"          =>  \$help,
    "verbose"       =>  \$verbose,
    "tempLogs=s"    =>  \$tempLogs,
    "recent=i"      =>  \$recent,
    "repeat=i"      =>  \$repeat,
    "output=s"      =>  \$gnuplotOutput,
    "tempServer=s"  =>  \$tempServer,
);

my %optHelp = (
    "help"        =>  "This helpful message",
    "verbose"     =>  "Report activities to console",
    "tempLogs"    =>  "List of specific data files to plot",
    "recent"      =>  "Number of days of most recent data to plot",
    "repeat"      =>  "Time in minutes between updates",
    "output"      =>  "Filename for plot image file (implies repeat=0)",
    "tempServer"  =>  "File server to use for acquiring data files",
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
        #  Launch gnuplot in persistant mode. We will
        #  use the pipe to write commands to it's stdin
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
        $gnuplotPID = open( $gnuplot, "|/usr/bin/gnuplot -persist -raise" ) or die "Cannot open gnuplot : $!\n";
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
            my $localFile = DEFAULT_LOG_DIR.$dateStr.DEFAULT_BASENAME.DEFAULT_SUFFIX;
            my $remoteFile = $tempServer.":".$dateStr.DEFAULT_BASENAME.DEFAULT_SUFFIX;
            if( $verbose ){
                print "scp -p 'bomr\@$remoteFile' '$localFile' > /dev/null","\n";
            }
            `scp -p 'bomr\@$remoteFile' '$localFile' > /dev/null`;
        }
    }
    my $yesterday = "";
    my $today = undef;
    my @tempLogs = ();
    do{
        #
        #       
        #
        if( defined( $tempLogs ) ){

            print "--tempLogs: \"$tempLogs\"\n";   
            @tempLogs = split( /[ ,:;\n]+/, $tempLogs );
            for( my $i = 0; $i < @tempLogs; $i++ ){
                system( "scp -q -p '$tempServer:$tempLogs[$i]'' . > /dev/null" );
                $tempLogs[$i] = "'$tempLogs[$i]' using 1:2 with steps";
                print $tempLogs[$i],"\n";
            }
        }
        elsif( defined( $recent ) ){

            #
            #   Grab today's latest data 
            #
            my $dateStr = `TZ=PST+8 date \"+%Y-%m-%d\"`;
            chomp $dateStr;
            my $localFile = DEFAULT_LOG_DIR.$dateStr.DEFAULT_BASENAME.DEFAULT_SUFFIX;
            my $remoteFile = $tempServer.":".$dateStr.DEFAULT_BASENAME.DEFAULT_SUFFIX;
            if( $verbose ){
                print "scp -q -p 'bomr\@$remoteFile' '$localFile' > /dev/null","\n";
            }
            my $status = system( "scp -q -p bomr\@$remoteFile $localFile " );
            # `scp -p 'bomr\@$remoteFile' '$localFile' > /dev/null`;

            #
            #  Check for new day. If new day, grab yesterday's last data file
            #
            $today = `date \"+%w\"`;
            #
            #   See if this is a new day on the temperature server. Failed 
            #   copy from the server probably means inconsistency between
            #   temp server TZ (DST) and this host in the hour after midnight.
            #
            if( $status == 0 && $today ne $yesterday && $recent > 1 ){
                #
                #  New day. Grab one last copy of yesterday's data
                #
                my $dateStr = `TZ=PST+8 date \"+%Y-%m-%d\" --date=\"1 days ago\"`;
                chomp $dateStr;
                my $localFile = DEFAULT_LOG_DIR.$dateStr.DEFAULT_BASENAME.DEFAULT_SUFFIX;
                my $remoteFile = $tempServer.":".$dateStr.DEFAULT_BASENAME.DEFAULT_SUFFIX;
                if( $verbose ){
                    print "scp -q -p 'bomr\@$remoteFile' '$localFile' > /dev/null","\n";
                }
                # `scp -p 'bomr\@$remoteFile' '$localFile' > /dev/null`;
                $status = system( "scp -q -p bomr\@$remoteFile $localFile " );
                if( 0 == $status ){
                    $yesterday = $today;
                }
            }

            #
            #  Compose a list of all files to plot
            #
            @tempLogs = ();
            for( my $i = 0; $i < $recent; $i++ ){
                my $dateStr = `TZ=PST+8 date \"+%Y-%m-%d\" --date=\"$i days ago\"`;
                chomp $dateStr;
                my $dow = `date \"+%w\" --date=\"$i days ago\"`;
                $dow = $weekDays[ $dow ];

                my $localFile = DEFAULT_LOG_DIR.$dateStr.DEFAULT_BASENAME.DEFAULT_SUFFIX;
                push @tempLogs, "'$localFile' using 1:2 with steps title '($dow) $dateStr'";
            }
        }

        my $plotFiles = join( ",\\\n", sort @tempLogs );  #  Use 'trailing backslash' notation
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

