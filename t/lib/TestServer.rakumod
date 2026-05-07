module TestServer {
	use HTTP::Strict::Request;
	sub test-full-message ( Promise $done-promise, Int :$port --> Promise:D ) is export {
		start {
			react {
				whenever $done-promise {
					done;
				}
				whenever IO::Socket::Async.listen: 'localhost', $port -> $conn {
					whenever $conn.Supply: :bin -> $buf {
						my HTTP::Strict::Request $r = HTTP::Strict::Request.new;
						$r.parse: $buf.decode;
						my ( $eol, $okl );
						$eol = $r.content.ends-with: "\x0d\x0a";
						$okl = $r.content.chars == .values.head.Int with $r.field: 'Content-Length';
						my $out-buf =
							Buf.new:
									'HTTP/1.1 200 OK'.comb>>.ord, 13, 10,
									'Content-Length: 3'.comb>>.ord, 13, 10,
									13, 10,
									( $eol ?? 'T'.ord !! 'F'.ord ), 13, ( $okl ?? 'T'.ord !! 'F'.ord );
						$conn.write: $out-buf;
						$conn.close;
					}
				}
			}
		}
	}
}

# vim: expandtab shiftwidth=4
