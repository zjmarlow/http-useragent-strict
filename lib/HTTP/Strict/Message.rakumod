unit class HTTP::Strict::Message;

use HTTP::Strict;
use HTTP::Strict::Header::Field;
use HTTP::Strict::Header;
use HTTP::MediaType;
use Encode;

has Int:D $.MAX-SIZE is rw = 300;

has HTTP::Strict::Header $.header = HTTP::Strict::Header.new;
has $.content is rw = '';

has $.protocol is rw = 'HTTP/1.1';

has Bool $.binary = False;
has Str  @.text-types;

multi method new ( $content, *%fields ) {
	my $header = HTTP::Strict::Header.new: |%fields;

	self.bless: :$header, :$content;
}

multi method new ( *%fields ) {
	my $header = HTTP::Strict::Header.new: |%fields;

	self.bless: :$header;
}

method add-content ( $content ) {
	$!content = join '', $!content, $content;
}

class X::Decoding is Exception {
	has HTTP::Strict::Message $.response;
	has Blob $.content;
	method message {
		"Problem decoding content";
	}
}

method content-type ( --> Str:D ) {
	$!header.field( 'Content-Type' ).values[0] || '';
}

has HTTP::MediaType $!media-type;

method media-type ( --> HTTP::MediaType ) {
	without $!media-type { 
		if self.content-type -> $ct {
			$!media-type = HTTP::MediaType.parse: $ct;
		}
	}
	$!media-type
}

# Don't want to put the heuristic in the HTTP::MediaType
# Also moving this here makes it much more easy to test

method charset ( --> Str:D ) {
	if self.media-type -> $mt {
		$mt.charset or $mt.major-type eq 'text' ?? $mt.sub-type eq 'html' ?? 'utf-8' !! 'iso-8859-1' !! 'utf-8';
	} else {
		# At this point we're probably screwed anyway
		'iso-8859-1'
	}
}

# This is already a candidate for refactoring
# Just want to get it working
method is-text ( --> Bool:D ) {
	if $!binary {
		False
	} elsif self.media-type -> $mt {
		if $mt.type ~~ any(@!text-types) {
			True
		} else {
			given $mt.major-type {
				when 'text' {
					True
				}
				when <image audio video>.any {
					False
				}
				when 'application' {
					given $mt.sub-type {
						when / xml | javascript | json / {
							True
						}
						default {
							False
						}
					}
				}
				default {
					# Not sure about this
					True
				}
			}
		}
	} else {
		# No content type, try and blow up
		True
	}
}

method is-binary(--> Bool:D) { !self.is-text }

#| multiple transfer-codings can be listed; chunked should be last
#| https://datatracker.ietf.org/doc/html/rfc2616#section-14.41
#| https://datatracker.ietf.org/doc/html/rfc7230#section-4
multi method is-chunked ( HTTP::Strict::Header:D $header --> Bool:D ) {
	my $enc = $header.field: 'Transfer-Encoding';
	so $enc and $enc.values.tail.trim.lc.ends-with: 'chunked'
}
multi method is-chunked ( --> Bool:D ) {
	self.is-chunked: $!header;
}

method content-encoding {
	$!header.field: 'Content-Encoding';
}

class X::Deflate is Exception {
	has Str $.message;
}

method inflate-content ( --> Blob:D ) {
	if self.content-encoding -> $v is copy {
		# This is a guess
		$v = 'zlib' if $v eq 'compress' ;
		$v = 'zlib' if $v eq 'deflate';
		try require ::( 'Compress::Zlib' );
		if ::( 'Compress::Zlib::Stream' ) ~~ Failure {
			.throw with X::Deflate.new:
					message =>
						"Please install 'Compress::Zlib' to uncompress '$v' encoded content";
		} else {
			my $z = ::( 'Compress::Zlib::Stream' ).new: $v => True;
			$z.inflate: $!content;
		}
	} else {
		$!content;
	}
}

