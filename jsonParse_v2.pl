#! /usr/bin/perl -w

use strict;

use lib ".";

use JSON::Path;

# use Data::Dumper;

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
our %metrics = ();
our %brokers = ();
our %files = ();
our %dbs = ();
our %stores = ();
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
            my $stores = $metric->param( 'store' );
            if( !defined( $stores ) ){
                die "No stores for metric '$metricId' ";
            }
            else{
                print "Stores for $metricId: $stores\n";
                foreach my $store ( @{ $stores } ){
                    my ( $storeType ) = keys %{ $store };
                    my $storeValue = $store->{ $storeType };
                    print "Type: $storeType, Value: $storeValue\n";

                    if( lc( $storeType)  eq 'file' ){
                        if( !defined( $files{ $storeValue } ) ){
                            print "Error: No 'file' store named $storeValue was defined\n";
                        }
                        else{
                            hashDump( $files{ $storeValue }, $metricId, "/", $storeType );
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
            $metric->metricExternals();
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
use File::Path qw(make_path);

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

sub metricExternals {
my $self = shift;

    #
    # Find all brokers & stores for this metric. 
    #
    #   For File stores, create any potentially needed directory tree
    #
    #   PROBLEM: The metric contains a referernce to a 'Store' hash. 
    #   The key to the Store hash is the StoreId, but the Stores in the hash are NOT 
    #   part of the Metric Object instance data, and are in a separate Class.
    #   We need to get access to the specified 'File', 'Db' & 'Pv' Class objects.
    #   We took care to create lookup hashes when the JSON dat was being parsed,
    #   but the lookup hashes are in the main:: class/namespace.
    #
    #   Do we want to pollute the Metrics Class by referencing the main::Lookups hashes directly,
    #   or should we pull some references to the lookups into the Metrics instance dataset?
    #

    print "\n\n--------------- metricExternals( $self->{ name } ) ----------------\n";
    #
    #   Validate Brokers
    #
    my $brokerId = $self->param( 'broker' );
    if( !defined( $brokerId ) ){
        die "No brokers for metric '$self->{ name }' ";
    }
    else{
        #
        #   Only one broker to be used for each Metric
        #
        print "Broker: $brokerId\n";
        if( !defined( $main::brokers{ $brokerId } ) ){
            die "Broker '$brokerId' not defined\n";
        }
        else{
            main::hashDump( $main::brokers{ $brokerId }, "\t$self->{ name } broker: " );
        }
    }

    my $stores = $self->param( 'store' );
    if( !defined( $stores ) ){
        die "No stores for metric '$self->{name}' ";
    }
    else{
        print "\nStores found for '$self->{name}'\n";
        foreach my $store ( @{ $stores } ){
            my ( $storeType ) = keys %{ $store };
            my $storeValue = $store->{ $storeType };
            print "Type: $storeType, Value: $storeValue\n";

            if( lc( $storeType)  eq 'file' ){

                #
                #   The store is a 'File' object, and the storeValue is the FileId
                #   to use in a lookup.
                #
                if( !defined( $main::files{ $storeValue } ) ){  # The 'Files' lookup is in main:: namespace...
                    print "Error: No 'file' store named $storeValue was defined\n";
                }
                else{
                    main::hashDump( $main::files{ $storeValue }, "\t".$self->{ name }."/".$storeType );
                    my $fileDir  = $main::files{ $storeValue }->{ directory };
                    my $fileName = $main::files{ $storeValue }->{ basename };
                    print "\t$self->{ name } Store[ File ]: $fileDir/$fileName\n";

                    if( ! -d $fileDir ){
                        print "\tCreating $fileDir\n";
                        make_path( $fileDir, { mode => 0775 } );
                    }
                    else{
                        print "\tDirectory exists\n";
                    }
                }
            }
            elsif( lc( $storeType)  eq 'db' ){
                if( !defined( $main::dbs{ $storeValue } ) ){
                    print "Error: No 'db' store named $storeValue was defined\n";
                }
                else{
                    main::hashDump( $main::dbs{ $storeValue }, "\t".$self->{ name }. "/". $storeType );
                }
            }
            print "========\n";
        }
    }
    print "------------- End metricExternals( $self->{ name } ) --------------\n\n";


}


#
#   Establish a connection to the specified MQTT Broker, and then
#   build a subscription to the specified topic on the connected broker.
#
sub mqttClientInit {
my $self = shift;
my $broker = shift;
    # my  %thisBroker = %{ $broker };
    if( $main::verbose ){
        print "Launch MQTT Broker: name:", $broker->property( 'name' );
        print ", ip: ",   $broker->property( 'ip' );
        print ", port: ", $broker->property( 'port' ),"\n";
        print "All broker properties: ", join( ", ", $broker->properties() ),"\n";
    }

    my $brokerIp = $broker->property( 'ip' ).":";
    $brokerIp   .= $broker->property( 'port' );
    #
    #   Connect to the specified broker.
    #
    if( $main::verbose ){
        print "Broker IP:port (Metrics) ", $brokerIp,"\n";
    }

    my $mqttClient = Net::MQTT::Simple->new( $brokerIp );
    if( $mqttClient ){
        print "MQTT Broker $brokerIp connection Okay\n"
    }
    else{ 
        die "Could not open MQTT Connection\n";
    }

    #
    #   If there are any logfiles or db's to resolve for this metric,
    #   do it here to reduce overhead in the callback..
    #
    my @stores = @{ $self->{ stores } };  # Stores are treated as a special type of property of a metric

    print "\thandler: ", $self->{ name }, ", (", scalar @stores, ") ", join( ", ", @stores), ", ", "\n";
    while( @stores ){
        my ( $storeType, $storeId ) = @stores;
        print "Store Type: $storeType, Store Name: $storeId\n";
        shift @stores;
        shift @stores;
        if( $storeType eq 'file' ){

            #
            #   StoreId is not a filename; it's a reference to a 'file' top-level type.
            #   We need to lookup the specified file Object. The lookup for that lives 
            #   in the main:: namespace...
            #
            if( %main::fileObjs ){
                print "Main File Lookup: ", join( ", ", sort keys( %main::fileObjs ) ),"\n";
            }
            else{
                print "Cannot access Main File Lookup '\%main::fileObjs'\n";
                die;
            }

            my $fileObj = $main::fileObjs{ $storeId };
            if( !defined( $fileObj ) ){
                die "Cannot lookup file ID $storeId: not defined \n";
            }
            else{

                print "File Obj Metadata: ", join( ", ", sort keys %{ $fileObj } ), "\n";
                my( $sec, $min, $hr, $mon, $day, $year, $dow, $xx, $xxx ) = localtime( time );
                $year+= 1900;
                my $timeDateStamp = sprintf( "%04d-%02d-%02dT%02d_%02d_%02d", 
                                           $year, $mon, $day, $hr, $min, $sec );
                # my $timeDateStamp = scalar localtime( time );
                # $timeDateStamp =~ s/\s/_/g;
                my $fileSpec = $fileObj->property( 'directory') . "/" .
                            $timeDateStamp . "_" .
                            $fileObj->property( 'basename' ) . ".log";
                print "Filespec: $fileSpec\n";
                push @{ $self->{ 'logfiles' } }, $fileSpec;
            }
        }
        elsif( $storeType eq 'db' ){
            print "Store Type 'db' not implemented\n";
        }
    }

    #
    #   Create a subscription on the already connected broker,
    #   to the specified topic. The callback will be invoked
    #   on each new data event.
    #
    if( $main::verbose ){
        print "Subscribing to ", $self->{ 'topic' }, " on broker '$brokerIp'\n";
    }

    $mqttClient->subscribe( $self->{ 'topic' }, $self->{ 'CALLBACK' } );
    print "Subscription registered\n";

    # my $testTopic = "$0/$$"; 
    # $testTopic =~ s/^[.\/]*//;
    # $testTopic =~ s/\./_/g;
    # my $testMessage = '{"timedate":"' . scalar localtime( time ) . '"}';
    # print "Publish 'Alive' message: Topic: $testTopic, Message: $testMessage\n";
    # $mqttClient->publish( $testTopic => $testMessage );
    return( $mqttClient );

}

#
#  For this test case, the topic and message looks like this 
#           (newlines added to JSON for clarity):
#
#  tele/tasmota_F74C1D/SENSOR, {
#         "Time":"2025-05-26T11:58:51",
#         "DS18B20":{
#             "Id":"0000005CBBBA",
#             "Temperature":20.8
#         },
#         "TempUnit":"C"
#     }
#

sub handler($$$){
my $self = shift;
my $topic = shift;
my $message = shift;

    print "Begin MQTT Callback:\n";
    
    #
    #   FIXME: This needs to be looked up from the Object Data
    #
    my $storeType = 'file';

    my $xdata = $self->{ xdata };
    my $ydata = $self->{ ydata };
    my $ydataPath = JSON::Path->new( $ydata );
    my $xdataPath = JSON::Path->new( $xdata );
    my $xdataVal;
    my $ydataVal;
    if( $xdata =~ m/^\$/ ){
        $xdataVal = $xdataPath->value( $message );
    }
    else{       # Use host localtime for Xdata 
        my( $sec, $min, $hr, $day, $mon, $year, $dow, $xx, $xxx ) = localtime( time );
        $year+= 1900;
        my $xdataVal = sprintf( "%04d-%02d-%02dT%02d_%02d_%02d", 
                               $year, $mon, $day, $hr, $min, $sec );
    }
    if( $ydata =~ m/^\$/ ){
        $ydataVal = $ydataPath->value( $message );
    }
    else{   # Assume the whole message is the data
        $xdataVal = $message;
    }
    
    #   FIXME:
    #   Here, we're allowed to store the same metric in multiple logfiles.
    #   We need to expand on this to allow multile *stores*.
    #
    if( $storeType eq 'file' ){
        foreach my $fileSpec ( @{ $self->{ logfiles } } ){
            print "Metric '", $self->{ name }, "' :: '$xdataVal' '$ydataVal' ==> $fileSpec\n";
            open( LOG, ">>$fileSpec" ) || die "Cannot open $fileSpec for writing: $!\n";
            # print( LOG "'$topic' : $message\n" );
            print( LOG "$xdataVal $ydataVal\n" );
            close( LOG );
        }
    }
    elsif( $storeType eq 'db' ){
        print "Store type 'DB' (not implemented)\n";
    }
 
    print "END MQTT Callback\n";
    return '';
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

