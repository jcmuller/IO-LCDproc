use 5.008001;

our $VERSION = '0.034';
package IO::LCDproc;

###############################################################################
package IO::LCDproc::Client;
@IO::LCDproc::Client::ISA = qw(IO::LCDproc);

use Carp;
use Fcntl;
use IO::Socket::INET;

sub new {
	my $proto 		= shift;
	my $class 		= ref($proto) || $proto;
	my %params	 	= @_;
	croak "No name for Client: $!" unless($params{name});
	my $self  		= {};
	$self->{name} 	= $params{name};
	$self->{host}	= $params{host} || "localhost";
	$self->{port}	= $params{port} || "13666";
	$self->{cmd}	= "client_set name {$self->{name}}\n";
	$self->{screen}	= undef;
   bless ($self, $class);
   return $self;
}

sub add {
	my $self = shift;
	$self->{screen} = shift;
	$self->{screen}{client} = $self;
	$self->{screen}{set} = "screen_set $self->{screen}{name} name {$self->{screen}{name}}\n";
	$self->{screen}{set}.= "screen_set $self->{screen}{name} heartbeat $self->{screen}{heartbeat}\n";
}

sub connect {
	my $self = shift;
	$self->{lcd}	= IO::Socket::INET->new(
		Proto => "tcp", PeerAddr => "$self->{host}", PeerPort => "$self->{port}"
	) or croak "Cannot connect to LCDproc port: $!";
	$self->{lcd}->autoflush();
	sleep 1;
}

sub initialize {
	my $self = shift;
	my $fh = $self->{lcd};
	my $msgs;
	print $fh "hello\n";
	$msgs = <$fh>;
	if($msgs =~ /lcd.+wid\s+(\d+)\s+hgt\s+(\d+)/){
		$self->{width}  = $1;
		$self->{height} = $2;
	} else {
		croak "No stats reported...: $!";
	}
	fcntl( $fh, F_SETFL, O_NONBLOCK );

	print $fh $self->{cmd};
	print $fh $self->{screen}{cmd};
	print $fh $self->{screen}{set};
	foreach(@{$self->{screen}{widgets}}){
		print $fh $_->{cmd};
	}
}

sub flush {
	my $class = shift;
	my $fh = $self->{lcd};
	my $msgs = <$fh>;
	return $self;
}

sub close {
	my $self = shift;
	my $sock = $self->{lcd};
	$sock->close();
}
	
###############################################################################
package IO::LCDproc::Screen;
@IO::LCDproc::Screen::ISA = qw(IO::LCDproc);

use Carp;

sub new {
	my $proto			= shift;
	my $class			= ref($proto) || $proto;
	my %params			= @_;
	croak "No name for Screen: $!" unless($params{name});
	my $self				= {};
	$self->{name}		= $params{name};
	$self->{heartbeat}= $params{heartbeat} || "on";
	$self->{cmd}		= "screen_add $self->{name}\n";
	$self->{widgets}	= undef;
	bless ($self, $class);
	return $self;
}

sub add {
	my $self = shift;
	foreach (@_){
		push @{$self->{widgets}}, $_;
		$_->{screen}=$self;
		$_->{cmd} = "widget_add $_->{screen}{name} $_->{name} $_->{type}\n";
	}
}

###############################################################################
package IO::LCDproc::Widget;
@IO::LCDproc::Client::ISA = qw(IO::LCDproc);

use Carp;
use overload '++' => \&xIncrement;

sub new {
	my $proto		= shift;
	my $class		= ref($proto) || $proto;
	my %params		= @_;
	croak "No name for Widget: $!" unless($params{name});
	my $self		= {};
	$self->{name}	= $params{name};
	$self->{align}	= $params{align} || "left";
	$self->{type}	= $params{type}  || "string";
	$self->{xPos}	= $params{xPos}  || "";
	$self->{yPos}	= $params{yPos}  || "";
	$self->{data}	= $params{data} if( $params{data} );
	bless ($self, $class);
	return $self;
}

