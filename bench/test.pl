#!/usr/bin/env perl
use strict;
use warnings;

use lib "lib", "../lib";
use File::Queue;

my $file = "./queue.bin";
unlink $file if -f $file;
my $q = File::Queue->new(file => $file, size => 1*(1024**2));


for my $i (1..115000) {
    $q->enqueue($i) or die
}

my %pid;
for my $id (1..10) {
    my $pid = fork // die;
    if ($pid) {
        $pid{$pid}++;
        next;
    }

    my $done = 0;
    while (my $data = $q->dequeue) {
        $done++;
    }
    warn "worker$id (pid $$) DONE $done\n";
    exit;
}

while (%pid) {
    my $pid = wait;
    delete $pid{$pid};
}

warn "master (pid $$) DONE\n";

