#! /usr/bin/perl -w

use strict;

use lib ".";

use JSON::Path;
use Data::Dumper;


#  Grab a whole file as specified on commandline
#
open( JSON_CFG, $ARGV[0] ) || die "Cannot read $ARGV[0] : $!\n";
my @jsonText = <JSON_CFG>;
my $jsonLines = scalar @jsonText;
close( JSON_CFG );

#
#   the JSON standard doens't provide for comments, so we 
#   delete any embedded comment lines before feeding it to 
#   Perl packages that read JSON data.
#
for( my $i = 0, my $j = 0; $i < $jsonLines; $i++ ){
    if( $jsonText[ $i ] =~ m/^\s*#/ ){
        print( "Removing line " ,$i+$j, "$jsonText[$i]" );
        splice( @jsonText, $i, 1 );
        $jsonLines--;
        $i--;
        $j++;
    }
}

# Convert the array data to a string 
my $jsonText = join( "", @jsonText );

# Create a JSON Parser and feed it the JSON string data
# my $json = new JSON::XS;
# my $jsonData = $json->decode( $jsonText );

# Display the structured result of the parsed JSON string data.
# print Dumper( $jsonData );

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
my %metrics = ();
my %brokers = ();
my %files = ();
my %dbs = ();
my %stores = ();
my %pvs = ();

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

    # -------------------------< Metrics >--------------------------------
    #   We read the Metrics data last, so we can verify references 
    #   to other parameter types (brokers, stores) in the Metrics parameters.
    #
    if( defined( $metrics ) ){
        print "\nMetricsPath: $metricsPath\n";
        print "\t", join( ",\n\t", sort keys( %{ $metrics } ) ), "\n";
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
            #   Validate Stores
            #   
            my $metricStores = $metric->param( 'store' );
            if( !defined( $metricStores ) ){
                die "No stores for metric '$metricId' ";
            }
            else{
                print "Stores for $metricId: $metricStores\n";
                foreach my $metricStore ( @{ $metricStores } ){
                    my ( $storeType ) = keys %{ $metricStore };
                    my $storeValue = $metricStore->{ $storeType };
                    print "Type: $storeType, Value: $storeValue\n";

                    if( lc( $storeType)  eq 'file' ){
                        if( !defined( $files{ $storeValue } ) ){
                            print "Error: No 'file' store named $storeValue was defined\n";
                        }
                        else{
                            hashDump( $dbs{ $storeValue }, $metricId, "/", $storeType );
                        }
                    }
                    elsif( lc( $storeType)  eq 'db' ){
                        if( !defined( $dbs{ $storeValue } ) ){
                            print "Error: No 'db' store named $storeValue was defined\n";
                        }
                        else{
                            hashDump( $dbs{ $storeValue }, $metricId, "/", $storeType );
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
        }
    }
    else{
        print "METRICS undefined\n";
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


package Metrics;

use parent 'TopLevel';

# sub new {
# my $proto = shift;
# my $class = ref( $proto ) || $proto;
# my $self = {};

#     bless $self, $class;

#     my %params = @_;
#     $self->parse( \%params );
#     return $self;   
# }

sub parse{
my $self = shift;
my $jsonObj = shift;

    foreach my $key ( keys %{ $jsonObj } ){
        my $value = $jsonObj->{ $key };
        if( ! ref( $value ) ){
            print "Key => $key, Value=> $value\n";
            $self->{ $key } = $value;
        }
        else{
            if( ref( $value ) =~ m/^ARRAY/ ){
                # print "$key is ARRAYref Type\n";
                print "$key ARRAY: ", join( " | ", @{ $value } ), "\n";
                $self->{ $key } = $value;
            }
            elsif( ref( $value ) =~ m/HASH/ ){
                # print "$key is HASHref Type\n";
                $self->{ $key } = $value;
            }
        }
    }
    return( $self );
}

sub param{
my $self = shift;
my $paramId = shift;

    if( @_ ){
        $self->${$paramId} = shift;
    }
    else{
        if( exists( $self->{$paramId} ) ){
            return( $self->{$paramId} );
        }
        else{
            return undef;
        }
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

1;

