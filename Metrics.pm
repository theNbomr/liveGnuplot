
package Metrics;

use parent 'TopLevel';
use File::Path qw(make_path);

sub new {

my $proto = shift;
my $class = ref( $proto ) || $proto;
my $self = {};

    bless $self, $class;

    my %params = @_;
    foreach my $key ( keys %params ){
        my $value = $params{ $key };
        $self->{ $key } = $value;
        if($verbose ){
            print "Key: $key, Value: $value\n";
        }
    }

    $self->{ sinks } = ();
    $self->{ logfiles } = ();
    $self->{ dbs } = ();
    $self->{ pv } = ();

    # Create a curried version of the object methods
    # to use as a callbacks by non-object code
    # RN does not really understand HOW this works,
    # although I understand why it's needed.
    $self->{ CALLBACKMQ } = $self->curry( 'callbackMQ' );
    $self->{ CALLBACKSUBCA } = $self->curry( 'callbackSubCA' );
    $self->{ CALLBACKEVNTCA } = $self->curry( 'callbackEventCA' );
    return $self;
}

#
#   This is some dark-assed voodoo majick. 
#   It allows an arbitrary non-object non-instance code 
#   to make callbacks to the curried object method.
#   See the links in the comments at the top of this file.
#
sub curry { 
    my ( $self, $method_name, @args ) = @_;
    my $method = $self->can( $method_name ) || die "No $method_name method found";
    return sub { $self->$method( @args, @_ ) };
}

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

#
#   This subroutine is just testbed code that kind of emulates the 
#   state of a metric's callback context. It is being used to evaluate
#   how callback context code can access the Broker, File, Db, and Pv 
#   elements needed to service ther callback.
#
sub metricExternals {
my $self = shift;

    #
    # Find all brokers & sinks for this metric. 
    #
    #   For File sinks, create any potentially needed directory tree
    #
    #   PROBLEM: The metric contains a referernce to a 'Sink' hash. 
    #   The key to the Sink hash is the SinkId, but the Sinks in the hash are NOT 
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
            # main::hashDump( $main::brokers{ $brokerId }, "\t$self->{ name } broker: " );
        }
    }

    my $sinks = $self->param( 'sink' );
    if( !defined( $sinks ) ){
        die "No sinks for metric '$self->{name}' ";
    }
    else{
        print "\nSinks found for '$self->{name}'\n";
        foreach my $sink ( @{ $sinks } ){
            my ( $sinkType ) = keys %{ $sink };
            my $sinkValue = $sink->{ $sinkType };
            print "Type: $sinkType, Value: $sinkValue\n";

            if( lc( $sinkType)  eq 'file' ){

                #
                #   The sink is a 'File' object, and the sinkValue is the FileId
                #   to use in a lookup.
                #
                if( !defined( $main::files{ $sinkValue } ) ){  # The 'Files' lookup is in main:: namespace...
                    print "Error: No 'file' sink named $sinkValue was defined\n";
                }
                else{
                    # main::hashDump( $main::files{ $sinkValue }, "\t".$self->{ name }."/".$sinkType );
                    my $fileDir  = $main::files{ $sinkValue }->{ directory };
                    my $fileName = $main::files{ $sinkValue }->{ basename };
                    print "\t$self->{ name } Sink[ File ]: $fileDir/$fileName\n";

                    if( ! -d $fileDir ){
                        print "\tCreating $fileDir\n";
                        make_path( $fileDir, { mode => 0744 } );
                    }
                    else{
                        print "\tDirectory exists\n";
                    }
                }
            }
            elsif( lc( $sinkType ) eq 'db' ){
                if( !defined( $main::dbs{ $sinkValue } ) ){
                    print "Error: No 'db' sink named $sinkValue was defined\n";
                }
                else{
                    # main::hashDump( $main::dbs{ $sinkValue }, "\t".$self->{ name }. "/". $sinkType );
                }
            }
            elsif( lc( $sinkType ) eq 'pv' ){
                #
                #   Lookup the PV object, and get the PV name and optionally, EPICS_CA_parameters,
                #   Send a number to the EPICS PV
                #
                if( !defined( $main::pvs{ $sinkValue } ) ){
                    print "Error: No 'pv' sink named $sinkValue was defined\n";
                }
                else{
                    # main::hashDump( $main::dbs{ $sinkValue }, "\t".$self->{ name }. "/". $sinkType );
                    my $pvObj = $main::pvs{ $sinkValue };
                    my $pvName       = $pvObj->param( "name" );
                    my $serverPort   = $pvObj->param( "EPICS_CA_SERVER_PORT" );
                    my $repeaterPort = $pvObj->param( "EPICS_CA_REPEATER_PORT" );
                    print "caput( $pvName, 3.1415926, $serverPort, $repeaterPort )\n";
                    main::caput( $pvName, 3.1415926, $serverPort, $repeaterPort );
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
    my @sinks = @{ $self->{ sinks } };  # Sinks are treated as a special type of property of a metric

    print "\thandler: ", $self->{ name }, ", (", scalar @sinks, ") ", join( ", ", @sinks), ", ", "\n";
    while( @sinks ){
        my ( $sinkType, $sinkId ) = @sinks;
        print "Sink Type: $sinkType, Sink Name: $sinkId\n";
        shift @sinks;
        shift @sinks;
        if( $sinkType eq 'file' ){

            #
            #   SinkId is not a filename; it's a reference to a 'file' top-level type.
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

            my $fileObj = $main::fileObjs{ $sinkId };
            if( !defined( $fileObj ) ){
                die "Cannot lookup file ID $sinkId: not defined \n";
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
        elsif( $sinkType eq 'db' ){
            print "Sink Type 'db' not implemented\n";
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

sub callbackMQ($$$){
my $self = shift;
my $topic = shift;
my $message = shift;

    print "Begin MQTT Callback:\n";
    
    #
    #   FIXME: This needs to be looked up from the Object Data
    #
    my $sinkType = 'file';

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
    #   Here, we're allowed to sink the same metric in multiple logfiles.
    #   We need to expand on this to allow multile *sinks*.
    #
    if( $sinkType eq 'file' ){
        foreach my $fileSpec ( @{ $self->{ logfiles } } ){
            print "Metric '", $self->{ name }, "' :: '$xdataVal' '$ydataVal' ==> $fileSpec\n";
            open( LOG, ">>$fileSpec" ) || die "Cannot open $fileSpec for writing: $!\n";
            # print( LOG "'$topic' : $message\n" );
            print( LOG "$xdataVal $ydataVal\n" );
            close( LOG );
        }
    }
    elsif( $sinkType eq 'db' ){
        print "Sink type 'DB' (not implemented)\n";
    }
 
    print "END MQTT Callback\n";
    return '';
}

#
#   Channel Access subscription events will be handled here.
#   This callback then subscribes to CA events on the same CHID.
#
sub callbackSubCA {
my $self = shift;


    
}

sub callbackEventCA {
my $self = shift;


    
}




1;
