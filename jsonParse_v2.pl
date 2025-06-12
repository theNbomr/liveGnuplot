#! /usr/bin/perl -w

use strict;

use lib ".";
use Metrics;

use JSON::Path;
require epicsCA;

use constant    PI => 3.1415926;

# use Data::Dumper;

#  Grab a whole file as specified on commandline
#
open( JSON_CFG, $ARGV[0] ) || die "Cannot read $ARGV[0] : $!\n";
my @jsonText = <JSON_CFG>;
close( JSON_CFG );

#
#   Preprocessor removes comments and expands 'include files'
#
my $jsonText = preprocessJson( \@jsonText );

# NOTE: literal strings expressing a JSON Path contain '$', and 
# therefore must be crafted as single-quoted strings to 
# prevent unwanted interpolation of the leading '$'
#
my $metricsPath = JSON::Path->new( '$.metrics' );
my $brokersPath = JSON::Path->new( '$.mqtt_brokers' );
my $filesPath   = JSON::Path->new( '$.files' );
my $dbsPath     = JSON::Path->new( '$.dbs' );
my $pvsPath     = JSON::Path->new( '$.pvs' );

my $metrics = $metricsPath->value( $jsonText );
my $brokers = $brokersPath->value( $jsonText );
my $files   = $filesPath->value( $jsonText );
my $dbs     = $dbsPath->value( $jsonText );
my $pvs     = $pvsPath->value( $jsonText );

my @metricsPaths = $metricsPath->paths( $jsonText );
my @brokersPaths = $brokersPath->paths( $jsonText );
my @filesPaths   = $filesPath->paths( $jsonText );
my @dbsPaths     = $dbsPath->paths( $jsonText );
my @pvsPaths     = $pvsPath->paths( $jsonText );

#
#   Keep a lookup, by objectId, of all top-level objects read
#
our %metrics = ();
our %brokers = ();
our %files = ();
our %dbs = ();
our %sinks = ();
our %pvs = ();

# ====================================================================
#  Break out all top-level JSON Objects
# ====================================================================


# -------------------------< Brokers >--------------------------------
if( defined( $brokers ) ){
    print "\nBrokersPath: $brokersPath\n";
    print "\t", join( ",\n\t", sort keys( %{ $brokers } ) ), "\n";
    foreach my $brokerId ( sort keys( %{ $brokers } ) ){
        print "\n$brokersPath.$brokerId\n";
        my $brokerPath = JSON::Path->new( "$brokersPath.$brokerId" );
        my ( $brokerObj ) = $brokerPath->values( $jsonText );  # Parens force array context
        my $broker = Brokers->new( name => $brokerId );
        $brokers{ $brokerId } = $broker;
        $broker->parse( $brokerObj );
    }        
}
else{
    print "BROKERS undefined\n";
}


# -------------------------< Files >--------------------------------
if( defined( $files ) ){
    print "\nFilesPath: $filesPath\n";
    print "\t", join( ",\n\t", sort keys( %{ $files } ) ), "\n";
    foreach my $fileId ( sort keys( %{ $files } ) ){
        print "\n$filesPath.$fileId\n";
        my $filePath = JSON::Path->new( "$filesPath.$fileId" );
        my ( $fileObj ) = $filePath->values( $jsonText );  # Force array context
        my $file = Files->new( name => $fileId );
        $files{ $fileId } = $file;
        $file->parse( $fileObj );
    }        
}
else{
    print "FILES undefined\n";
}



# -------------------------< DBs >--------------------------------
if( defined( $dbs ) ){
    print "\nDbsPath: $dbsPath\n";
    print "\t", join( ",\n\t", sort keys( %{ $dbs } ) ), "\n";
    foreach my $dbId ( sort keys( %{ $dbs } ) ){
        print "\n$dbsPath.$dbId\n";
        my $dbPath = JSON::Path->new( "$dbsPath.$dbId" );
        my ( $dbObj ) = $dbPath->values( $jsonText );  # Force array context
        my $db = Dbs->new( name => $dbId );
        $dbs{ $dbId } = $db;
        $db->parse( $dbObj );
    }        
}
else{
    print "DBS undefined\n";
}


