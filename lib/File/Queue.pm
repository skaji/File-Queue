package File::Queue;
use strict;
use warnings;

our $VERSION = '0.001';

{
    package File::Queue::Lock;
    use Fcntl ();
    sub new {
        my ($class, $fh, $kind) = @_;
        flock $fh, $kind;
        bless { fh => $fh }, $class;
    }
    sub DESTROY {
        my $self = shift;
        flock $self->{fh}, Fcntl::LOCK_UN;
    }
}

use Fcntl qw(:flock SEEK_CUR);
use POSIX qw(O_RDWR O_CREAT O_RDONLY);

my $FORMAT_VERSION = '1';
my $META_SIZE = 64;

sub new {
    my ($class, %args) = @_;

    my $open_flag = $args{readonly} ? O_RDONLY : O_RDWR | O_CREAT;
    sysopen my $fh, $args{file}, $open_flag or die "$!: $args{file}";
    my $self = bless {
        size => 1024**2,
        %args,
        owner => $$,
        meta_size => 64,
        fh => $fh,
        open_flag => $open_flag,
    }, $class;

    my $guard = File::Queue::Lock->new($fh, LOCK_EX);
    if (-s $fh == 0) {
        sysseek $fh, $self->{size}-1, 0;
        syswrite $fh, "\0";
        $self->_meta_write({
            version => $FORMAT_VERSION,
            size => $self->{size},
            first => $META_SIZE,
            last => $META_SIZE,
            count => 0,
        });
    }
    undef $guard;

    $self;
}

sub stat {
    my $self = shift;
    my $meta = $self->_meta_read;
    my $mtime = (stat $self->{fh})[9];

    my $free;
    if ($meta->{count} == 0) {
        $free = $meta->{size} - $META_SIZE;
    } elsif ($meta->{last} < $meta->{first}) {
        $free = $meta->{first} - $meta->{last};
    } else {
        $free = $meta->{first} - $META_SIZE + $meta->{size} - $meta->{last};
    }
    +{
        size => $meta->{size} - $META_SIZE,
        free => $free,
        count => $meta->{count},
        mtime => $mtime,
    };
}

sub enqueue {
    my ($self, $data) = @_;
    $self->_reopen_if_any;
    my $guard = File::Queue::Lock->new($self->{fh}, LOCK_EX);
    my $meta = $self->_meta_read;
    my $ok = $self->_data_write($meta, (pack 'I', length $data) . $data);
    $self->_meta_write($meta) if $ok;
    $ok;
}

sub dequeue {
    my $self = shift;
    $self->_reopen_if_any;
    my $guard = File::Queue::Lock->new($self->{fh}, LOCK_EX);
    my $meta = $self->_meta_read;
    my $data = $self->_data_read($meta);
    $self->_meta_write($meta) if defined $data;
    $data;
}

sub _reopen_if_any {
    my $self = shift;
    return if $self->{owner} == $$;
    close $self->{fh};
    sysopen my $fh, $self->{file}, $self->{open_flag} or die "$!: $self->{file}";
    $self->{owner} = $$;
    $self->{fh} = $fh;
}

sub _meta_read {
    my $self = shift;
    sysseek $self->{fh}, 0, 0;
    sysread $self->{fh}, my $meta, 4*5;
    my ($version, $size, $first, $last, $count) = unpack 'IIIII', $meta;
    return {
        version => $version,
        size => $size,
        first => $first,
        last => $last,
        count => $count,
    };
}

sub _meta_write {
    my ($self, $meta) = @_;
    my $data = pack 'IIIIII', $meta->{version}, $meta->{size},
        $meta->{first}, $meta->{last}, $meta->{count};
    sysseek $self->{fh}, 0, 0;
    syswrite $self->{fh}, $data;
}

sub _data_read {
    my ($self, $meta) = @_;
    return if $meta->{count} == 0;

    my $first = $meta->{first};
    sysseek $self->{fh}, $meta->{first}, 0;
    sysread $self->{fh}, (my $plen), 4;
    if (length $plen < 4) {
        $first = $META_SIZE + 4 - length $plen;
        sysseek $self->{fh}, $META_SIZE, 0;
        sysread $self->{fh}, $plen, 4 - length $plen, length $plen;
    } else {
        $first += 4;
    }
    my $len = unpack 'I', $plen;
    sysread $self->{fh}, (my $data), $len;
    if (length $data < $len) {
        $first = $meta->{meta_data} + $len - length $data;
        sysseek $self->{fh}, $META_SIZE, 0;
        sysread $self->{fh}, $data, $len - length $data, length $data;
    } else {
        $first += $len;
    }
    $meta->{first} = $first;
    $meta->{count}--;
    $data;
}

sub _data_write {
    my ($self, $meta, $data) = @_;
    my $len = length $data;

    my $size      = $meta->{size};
    my $first     = $meta->{first};
    my $last      = $meta->{last};
    my $count     = $meta->{count};

    my $empty = $last <= $first ? $first - $last : ($size - $last) + ($first - $META_SIZE);
    return if $count && $empty < $len;

    sysseek $self->{fh}, $last, 0;
    if (!$empty || $last < $first || $len < $size - $last) {
        syswrite $self->{fh}, $data;
        $meta->{last} += $len;
    } else {
        syswrite $self->{fh}, $data, $size - $last;
        sysseek $self->{fh}, $META_SIZE, 0;
        syswrite $self->{fh}, $data, $len - ($size - $last), $size - $last;
        $meta->{last} = $META_SIZE + $len - ($size - $last);
    }
    $meta->{count}++;
    1;
}

1;
__END__

=encoding utf-8

=head1 NAME

File::Queue - file based queue

=head1 SYNOPSIS

  use File::Queue;

  my $queue = File::Queue->new( file => 'app.bin', size => 64*(1024**2) );

  my $ok = $queue->enqueue("data");

  my $data = $queue->dequeue;

=head1 DESCRIPTION

File::Queue is

=head1 AUTHOR

Shoichi Kaji <skaji@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2018 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