sub set {
	my $self = shift;
	my %params = @_;
	$self->{xPos} = $params{xPos} if($params{xPos});
	$self->{yPos} = $params{yPos} if($params{yPos});
	$self->{data} = $params{data} if($params{data});
	$self->{data} = " " x $self->{screen}{client}{width} if(length( $self->{data} ) < 1 );
	my $fh = $self->{screen}{client}{lcd};
	print $fh "widget_set $self->{screen}{name} $self->{name} $self->{xPos} $self->{yPos} {" .
		($self->{align} =~ /center/ ? $self->_center($self->{data}) :
			($self->{align} =~ /right/ ? $self->_right($self->{data}) : $self->{data})
		) . "}\n";
}

sub _center {
	my $self = shift;
	return(" " x (($self->{screen}{client}{width} - length($_[0]))/2) . $_[0]);
}

sub _right {
	my $self = shift;
	return(" " x (($self->{screen}{client}{width} - length($_[0]))) . $_[0]);
}

sub save {
	my $self = shift;
	$self->{saved} = $self->{data};
}

sub restore {
	my $self = shift;
	$self->{data}  = $self->{saved};
	$self->{saved} = "";
	$self->set;
}

sub xIncrement {
	my $self = shift;
	$self->{xPos}++
}

1;

__END__

=head1 NAME

IO::LCDproc - Perl extension to connect to an LCDproc ready display.

=head1 SYNOPSIS

	use IO::LCDproc;

	my $client	= IO::LCDproc::Client->new(name => "MYNAME");
	my $screen	= IO::LCDproc::Screen->new(name => "screen");
	my $title 	= IO::LCDproc::Widget->new(
			name => "date", type => "title"
			);
	my $first	= IO::LCDproc::Widget->new(
			name => "first", align => "center", xPos => 1, yPos => 2
			);
	my $second	= IO::LCDproc::Widget->new(
			name => "second", align => "center", xPos => 1, yPos => 3
			);
	my $third	= IO::LCDproc::Widget->new(
			name => "third", xPos => 1, yPos => 4
			);
	$client->add( $screen );
	$screen->add( $title, $first, $second, $third );
	$client->connect() or die "cannot connect: $!";
	$client->initialize();

	$title->set( data => "This is the title" );
	$first->set( data => "First Line" );
	$second->set( data => "Second line" );
	$third->set( data => "Third Line" );

=head1 DESCRIPTION

Follow the example above. Pretty straight forward. You create a client, assign a screen,
add widgets, and then set the widgets.

=head2 IO::LCDproc::Client

It is the back engine of the module. It generates the connection to a ready listening server.

=head3 METHODS

=item new( name => 'Client_Name' [, host => $MYHOSTNAME] [, port => $MYPORTNUMBER] )

	Constructor. Takes the following possible arguments (arguments must be given in key => value form):
	host, port, and name. name is required.


=item add( I<SCREENREF> )

	Adds the screens that will be attached to this client.

=item connect()

	Establishes connection to LCDproc server (LCDd).

=item initialize()

	Initializes client, screen and all the widgets  with the server.

=head2 IO::LCDproc::Screen

=head3 METHODS

=item new( name => 'MYNAME')

	Constructor. Allowed options:
	heartbeat => 1 or 0.

=item add( @WIDGETS )

	Adds the given widgets to this screen.

=head2 IO::LCDproc::Widget

=head3 METHODS

=item new( name => 'MYNAME' )

	Constructor. Allowed arguments:
	align (left, center, rigth), type (string, title, vbar, hbar, ...), xPos, yPos, data

=item set()

   Sets the widget to the spec'd args. They may be given on the function call or the may be
   pre specified.
   xPos, yPos, data

=item save()

	Saves current data to be used later.

=item restore()

	Restore previously saved data. (Implicitly calls set)

=head1 SEE ALSO

L<LCDd>

=head1 AUTHOR

Juan C. Muller, E<lt>jcmuller@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Juan C. Muller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
