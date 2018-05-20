#!/usr/bin/env perl
use strict;
use warnings;

use lib "lib", "../lib";
use File::Queue;
use Benchmark 'timethis';

my $file = "./queue.bin";
unlink $file if -f $file;
my $q = File::Queue->new(file => $file, size => 128*(1024**2));

timethis -1, sub {
    my $v = "x" x 1024;
    for (1..100) {
        $q->enqueue($v . $_) or die;
    }
};
