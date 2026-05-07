use HTTP::Strict;
use HTTP::Strict::Message;
use HTTP::Status;
use HTTP::Strict::Request;
use HTTP::Strict::UserAgent::Exception;

unit class HTTP::Strict::Response is HTTP::Strict::Message;

has $.status-line is rw;
has $.code is rw;
has HTTP::Strict::Request $.request is rw;

submethod BUILD ( :$!code ) {
	$!status-line = self.set-code: $!code;
}

proto method new(|) {*}

# This candidate makes it easier to test weird responses
multi method new ( Blob:D $header-chunk ) {
	# See https://tools.ietf.org/html/rfc7230#section-3.2.4
	my ( $rl, $header );
	( $rl, $header ) = $header-chunk.decode( 'ISO-8859-1' ).split: $CRLF, 2;
	X::HTTP::Strict::NoResponse.new.throw unless $rl;

	my $code = ( try $rl.split( ' ' )[1].Int ) // 500;
	my $response = self.new: $code;
	$response.header.parse: $header with $header;

	$response
}

multi method new ( Int:D $code = 200, *%fields ) {
	my $header = HTTP::Strict::Header.new: |%fields;
	self.bless: :$code, :$header;
}

method content-length ( --> Int ) {
	my $content-length = self.field('Content-Length').values[0];

	with $content-length -> $c {
		X::HTTP::Strict::ContentLength.new( message => "Content-Length header value '$c' is not numeric" ).throw
			without $content-length = try +$content-length;
		$content-length
	} else {
		Int
	}
}

method is-success { is-success $!code }

# please extend as necessary
method has-content ( --> Bool:D ) {
	( 204, 304 ).grep({ $!code eq $_ }) ?? False !! True;
}

method set-code ( Int:D $code ) {
	$!code = $code;
	$!status-line = join ' ', $code, get_http_status_msg $code;
}

method next-request ( --> HTTP::Strict::Request:D ) {
	my HTTP::Strict::Request $new-request;

	my $location = ~self.header.field('Location').values;


	if $location.defined {
		# Special case for the HTTP status code 303 (redirection):
		# The response to the request can be found under another URI using
		# a separate GET method. This relates to POST, PUT, DELETE and PATCH
		# methods.
		my $method = $!request.method;
		$method = "GET"
			if self.code == 303
			&& $!request.method eq <POST PUT DELETE PATCH>.any;

		my %args = $method => $location;

		$new-request = HTTP::Strict::Request.new: |%args;

		unless ~$new-request.field( 'Host' ).values {
			my $hh = ~$!request.field( 'Host' ).values;
			$new-request.field: Host => $hh;
			$new-request.scheme = $!request.scheme;
			$new-request.host   = $!request.host;
			$new-request.port   = $!request.port;
		}
	}

	$new-request
}

method Str ( :$debug ) {
	my $s = join ' ', $.protocol, $!status-line;
	join $CRLF, $s, callwith :$debug;
}
