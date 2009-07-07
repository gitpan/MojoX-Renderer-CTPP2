package MojoX::Renderer::CTPP2;

use strict;
use warnings;

use base 'Mojo::Base';

use HTML::CTPP2 ();
use Carp        ();

use File::Spec ();
use File::Path qw/make_path/;

our $VERSION = '0.01';

__PACKAGE__->attr('ctpp2', chained => 1);

sub build {
    my $self = shift->SUPER::new(@_);
    my %args = @_;

    my %config = (%{$args{template_options} || {}});

    Carp::carp "Not defined 'mojo' param. Relative path for compiled templates ignored. Use path - "
      . File::Spec->catdir(File::Spec->tmpdir, $self->{COMPILE_DIR})
      if !$self->{mojo}
          && ($self->{COMPILE_DIR} && ! File::Spec->file_name_is_absolute($self->{COMPILE_DIR}));

    $self->ctpp2(HTML::CTPP2->new(%config))
      or Carp::croak 'Could not initialize CTPP2 object';

    return sub { $self->_render(@_) };
}

sub _render {
    my ($self, $renderer, $c, $output) = @_;

    my $template_path = $c->stash->{template_path};

    my $bytecode =
      ($self->{COMPILE_DIR} || $self->{COMPILE_EXT})
      ? $self->compile_bytecode($template_path, $renderer)
      : $self->ctpp2->parse_template($template_path);

    $self->ctpp2->param($c->stash);

    $$output = $self->ctpp2->output($bytecode);

    unless ($$output = $self->ctpp2->output($bytecode)) {
        Carp::carp 'Template error: ['
          . $self->ctpp2->get_last_error->{'template_name'} . '] - '
          . $self->ctpp2->get_last_error->{'error_str'};
        return 0;
    }
    else {
        return 1;
    }
}

sub compile_bytecode {
    my ($self, $template_path, $renderer) = @_;

    my $compile_dir;
    if ($self->{mojo}) {
        $compile_dir =
            $self->{COMPILE_DIR}
          ? File::Spec->file_name_is_absolute($self->{COMPILE_DIR})
              ? $self->{COMPILE_DIR}
              : $self->{mojo}->home->rel_dir($self->{COMPILE_DIR})
          : $self->{mojo}->home->rel_dir('tmp/ctpp2');
    }
    else {
        $compile_dir =
            $self->{COMPILE_DIR}
          ? File::Spec->file_name_is_absolute($self->{COMPILE_DIR})
              ? $self->{COMPILE_DIR}
              : File::Spec->catdir(File::Spec->tmpdir, $self->{COMPILE_DIR})
          : File::Spec->catdir(File::Spec->tmpdir, 'ctpp2');
    }

    my $template = File::Spec->abs2rel($template_path, $renderer->root);
    $template =~ s{\.[^\.]+$}{};
    $template .= $self->{COMPILE_EXT} || '.ctpp2c';
    $template = File::Spec->catfile($compile_dir, $template);

    my $bytecode;
    if (-e $template) {
        if ((stat($template))[9] < (stat($template_path))[9]) {
            $bytecode = $self->ctpp2->parse_template($template_path);
            $bytecode->save($template);
        }
        else {
            $bytecode = $self->ctpp2->load_bytecode($template);
        }
    }
    else {
        $bytecode = $self->ctpp2->parse_template($template_path);

        my $save_path = $template;
        $save_path =~ s{/[^/]+$}{};

        make_path($save_path) if !-d $save_path;

        $bytecode->save($template);
    }
    return $bytecode;
}

1;

__END__

=encoding utf8

=head1 NAME

MojoX::Renderer::CTPP2 - CTPP2 renderer for Mojo

=head1 SYNOPSIS

Add the handler:

    use MojoX::Renderer::CTPP2;

    sub startup {
       ...

       my $ctpp2 = MojoX::Renderer::CTPP2->build(
            mojo        => $self,
            COMPILE_DIR => '/tmp/ctpp',
            COMPILE_EXT => '.ctpp2'
            template_options =>
             { arg_stack_size => 1024,
               arg_stack_size => 2048
             }
       );

       $self->renderer->add_handler( ctpp2 => $ctpp2 );

       ...
    }

And then in the handler call render which will call the
MojoX::Renderer::CTPP2 renderer.

   $c->render(foo => 653, bar => [qw(abc 7583 def)]);


=head1 METHODS

=head2 build

This method returns a handler for the Mojo renderer.

Supported parameters are:

=over 4

=item mojo

C<new> currently requires a I<mojo> parameter pointing to the base class Mojo-object. (Need for initial path to compiled templates.)

=item COMPILE_DIR

Root of directory in which compiled template files should be written.

I<If not defined B<'COMPILE_DIR'> or B<'COMPILE_EXT'> params - template don't compile and save.>

=item COMPILE_EXT

Filename extension for compiled template files (default - .ctpp2c).

=item template_options

A hash reference of options that are passed to CTPP2->new().

=back

=head3 About path for compiled templates:

=over

=item *

If B<mojo> and B<COMPILE_DIR> are defined:

=over

=item *

B<COMPILE_DIR> is absolute path - use this absolute path (ex.: mojo project root path - '/mojo', COMPILE_DIR - '/c_tmpl', path for compiled templates - '/c_tmpl')

=item *

B<COMPILE_DIR> is relative path - use relative path into B<mojo> root directory (ex.: mojo project root path - '/mojo', COMPILE_DIR - 'tmp/c_tmpl', path for compiled templates - '/mojo/tmp/c_tmpl')

=back

=back

=over

=item *

If B<mojo> defined and B<COMPILE_DIR> not defined:

=over

=item *

use relative path 'tmp/ctpp2' into B<mojo> root directory (ex.: mojo project root path - '/mojo', path for compiled templates - '/mojo/tmp/ctpp2')

=back

=back

=over

=item *

If B<mojo> not defined and B<COMPILE_DIR> are defined:

=over

=item *

B<COMPILE_DIR> is absolute path - use this absolute path (COMPILE_DIR - '/c_tmpl', path for compiled templates - '/c_tmpl')

=item *

B<COMPILE_DIR> is relative path - use relative path into C<File::Spec-E<gt>tmpdir> function directory (ex.: system temporary path - '/tmp', COMPILE_DIR - 'c_tmpl', path for compiled templates - '/tmp/c_tmpl')

=back

=back

=over

=item *

Both parameters B<mojo> and B<COMPILE_DIR> not defined:

=over

=item *

use relative path 'ctpp2' into C<File::Spec-E<gt>tmpdir> function directory (ex.: system temporary path - '/tmp', path for compiled templates - '/tmp/ctpp2')

=back

=back

=head1 AUTHOR

Victor M Elfimov, (victor@sols.ru)

=head1 BUGS

Please report any bugs or feature requests to C<bug-mojox-renderer-ctpp2 at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MojoX-Renderer-CTPP2>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MojoX::Renderer::CTPP2

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=MojoX-Renderer-CTPP2>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/MojoX-Renderer-CTPP2>

=item * Search CPAN

L<http://search.cpan.org/dist/MojoX-Renderer-CTPP2/>

=back

=head1 SEE ALSO

HTML::CTPP2(3)

=head1 COPYRIGHT & LICENSE

Copyright 2009 Victor M Elfimov

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
