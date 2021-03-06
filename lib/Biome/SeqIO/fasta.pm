package Biome::SeqIO::fasta;

use Biome;
use Biome::PrimarySeq;
use Biome::Type::Sequence 'Output_ID_Type';

extends 'Biome::SeqIO';

has 'width' => (
    isa     => 'Int',
    is      => 'rw',
    lazy    => 1,
    default => 60
);

has 'preferred_id_type' => (
    isa     => Output_ID_Type,
    is      => 'rw',
    lazy    => 1,
    default => 'display'
);

sub next_Seq {
    my ($self) = @_;
    my $seq;
    my $alphabet;
    local $/ = "\n>";
    return unless my $entry = $self->readline;

    chomp($entry);
    if ( $entry =~ m/\A\s*\Z/s ) {    # very first one
        return unless $entry = $self->readline;
        chomp($entry);
    }

    # this just checks the initial input; beyond that, due to setting $/ above,
    # the > is part of the record separator and is removed
    $self->throw( "The sequence does not appear to be FASTA format "
          . "(lacks a descriptor line '>')" )
      if $. == 1 && $entry !~ /^>/;

    $entry =~ s/^>//;

    my ( $top, $sequence ) = split( /\n/, $entry, 2 );
    defined $sequence && $sequence =~ s/>//g;

    my ( $id, $fulldesc );
    if ( $top =~ /^\s*(\S+)\s*(.*)/ ) {
        ( $id, $fulldesc ) = ( $1, $2 );
    }

    if ( defined $id && $id eq '' ) { $id = $fulldesc; }   # FIX incase no space
             # between > and name \AE
    defined $sequence && $sequence =~ tr/ \t\n\r//d;    # Remove whitespace

    # for empty sequences we need to know the mol.type
    $alphabet = $self->alphabet();
    if ( defined $sequence && length($sequence) == 0 ) {
        if ( !defined($alphabet) ) {

            # let's default to dna
            $alphabet = "dna";
        }
    }
    else {

        # we don't need it really, so disable
        # we want to keep this if SeqIO alphabet was set by user
        # not sure if this could break something
        $alphabet = undef;
    }

    # switch this to a builder, or better yet a handler...
    $seq = Biome::PrimarySeq->new(
        -seq => $sequence,

        # forcing more specificity here (from -id to -display_id)
        # We could possibly alias this, but I think more specific the better.
        -display_id => $id,

        # Ewan's note - I don't think this healthy
        # but obviously to taste.
        #-primary_id  => $id,
        -description => $fulldesc,
        -alphabet    => $alphabet,

        #-direct      => 1,  # what does this do??
    );

    return $seq;
}

sub next_dataset {
    $_[0]->throw_not_implemented;
}

sub write_Seq {
    my ( $self, @seq ) = @_;
    my $width = $self->width;
    foreach my $seq (@seq) {
        $self->throw("Did not provide a valid Biome::Role::PrimarySeq implementation")
          unless defined $seq && ref($seq) && $seq->does('Biome::Role::PrimarySeq');

        my $top;

        # Allow for different ids
        my $id_type = $self->preferred_id_type;
        if ( $id_type =~ /^acc/i ) {
            $top = $seq->accession_number();
            if ( $id_type =~ /vers/i ) {
                $top .= "." . $seq->version();
            }
        }
        elsif ( $id_type =~ /^displ/i ) {
            $self->warn(
                "No whitespace allowed in FASTA ID [" . $seq->display_id . "]" )
              if defined $seq->display_id && $seq->display_id =~ /\s/;
            $top = $seq->display_id();
            $top = '' unless defined $top;
            $self->warn( "No whitespace allowed in FASTA ID [" . $top . "]" )
              if defined $top && $top =~ /\s/;
        }
        elsif ( $id_type =~ /^pri/i ) {
            $top = $seq->primary_id();
        }

        if ( $seq->can('description') and my $desc = $seq->description() ) {
            $desc =~ s/\n//g;
            $top .= " $desc";
        }

        #if ( $seq->isa('Bio::Seq::LargeSeqI') ) {
        #    $self->_print(">$top\n");
        #
        #    # for large seqs, don't call seq(), it defeats the
        #    # purpose of the largeseq functionality.  instead get
        #    # chunks of the seq, $width at a time
        #    my $buff_max = 2000;
        #    my $buff_size =
        #      int( $buff_max / $width ) *
        #      $width;    #< buffer is even multiple of widths
        #    my $seq_length = $seq->length;
        #    my $num_chunks = int( $seq_length / $buff_size + 1 );
        #    for ( my $c = 0 ; $c < $num_chunks ; $c++ ) {
        #        my $buff_end = $buff_size * ( $c + 1 );
        #        $buff_end = $seq_length if $buff_end > $seq_length;
        #        my $buff = $seq->subseq( $buff_size * $c + 1, $buff_end );
        #        if ($buff) {
        #            $buff =~ s/(.{1,$width})/$1\n/g;
        #            $self->_print($buff);
        #        }
        #        else {
        #            $self->_print("\n");
        #        }
        #    }
        #}
        #else {
            my $str = $seq->seq;
            if ( defined $str && length($str) > 0 ) {
                $str =~ s/(.{1,$width})/$1\n/g;
            }
            else {
                $str = "\n";
            }
            $self->print( ">$top\n$str" ) or return;
        #}
    }

    $self->flush if $self->flush_on_write && defined $self->fh;
    return 1;
}

