[![Build Status](https://travis-ci.org/skaji/File-Queue.svg?branch=master)](https://travis-ci.org/skaji/File-Queue)
[![AppVeyor Status](https://ci.appveyor.com/api/projects/status/github/skaji/File-Queue?branch=master&svg=true)](https://ci.appveyor.com/project/skaji/File-Queue)

# NAME

File::Queue - file based queue

# SYNOPSIS

    use File::Queue;

    my $queue = File::Queue->new( file => 'app.bin', size => 64*(1024**2) );

    my $ok = $queue->enqueue("data");

    my $data = $queue->dequeue;

# DESCRIPTION

File::Queue is

# AUTHOR

Shoichi Kaji <skaji@cpan.org>

# COPYRIGHT AND LICENSE

Copyright 2018 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
