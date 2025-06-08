#! /usr/bin/perl -w 

use strict;

use lib( "." );

require TimeUtils;

my @timeFmtStrings = (
    "%Y-%m-%dT%H:%M:%S",
    "%y-%m-%dT%H:%M:%S",
    "%w_%Y-%m-%d_%H:%M:%S",
    "%y-%n-%dT%H:%M:%S",
    "[[[ %y-%n-%dT%H:%M:%S ]]]",
    "[[[ %y/%n/%dT%H:%M:%S ]]]",
    # "%w-%n\nhelloWorld",
);


    ## print TimeUtils::timeSpec2String( "%w_%Y-%m-%d_%H:%M:%S" );
    foreach my $timeFmtString ( @timeFmtStrings ){
        print "$timeFmtString, ";
        print timeSpec2Fmt(    $timeFmtString ), ", ";
        print timeSpec2String( $timeFmtString ), "\n\n";

        my( $formatStr, @timeIndices ) = timeSpec2FmtInd( $timeFmtString );
        print "$formatStr, ", join( "-:-", @timeIndices ),"\n";

        
    }