# -------------------------< PVs >--------------------------------
if( defined( $pvs ) ){
    print "\nPvsPath: $pvsPath\n";
    print "\t", join( ",\n\t", sort keys( %{ $pvs } ) ), "\n";
    foreach my $pvId ( sort keys( %{ $pvs } ) ){
        # $pvId = "'$pvId'";
        $pvId =~ s/:/&#58;/g;
        print "\n$pvsPath.$pvId\n";
        my $pvPath = JSON::Path->new( "$pvsPath.$pvId" );
        my ( $pvObj ) = $pvPath->values( $jsonText );  # Force array context
        my $pv = Pvs->new( name => $pvId );
        $pvs{ $pvId } = $pv;
        $pv->parse( $pvObj );
    }        
}
else{
    print "PVS undefined\n";
}

#--------------------------------------------------------------------------
#    All JSON data processed and parsed
#--------------------------------------------------------------------------
    print "\n---------------------------------------------------------------\n";
    print "All JSON data processed and parsed\n";
    print "---------------------------------------------------------------\n\n";



# -------------------------< Metrics >--------------------------------
#   We read the Metrics data last, so we can verify references to 
#   other parameter types (brokers, sinks, etc) in the Metrics parameters.
#
if( defined( $metrics ) ){
    print "\nMetricsPath: $metricsPath\n";
    print "\t", join( ",\n\t", sort keys( %{ $metrics } ) ), "\n";

    #
    #   Translate JSON Metrics Paths to Perl Object Database.
    #   Iterate over found JSON Paths
    #
    foreach my $metricId ( sort keys( %{ $metrics } ) ){
        print "\n$metricsPath.$metricId\n";
        my $metricPath = JSON::Path->new( "$metricsPath.$metricId" );
        my ( $metricObj ) = $metricPath->values( $jsonText );  # Force array context
        # hashDump( $metricObj );
        my $metric = Metrics->new( name => $metricId );
        $metrics{ $metricId } = $metric;
        $metric->parse( $metricObj );
    }


    foreach my $metricId ( sort keys %metrics ){
        my $metric = $metrics{ $metricId };

        #
        #   Validate Sinks
        #   
        my $sinks = $metric->param( 'sink' );
        if( !defined( $sinks ) ){
            die "No sinks for metric '$metricId' ";
        }
        else{
            print "Sinks for $metricId: $sinks\n";
            foreach my $sink ( @{ $sinks } ){
                my ( $sinkType ) = keys %{ $sink };
                my $sinkValue = $sink->{ $sinkType };
                print "Type: $sinkType, Value: $sinkValue\n";

                if( lc( $sinkType)  eq 'file' ){
                    if( !defined( $files{ $sinkValue } ) ){
                        print "Error: No 'file' sink named $sinkValue was defined\n";
                    }
                    else{
                        hashDump( $files{ $sinkValue }, $metricId, "/", $sinkType );
                    }
                }
                elsif( lc( $sinkType)  eq 'db' ){
                    if( !defined( $dbs{ $sinkValue } ) ){
                        print "Error: No 'db' sink named $sinkValue was defined\n";
                    }
                    else{
                        hashDump( $dbs{ $sinkValue }, $metricId, "/", $sinkType );
                    }
                }
                elsif( lc( $sinkType ) eq 'pv' ){
                    if( !defined( $pvs{ $sinkValue } ) ){
                        print "Error: No 'pv' sink named $sinkValue was defined\n";
                    }
                    else{
                        hashDump( $pvs{ $sinkValue }, $metricId,"/", $sinkType );
                    }
                }
                print "========\n";
            }
        }

        #
        #   Validate Brokers
        #
        my $metricBrokerId = $metric->param( 'broker' );
        if( !defined( $metricBrokerId ) ){
            die "No brokers for metric '$metricId' ";
        }
        else{
            #
            #   Only one broker to be used for each Metric
            #
            print "Broker: $metricBrokerId\n";
            if( !defined( $brokers{ $metricBrokerId } ) ){
                die "Broker '$metricBrokerId' not defined\n";
            }
            else{
                hashDump( $brokers{ $metricBrokerId }, "$metricId broker: " );
            }
        }

        #
        #   Test access to runtime Object database. Use Object/Classs methods to access
        #   instance data, just like the state of a MQTT subscription callback, or an 
        #   EPICS PV subscription event. We just don't have to have a live subscription to
        #   do these tests...
        #
        $metric->metricExternals();
    }
}
else{
    print "METRICS undefined\n";
}