method decoded-content ( Bool :$bin ) {
	return $!content if $!content ~~ Str || $!content.bytes == 0;

	my $content = self.inflate-content;
	# [todo]
	# If charset is missing from Content-Type, then before defaulting
	# to anything it should attempt to extract it from $!content like (for HTML):
	# <meta charset="UTF-8"> 
	# <meta http-equiv="content-type" content="text/html; charset=UTF-8">
	
	my $decoded_content;

	if !$bin && self.is-text {
		my $charset = self.charset;
		$decoded_content = try {
			Encode::decode($charset, $content);
		} || try {
			$content.decode('iso-8859-1');
		} || try { 
			$content.unpack("A*") 
		} || X::Decoding.new(content => $content, response => self).throw;
	} else {
		$decoded_content = $content;
	}

	$decoded_content
}

multi method field ( Str $f ) {
	$!header.field: $f;
}

multi method field ( *%fields ) {
	$!header.field: |%fields;
}

method push-field ( *%fields ) {
	$!header.push-field: |%fields;
}

method remove-field ( Str $field ) {
	$!header.remove-field: $field;
}

method clear {
	$!header.clear;
	$!content = ''
}

# parsing content with embedded CRLFs NYI
#   it would require taking encoding into account and working with Blobs
method !parse-content-strict ( $content ) {
	if self.is-chunked {
		# technically incorrect - content allowed to contain embedded CRLFs
		my @lines = $content.split: $CRLF;
		# pop zero-length Str that occurs after last chunk
		#   what to do if this doesn't happen?
		@lines.pop if @lines %2;
		@lines = grep so *,
					@lines.map:
							-> $d, $s { $d ~~ /^<[0..9a..fA..F]>/ ?? $s !! Str }
				;
		$!content = @lines.join;
	} else {
		$!content = $content;
	}
}

method !parse-first ( $raw_message, --> Str ) {
	my ( $start-line, $rest ) = $raw_message.split: $CRLF, 2;
	my ( $first, $second, $third ) = $start-line.split: /\s+/;
	if $third.index: '/' { # is a request
		$!protocol = $third;
	} else {			   # is a response
		$!protocol = $first;
	}
	$rest;
}

method !parse-header ( $header ) {
	$!header.parse: $header;
}

method parse ( $raw-message ) {
	my $rest = self!parse-first: $raw-message;
	my ( $header, $content ) = $rest.split: $DELIM, 2;
	$!header.parse: $header;
	self!parse-content-strict: $content if $content;
	self
}

method Str ( :$debug, Bool :$bin ) {
	# only update Content-Length, don't add it
	self.field: Content-Length => ( $!content.?encode or $!content ).bytes.Str
		if self.field: 'Content-Length';
	my $s = $!header.Str;
	# add Content-Length to output if needed but don't add it to the Message
	if $!content and not self.is-chunked and not self.field: 'Content-Length' {
		# self.field: Content-Length => ( $!content.?encode or $!content ).bytes.Str;
		$s = join '', $s, .Str, $CRLF
			with HTTP::Strict::Header::Field.new:
					name => 'Content-Length',
					values =>  [ ( $!content.?encode or $!content ).bytes.Str ];
	}
	
	# The :bin will be passed from the H::UA
	if not $bin {
		$s = join $CRLF, $s, $!content || '';
	}
	if $!content and $debug {
		if $bin || self.is-binary {
			$s ~= $CRLF ~ "=Content size : " ~ $!content.elems ~ " bytes ";
			$s ~= "$CRLF ** Not showing binary content ** $CRLF";
		} else {
			$s ~= $CRLF ~ "=Content size: "~$!content.Str.chars~" chars";
			$s ~= "- Displaying only $!MAX-SIZE" if $!content.Str.chars > $!MAX-SIZE;
			$s ~= $CRLF ~ $!content.Str.substr( 0, $!MAX-SIZE ) ~ $CRLF;
		}
	}
	
	$s
}