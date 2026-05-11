use HTTP::Strict;
use HTTP::Header::Field::Strict;
use HTTP::Header::Field::ETag::Strict;

unit class HTTP::Header::Strict;

has HTTP::Header::Field::Strict:D @.fields;

grammar Grammar {
	token TOP {
		<message-header>
	}
	token message-header {
		[ <[\t\x[20]]>* <field> <[\t\x[20]]>* \x[0d]\x[0a] ]*
	}
	#| includes any VCHAR except delimiters
	#| https://datatracker.ietf.org/doc/html/rfc9110#name-tokens
	token token {
		<[!#$%&'*+\-.^_`|~0..9a..zA..Z]>+
	}
	token field {
		| <etag>
		| <other-field>
	}
	token other-field {
		$<field-name>=<token> ':' \s* [ <value> | <quoted-string> ]
	}
	token etag {
		$<field-name>=[<[eE]><[tT]><[aA]><[gG]>] ':'\s* $<field-value>=[ [(W)'/']? <opaque-tag> ]
	}
	token opaque-tag {
		\" <opaque-content> \"
	}
	# visible chars except double quote
	token opaque-content {
		<[\x[21]..\x[FF]]-[\x[22]\x[7F]]>*
	}
	token vchars { <[\x[21]..\x[7E]]>+ } # visible ascii
	token field-vchars { <[\x[21]..\x[FF]]-[\x[7F]]>+ } # visible chars
	token value {
		<field-vchars> [ <[\t\x[20]]>* <field-vchars> ]*
	}
	token quoted-string {
		\" <quoted-content> \"
	}
	token quoted-content {
		[<qtd-text> | <quoted-pair>]*
	}
	# visible chars plus tab, space, except double quotes and backslash
	token qtd-text {
		<[\t\x[20]..\x[FF]]-[\x[22]\x[5C]\x[7F]]>+
	}
	# visible chars plus tab, space
	token quotable-char {
		<[\t\x[20]..\x[FF]]-[\x[7F]]>
	}
	token quoted-pair {
		\\ <quotable-char>
	}
}

class Actions {
	method etag ( $/ ) {
		$*OBJ.field:
				HTTP::Header::Field::ETag::Strict.new:
						$<opaque-tag>.made,
						weak => $/[0].Bool
	}
	method other-field ( $/ ) {
		my $k = $<field-name>.Str;
		my @v = $<quoted-string>
				?? $<quoted-string>.made
				!! map *.trim, $<value>.Str.split: ',';
		if $*OBJ.field: $<field-name> {
			$*OBJ.push-field: |( $k => @v );
		} else {
			$*OBJ.field: |( $k => @v );
		}
	}
	method opaque-tag ( $/ ) {
		make $<opaque-content>.Str;
	}
	method quoted-string ( $/ ) {
		make $<quoted-content>.Str;
	}
}

method new ( *%fields ) {
	my @fields = %fields.sort(*.key).map: {
		HTTP::Header::Field::Strict.new:
				name => .key,
				values => .values.list;
	}

	self.bless: :@fields;
}

proto method field(|) {*}

# set fields
multi method field(*%fields) {
	for %fields.sort(*.key) -> (:key($k), :value($v)) {
		my $f = HTTP::Header::Field::Strict.new(:name($k), :values($v.list));
		if @!fields.first({ .name.lc eq $k.lc }) {
			@!fields[@!fields.first({ .name.lc eq $k.lc }, :k)] = $f;
		}
		else {
			@!fields.push: $f;
		}
	}
}

# get fields
multi method field($field) {
	my $field-lc := $field.lc;
	@!fields.first(*.name.lc eq $field-lc)
}

multi method field ( HTTP::Header::Field::ETag::Strict:D $etag ) {
	if @!fields.first: *.name.lc eq $etag.name.lc {
		@!fields[ @!fields.first: *.name.lc eq $etag.name.lc ] = $etag;
	} else {
		@!fields.push: $etag;
	}
}


# initialize fields
method init-field(*%fields) {
	for %fields.sort(*.key) -> (:key($k), :value($v)) {
		my $k-lc := $k.lc;
		@!fields.push:
		  HTTP::Header::Field::Strict.new(:name($k), :values($v.list))
		  unless @!fields.first(*.name.lc eq $k-lc);
	}
}

# add value to existing fields
method push-field(*%fields) {
	for %fields.sort(*.key) -> (:key($k), :value($v)) {
		my $k-lc := $k.lc;
		@!fields.first(*.name.lc eq $k-lc).values.append: $v.list;
	}
}

# remove a field
method remove-field(Str $field) {
	my $field-lc := $field.lc;
	@!fields.splice($_, 1)
	  with @!fields.first(*.name.lc eq $field-lc, :k);
}

# get fields names
method header-field-names() {
	@!fields.map(*.name)
}

# return the headers as name -> value hash
method hash(--> Hash:D) {
	@!fields.map({ $_.name => $_.values }).Hash
}

# remove all fields
method clear() {
	@!fields = ();
}

# get header as string
multi method Str ( --> Str:D ) {
	join $CRLF, @!fields>>.Str, '';
}

method parse ( $raw ) {
	my $*OBJ = self;
	Grammar.parse: $raw, actions => Actions;
}
