use strict;
use warnings;

sub timeSpec2String($);
sub timeSpec2Fmt($);

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

        # my @brokenDownTime = localtime( time );
        # $brokenDownTime[ $timeElementLookup{ '%Y'} ] += 1900;
        # $brokenDownTime[ $timeElementLookup{ '%m'} ] += 1;

        # foreach my $timeSpec ( @ARGV ){
        #     print "timeSpec: $timeSpec\n";
        #     print timeSpec2String( $timeSpec );
        # }

sub timeSpec2String($) {
my $timeSpec = shift;

    my @brokenDownTime = localtime( time );
    $brokenDownTime[ $timeElementLookup{ '%Y'} ] += 1900;
    $brokenDownTime[ $timeElementLookup{ '%m'} ] += 1;
    
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
        print "timeSpecMacro: $timeSpecMacro\n";

        if( $timeSpecMacro eq '%w' ){
            my $dayName = $dowNames[ $brokenDownTime[ 6 ] ];
            print "DayOfWeekName : $dayName\n";
            push @timeElements, $dayName;
        }
        elsif( $timeSpecMacro eq '%n' ){
            my $monthName = $monthNames[ $brokenDownTime[ 4 ] ] ;
            print "MonthName: $monthName\n";
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

    print "$timeSpec : ", join( "::", @timeElements ),"\n";
    return( sprintf( $timeSpec, @timeElements ) );
}

sub timeSpec2Fmt($){
my $timeSpec = shift;

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
        my $formatString = $timeFormatLookup{ $timeSpecMacro };
        $timeSpec =~ s/$timeSpecMacro/$formatString/;
    }
    return( $timeSpec );
}    

#
#   Return a composed format string, and a list of indices to the broken-down 
#   time elements returned by localtime. The format string can then be re-used
#   with new localtime calls. Need to figure out how to use map() to apply the 
#   list of indices to the broken-down time array.
#
sub timeSpec2FmtInd($) {
my $timeSpec = shift;

    my @brokenDownTime = localtime( time - 86400 );
    $brokenDownTime[ $timeElementLookup{ '%Y'} ] += 1900;
    $brokenDownTime[ $timeElementLookup{ '%m'} ] += 1;
    
    my @timeIndices;  # Build up as the argument list to printf()

    #
    #   Iteratively scan the given timestamp specification string,
    #   and lookup the embedded macros (%Y, %m, %S, etc) to find the
    #   respective localtime elements and also the respective printf()
    #   format specifiers. Replace the emebedded timestamp macros 
    #   with the looked-up printf() formatters in the tiemstamp spec string.
    #
    while( my @matches = $timeSpec =~ m/%[YymdHMSnw]/ ){

        my $timeSpecMacro = $&;
        print "timeSpecMacro: $timeSpecMacro\n";
        my $timeElementIndex = $timeElementLookup{ $timeSpecMacro };

        if( $timeSpecMacro eq '%w' ){
            $timeElementIndex |= 0x80;
        }
        elsif( $timeSpecMacro eq '%n' ){
            $timeElementIndex |= 0x40;
        }
        elsif( $timeSpecMacro eq '%y' ){
            $timeElementIndex |= 0x20;
        }

        push @timeIndices, $timeElementIndex;

        # Convert one embedded macro to the respective printf() format string
        my $formatString = $timeFormatLookup{ $timeSpecMacro };
        $timeSpec =~ s/$timeSpecMacro/$formatString/;
    }

    # print "$timeSpec : ", join( "::", @timeElements ),"\n";
    return( $timeSpec, @timeIndices );
}
