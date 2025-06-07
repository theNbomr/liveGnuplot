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

    my @brokenDownTime = localtime( time );
    $brokenDownTime[ $timeElementLookup{ '%Y'} ] += 1900;
    $brokenDownTime[ $timeElementLookup{ '%m'} ] += 1;

    foreach my $timeSpec ( @ARGV ){

        my @timeElements;  # Build up as the argument list to printf()

        #
        #   Iteratively scan the given timestamp specification string,
        #   and lookup the embedded macros (%Y, %m, %S, etc) to find the
        #   respective localtime elements and also the respective printf()
        #   format specifiers. Replace the emebedded timestamp macros 
        #   with the looked-up printf() formatters in the tiemstamp spec string.
        #
        while( my @matches = $timeSpec =~ m/%[YymdHMSnw]/ ){
            my $timeSpecMacro = $&;
            # print "timeSpecMacro: $timeSpecMacro\n";

            if( $timeSpecMacro eq '%w' ){
                my $dayName = $dowNames[ $brokenDownTime[ 6 ] ];
                # print "DayOfWeekName : $dayName\n";
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
            else{      #  "%Y, %m, %d, %H, %M, %S"
                my $timeElementIndex = $timeElementLookup{ $timeSpecMacro };
                push @timeElements, $brokenDownTime[ $timeElementIndex ];
            }

            # Convert one embedded macro to the respective printf() format string
            my $formatString = $timeFormatLookup{ $timeSpecMacro };
            $timeSpec =~ s/$timeSpecMacro/$formatString/;
        }

        print "$timeSpec : ";
        printf( "$timeSpec\n", @timeElements );
    }
    