exit(0);



sub preprocessJson {
my $jsonData = shift;
my @jsonText = @{ $jsonData };

    #
    #   the JSON standard doesn't provide for comments, so we 
    #   delete any embedded comment lines before feeding it to 
    #   Perl packages that read JSON data.
    #
    my $jsonLines = scalar @jsonText;
    for( my $i = 0, my $j = 0; $i < $jsonLines; $i++ ){

        #
        #   Remove comment lines
        #
        if( $jsonText[ $i ] =~ m/^\s*#/ ){
            print( "Removing line " ,$i+$j, "$jsonText[$i]" );
            splice( @jsonText, $i, 1 );
            $jsonLines--;
            $i--;
            $j++;
        }

        #
        #   Check for prescence of an 'include' directive (FIXME: Must be a single text line)
        #
        elsif( $jsonText[ $i ] =~ m/\"include"\s*:\s*{\s*"file"\s*:\s*"([^"]+)".*}/ ){
            #                        "include" : { "file" : "/home/bomr/data/pvs.json" },
            my $includeFile = $1;
            if( -e $includeFile ){
                print "Found include file specifier : $includeFile at line ", 1+$i+$j, "\n";

                open( INCLUDE, $includeFile ) || die "Cannot read include file : $includeFile : $!\n";
                my @includeFile = <INCLUDE>;
                close( INCLUDE );

                #
                #   Sigh... So much hassle to fix comma syntax in JSON.
                chomp $includeFile[-1];
                $includeFile[-1] .= "\n";
                if( $i < $jsonLines && $includeFile[-1] =~ m/[^,]\s*\n$/ ){
                    # print "Adding trailing comma\n";
                    push @includeFile, ",\n";
                }

                splice( @jsonText, $i, 1, @includeFile );

                # Recalculate array sizes and indices
                $jsonLines = scalar @jsonText;
                $j--;
                $i--;       # repeat inspection of the first inserted line
            }
            else{
                die "Include file '$includeFile' not found\n";
            }
        }

        #
        #   HTML-ize JSON Object names that have embedded colons
        #
        elsif( $jsonText[ $i ] =~ m/("[^"]+:[^"]+")\s*:/ ){
            my $pvName = $1;
            # print "$& ==> $pvName\n";
            $pvName =~ s/:/&#58;/g;
            $jsonText[ $i ] =~ s/("[^"]+:[^"]+")/$pvName/g;
        }
    }

    # Convert the array data to a string 
    my $jsonText = join( "", @jsonText );

    return( $jsonText );
}


sub hashDump{
my $hashRef = shift;

my $header = "";
    if( @_ ){
        $header = shift;    
    }
    foreach my $key ( sort keys %{ $hashRef } ){
        print "$header $key : ",$hashRef->{ $key },"\n";
    }
}
    
    
1;

package Brokers;

use parent 'TopLevel';

1;

package Files;

use parent 'TopLevel';

1;

package Dbs;

use parent 'TopLevel';

1;

package Pvs;

use parent 'TopLevel';

sub new {
my $proto = shift;
my $class = ref( $proto ) || $proto;
my $self = {};

    bless $self, $class;

    my %params = @_;

    #
    # Un-HTML-ize parameter name that may contain colons (illegal JSON value)
    #
    # print "Unescaping PV name $params{ name }\n";
    $params{ name } =~ s/&#58;/:/g;
    $self->parse( \%params );
    return $self;   
}


1;

