#! /usr/bin/perl -w 

use strict;

my @localtimeArgs = [
    'sec', 'minute', 'hour', 
    'month', 'dom', 'year4', 
    'dow', 'tz', 'isdst'
];

#
#   Use this to lookup the indices into the localtime array 
#
    #       0    1    2     3     4    5     6     7     8
    # my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my %timeElementLookup = (
    '%S' => 0,
    '%M' => 1,
    '%H' => 2,
    '%d' => 3,
    '%m' => 4,
    '%Y' => 5,
    '%y' => 5,
    '%w' => 6,
    '%n' => 4
);

#
#   This maps the time component to an appropriate printf format
#   This reserves '%w' for weekday names, 
#   and '%n' for month names, both 3 letter abbreviations
my %timeFormatLookup = (
    '%S' => "%02d",
    '%M' => "%02d",
    '%H' => "%02d",
    '%d' => "%02d",
    '%m' => "%02d",
    '%Y' => "%04d",
    '%y' => "%02d",
    '%w' => "%3s",
    '%n' => "%3s",
);

my @monthNames = (
    '',
    'Jan', 'Feb', 'Mar',
    'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep',
    'Oct', 'Nov', 'Dec'
);

my @dowNames = (
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
);

    my( $sec, $min, $hr, $mday, $mon, $year, $dow, $yday, $isdst ) = localtime( time );
    $year += 1900;
    $mon += 1;
    printf( "%04d-%02d-%02dT%02d_%02d_%02d\n", $year, $mon, $mday, $hr, $min, $sec );

    my @brokenDownTime = localtime( time );
    $brokenDownTime[ $timeElementLookup{ '%Y'} ] += 1900;
    $brokenDownTime[ $timeElementLookup{ '%m'} ] += 1;

    # foreach my $timeComponent ( @ARGV ){

    #     if( $timeComponent =~ m/%[YymdHMS]/ ){
    #         print "Match: $&\n";
    #         my $timeIndex = $timeElementLookup{ $& };
    #         my $formatString = $timeFormatLookup{ $& };
    #         print $formatString;
    #         printf( " $formatString\n", $brokenDownTime[ $timeIndex ] );
    #     }
    # }

    # my $timeSpec = "%Y-%m-%dT%H:%M:%S";
    my $timeSpec = $ARGV[0];
    my @timeElements;
    while( my @matches = $timeSpec =~ m/%[YymdHMSnw]/ ){
        my $timeSpecMacro = $&;
        print "timeSpecMacro: $timeSpecMacro\n";
        my $formatString     = $timeFormatLookup{ $timeSpecMacro };

        if( $timeSpecMacro eq '%w' ){
            my $dayName = $dowNames[ $brokenDownTime[ 6 ] ];
            # print "DayName : $dayName\n";
            push @timeElements, $dayName;
        }
        elsif( $timeSpecMacro eq '%n' ){
            my $monthName = $monthNames[ $brokenDownTime[ 4 ] ] ;
            # print "MonthIndex: $monthIndex, MonthName: $monthName\n";
            push @timeElements, $monthName;
        }
        elsif( $timeSpecMacro eq '%y' ){
            my $timeElementIndex = $timeElementLookup{ $timeSpecMacro };
            push @timeElements, $brokenDownTime[ $timeElementIndex ] % 100;
        }
        else{
            my $timeElementIndex = $timeElementLookup{ $timeSpecMacro };
            push @timeElements, $brokenDownTime[ $timeElementIndex ];
        }
        $timeSpec =~ s/$timeSpecMacro/$formatString/g;
    }

    print "$timeSpec : ";
    printf( "$timeSpec\n", @timeElements );

    # print "Matches: ", scalar @matches, " : $&\n";
    