no Biome::Role;

1;

__END__

=head1 NAME

Biome::SeqIO::fasta - <One-line description of module's purpose>

=head1 VERSION

This documentation refers to Biome::SeqIO::fasta version Biome::Role.

=head1 SYNOPSIS

   # this wouldn't normallly be used 
   with 'Biome::SeqIO::fasta';
   # Brief but working code example(s) here showing the most common usage(s)

   # This section will be as far as many users bother reading,

   # so make it as educational and exemplary as possible.

=head1 DESCRIPTION

<TODO>
A full description of the module and its features.
May include numerous subsections (i.e., =head2, =head3, etc.).

=head1 SUBROUTINES/METHODS

<TODO>
A separate section listing the public components of the module's interface.
These normally consist of either subroutines that may be exported, or methods
that may be called on objects belonging to the classes that the module provides.
Name the section accordingly.

In an object-oriented module, this section should begin with a sentence of the
form "An object of this class represents...", to give the reader a high-level
context to help them understand the methods that are subsequently described.

=head1 DIAGNOSTICS

<TODO>
A list of every error and warning message that the module can generate
(even the ones that will "never happen"), with a full explanation of each
problem, one or more likely causes, and any suggested remedies.

=head1 CONFIGURATION AND ENVIRONMENT

<TODO>
A full explanation of any configuration system(s) used by the module,
including the names and locations of any configuration files, and the
meaning of any environment variables or properties that can be set. These
descriptions must also include details of any configuration language used.

=head1 DEPENDENCIES

<TODO>
A list of all the other modules that this module relies upon, including any
restrictions on versions, and an indication of whether these required modules are
part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.

=head1 INCOMPATIBILITIES

<TODO>
A list of any modules that this module cannot be used in conjunction with.
This may be due to name conflicts in the interface, or competition for
system or program resources, or due to internal limitations of Perl
(for example, many modules that use source code filters are mutually
incompatible).

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

User feedback is an integral part of the evolution of this and other Biome and
BioPerl modules. Send your comments and suggestions preferably to one of the
BioPerl mailing lists. Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

Patches are always welcome.

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and reponsive
experts will be able look at the problem and quickly address it. Please include
a thorough description of the problem with code and data examples if at all
possible.

=head2 Reporting Bugs

Preferrably, Biome bug reports should be reported to the GitHub Issues bug
tracking system:

  http://github.com/cjfields/biome/issues

Bugs can also be reported using the BioPerl bug tracking system, submitted via
the web:

  http://bugzilla.open-bio.org/

=head1 EXAMPLES

<TODO>
Many people learn better by example than by explanation, and most learn better
by a combination of the two. Providing a /demo directory stocked with
well-commented examples is an excellent idea, but your users might not have
access to the original distribution, and the demos are unlikely to have been
installed for them. Adding a few illustrative examples in the documentation
itself can greatly increase the "learnability" of your code.

=head1 FREQUENTLY ASKED QUESTIONS

<TODO>
Incorporating a list of correct answers to common questions may seem like extra
work (especially when it comes to maintaining that list), but in many cases it
actually saves time. Frequently asked questions are frequently emailed
questions, and you already have too much email to deal with. If you find
yourself repeatedly answering the same question by email, in a newsgroup, on a
web site, or in person, answer that question in your documentation as well. Not
only is this likely to reduce the number of queries on that topic you
subsequently receive, it also means that anyone who does ask you directly can
simply be directed to read the fine manual.

=head1 COMMON USAGE MISTAKES

<TODO>
This section is really "Frequently Unasked Questions". With just about any kind
of software, people inevitably misunderstand the same concepts and misuse the
same components. By drawing attention to these common errors, explaining the
misconceptions involved, and pointing out the correct alternatives, you can once
again pre-empt a large amount of unproductive correspondence. Perl itself
provides documentation of this kind, in the form of the perltrap manpage.

=head1 SEE ALSO

<TODO>
Often there will be other modules and applications that are possible
alternatives to using your software. Or other documentation that would be of use
to the users of your software. Or a journal article or book that explains the
ideas on which the software is based. Listing those in a "See Also" section
allows people to understand your software better and to find the best solution
for their problem themselves, without asking you directly.

By now you have no doubt detected the ulterior motive for providing more
extensive user manuals and written advice. User documentation is all about not
having to actually talk to users.

=head1 (DISCLAIMER OF) WARRANTY

<TODO>
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=head1 ACKNOWLEDGEMENTS

<TODO>
Acknowledging any help you received in developing and improving your software is
plain good manners. But expressing your appreciation isn't only courteous; it's
also enlightened self-interest. Inevitably people will send you bug reports for
your software. But what you'd much prefer them to send you are bug reports
accompanied by working bug fixes. Publicly thanking those who have already done
that in the past is a great way to remind people that patches are always
welcome.

=head1 AUTHOR

Chris Fields  C<< <cjfields at bioperl dot org> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2010 Chris Fields (cjfields at bioperl dot org). All rights reserved.

followed by whatever licence you wish to release it under.
For Perl code that is often just:

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
