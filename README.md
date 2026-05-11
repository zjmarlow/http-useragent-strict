NAME
====

HTTP::UserAgent::Strict - Web user agent class

SYNOPSIS
========

```raku
use HTTP::UserAgent::Strict;

my $ua = HTTP::UserAgent::Strict.new;
$ua.timeout = 10;

my $response = $ua.get("URL");

if $response.is-success {
    say $response.content;
}
else {
    die $response.status-line;
}
```

DESCRIPTION
===========

This module is based on [HTT::UserAgent](https://github.com/raku-community-modules/HTTP-UserAgent).
It attempts to follow the RFCs more closely.  Otherwise, its behavior is intended to match that module.
Please see that module's documentation but note that this module's classes end in ::Strict.

AUTHOR
======

  * Filip Sergot (original)

Source can be located at: https://github.com/zjmarlow/http-useragent-strict. Comments and tickets welcome.

COPYRIGHT AND LICENSE
=====================

Copyright 2014 - 2022 Filip Sergot

Copyright 2023 - 2025 The Raku Community

This library is free software; you can redistribute it and/or modify it under the MIT License.
