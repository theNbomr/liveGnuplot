#! /usr/bin/perl -w 
use strict;

my @json = <>;

my $jsonLines = scalar @json;

for( my $i = 0; $i < $jsonLines; $i++ ){
    if( $json[ $i ] =~ m/^\s*#/ ){
        print "Removing line $i :$json[$i]";
        splice( @json, $i, 1 );
        $jsonLines--;
        $i--;
    }
}

print join( "", @json );


