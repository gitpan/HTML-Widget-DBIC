package HTML::Widget::DBIC;
use strict;
use warnings;

BEGIN {
	use Exporter ();
	use vars qw ($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	$VERSION     = 0.03;
	@ISA         = qw (Exporter);
	#Give a hoot don't pollute, do not export more than needed by default
	@EXPORT      = qw ();
	@EXPORT_OK   = qw ();
	%EXPORT_TAGS = ();
}
use base 'HTML::Widget';
use Data::Dumper;

sub _make_elem {
    my( $w, $field_conf, @options ) = @_;
#    warn "Making element: " . Dumper($field_conf); use Data::Dumper;
    my @widget_args = @{$field_conf->{widget_element}};
    my $widget_type = shift @widget_args;
    my %additionalmods = @widget_args;
#    $widget_element = 'Select' if $widget_element eq 'DoubleSelect';
    my $element = $w->element( $widget_type , $field_conf->{name} );
    if ( $widget_type eq 'Select' ){
        $element->options(0, '', @options);
    }
    if ( $widget_type eq 'DoubleSelect' ){
        $element->options( @options );
    }
    $element->label( $field_conf->{label} );
    for my $widgetmod ( keys %additionalmods ) {
        $element->$widgetmod( $additionalmods{$widgetmod} );
    }
    return $element;
}

sub _make_constraints {
    my( $w, $field_conf ) = @_;
    for my $cconf ( @{ $field_conf->{constraints} || [] } ) {
        my $const =
          $w->constraint( $cconf->{constraint}, $field_conf->{name},
            $cconf->{args} ? @{ $cconf->{args} } : () );
        $cconf->{$_} and $const->$_( $cconf->{$_} )
          for qw/min max regex callback in message/;
    }
}

sub _get_options {
    my( $resultset ) = @_;
    my @options;
#    my $displaymethod = $config->{$class}->{displaymethod};
    my( $pkey ) = $resultset->result_source->primary_columns();
    my $j = 1;
    my $rs = $resultset->search();
    while( my $i = $rs->next() ){
        push @options, $i->$pkey, "$i";   #->$displaymethod;
    }
    return @options;
}

sub _getval {
    my( $item, $field_conf, $schema ) = @_;
    my $class = $field_conf->{foreign_class};
    my $name  = $field_conf->{name};
    my @widget_args = @{$field_conf->{widget_element}};
    my $widget_type = shift @widget_args;
    my %additionalmods = @widget_args;
    if( $class ){
        my( $pkey ) = $schema->source( $class )->primary_columns();
        if( $additionalmods{multiple} ){
            my @vals;
            my $rs = $item->$name();
            while( my $rec = $rs->next() ){
                push @vals, $rec->$pkey;
            }
            return @vals;
        }else{
            return $item->$name()->$pkey;
        }
    }else{
        if( $widget_type eq 'Password' ){
            $name =~ s/_2$//;
        }
        return $item->$name();
    }
}

sub create_from_config {
    my ( $class, $config, $resultset, $item ) = @_;
#    warn 'aaaaaaaaaaa' . Dumper($config); use Data::Dumper;
    my $self = $class->SUPER::new;
    my $schema = $resultset->result_source->schema;
    for my $col ( @{$config} ) {
        next if ! defined $col->{widget_element};
        my @options;
        if( $col->{foreign_class} ){
            @options = _get_options( $schema->resultset( $col->{foreign_class} ) );
        }
        my $element = _make_elem( $self, $col, @options );
        $element->value( _getval($item, $col, $schema) ) if $item &&
        $element->can('value');
        _make_constraints( $self, $col );
    }
    $self->{dbic_config} = $config;
    $self->{dbic_schema} = $schema;
    $self->{dbic_resultclass} = $resultset->result_class;
    $self->{dbic_item}   = $item;
    return bless( $self, $class);
}

sub process {
    my $self = shift;
    my $result = $self->SUPER::result( @_ );
    for my $attr ( qw/ dbic_config dbic_schema dbic_resultclass dbic_item / ){ 
        $result->{$attr} = $self->{$attr};
    }
    return bless ( $result, 'HTML::Widget::Result::DBIC' );
}


package HTML::Widget::Result::DBIC;
use base 'HTML::Widget::Result';
use Data::Dumper;

sub save_to_db {
    my $self = shift;
#    my ( $interface_config, $class, $widget, $item ) = @_;
    my $config = $self->{dbic_config};
    my @widgets = ( $self, @{ $self->{_embedded} || [] } );
    my @elements = map @{ $_->{_elements} }, @widgets;
    my ( @cols, @rels, %rels );
    my $resultclass = $self->{dbic_resultclass};
    my $schema = $self->{dbic_schema};
    my $source = $schema->source($self->{dbic_resultclass});
    my %possiblerels;
    my %pkeys = map { $_ => 1 } $source->primary_columns();
    for my $field ( @$config ){
        next if $pkeys{$field->{name}};
        if ( $source->has_column ( $field->{name} ) ){
            push @cols, $field->{name};
        }elsif ( !$field->{not_to_db} ) { 
            push @rels, $field->{name};
            $rels{$field->{name}} = 1;
        }
    }
    my %obj = map {
         $_ => scalar $self->param( $_ )
    } @cols;
    my $item = $self->{dbic_item} || $schema->resultset( $self->{dbic_resultclass} )->new_result( {} );
    $item->result_source->schema->txn_do(
        sub {
            $item->set_columns( \%obj );
            my $in_storage = $item->in_storage;
            $item->insert_or_update;
            for (@$config) {
                my $name = $_->{name};
                next if ! $rels{$name};
                if ( my $bridge_rel = $_->{bridge_rel} ){
                    $item->delete_related( $bridge_rel ) if $in_storage;
                    my $foreign_class = $_->{foreign_class};
                    my $other_class = $schema->source($foreign_class);
                    my $info = $other_class->relationship_info($bridge_rel);
                    my ($self_col, $foreign_col) = %{$info->{cond}};
                    if ( $self_col =~ /^foreign/ ) {
                        ( $foreign_col, $self_col ) = %{$info->{cond}};
                    }
                    $foreign_col =~ s/foreign\.//;
                    $self_col    =~ s/self\.//;
                    $item->create_related( $bridge_rel,
                        { $foreign_col => $_ } )
                      for $self->param($name);
                }
                else {                          #if ( $info->{type} eq 'has_many' ) {
                    my $info = $item->result_source->relationship_info($name);
                    my ($self_col, $foreign_col) = %{$info->{cond}};
                    if ( $self_col =~ /^foreign/ ) {
                        ( $foreign_col, $self_col ) = %{$info->{cond}};
                    }
                    $foreign_col =~ s/foreign\.//;
                    $self_col    =~ s/self\.//;
                    if ($in_storage) {
                        my $related_objs = $item->search_related(
                            $name,
                            {
                                $self_col =>
                                  { -not_in => [ $self->param($name) ] },
                            }
                        );

                        # Let's try to put a NULL in the related objects FK
                        eval {
                            $related_objs->update(
                                { $foreign_col => undef } );
                          }

             # If the relation can't be NULL the related objects must be deleted
                          || $related_objs->delete;
                    }
                    my ($pk) = $item->result_source->primary_columns;
                    my @values = grep $_, $self->param($name);
                    $item->result_source->schema->resultset( $info->{class} )
                      ->search( { $self_col => \@values } )
                      ->update( { $foreign_col => $item->$pk } )
                      if @values;
                }
            }
        }
    );
    return $item;
}



1;

__END__


=head1 NAME

HTML::Widget::DBIC - a subclass of HTML::Widgets for dealing with DBIx::Class

=head1 SYNOPSIS

    use HTML::Widget::DBIC;
    
    # create a widget coupled with a db record
    my $widget = HTML::Widget::DBIC->create_from_config( $config, $resultset, $item );

    # process a query
    my $result = $widget->process ( $query );

    # and save the values from the query to the database
    $result->save_to_db();


=head1 METHODS

=over 4

=item create_from_config

Method to create widget.  The parameters are configuration for all the widget
fields, a DBIC Resultset and optionally 
a DBIC record (item) - to fill in the current values in the form and as the
target for saving the data, if not present when saving a new record will be
created.

The config is a reference to a list of configuration for particular fields.
Like:
    my $config = [
        {
            'foreign_class'  => 'Dvd',
            'widget_element' => [ 'Select', 'multiple' => 1 ],
            'name'           => 'dvds',
            'label'          => 'Dvds',
            'bridge_rel'     => 'dvdtags'
        },
        {
            'widget_element' => [
                'Textarea', 
                'rows' => 5,
                'cols' => 60
            ],
            'constraints' => [
                {
                    'max'        => '255',
                    'constraint' => 'Length',
                    'message'    => 'Should be shorten than 255 characters'
                },
                {
                    'constraint' => 'All',
                    'message'    => 'The field is required'
                }
            ],
            'name'  => 'name',
            'label' => 'Name'
        },
        {
            'primary_key' => 1,
            'name'        => 'id',
            'label'       => 'Id'
        }
    ];
    

=item process

Like HTML::Widget->process but produces HTML::Widget::Result::DBIC (instead of
HTML::Widget::Result) - with extra info for saving to database.

=item save_to_db

HTML::Widget::DBIC::Result method to save the data from widget to the database

=cut
=back

=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
Catalyst::Helper::Controller::InstantCRUD requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-catalyst-helper-controller-instantcrud@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

<Zbigniew Lukasiak>  C<< <<zz bb yy @ gmail.com>> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2005, <Zbigniew Lukasiak> C<< <<zz bb yy @ gmail.com>> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.


1;    # Magic true value required at end of module
__END__


