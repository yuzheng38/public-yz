#!/usr/bin/perl
#####################################################################################
# script to validate input against regex rules
#####################################################################################
use strict;
use warnings;

my $ERR_DS_CMD = 1;
my $ERR_FILE_CHK = 1;
my $ERR_NO_VALIDATION_RULES = 1;
my $ERR_NULL_VALIDATION_RULE = 1;
my $ERR_VALIDATION_SCRIPT_NOT_EXEC = 1;

# DEFAULTS - validation rule
my $RULE_MIN_COUNT_DEFAULT = 0;
my $RULE_MAX_COUNT_DEFAULT = 999;
my $RULE_ERR_TEXT_DEFAULT = "Default error message";
my $RULE_ERR_CODE_DEFAULT = 99;

# Datastage command check
if (( not defined $ARGV[0] ) || (not defined $ARGV[1] )){
	print STDERR "Command entered in Datastage is not valid. Valid example: #command [rules.dat] [data.dat] \n";
	exit $ERR_DS_CMD;
}

my ($rules_file, $data_file) = @ARGV;

# File tests -exists -isFile -readable -zeroBytes or -executable
if (( ! -e $rules_file ) || ( ! -f _ ) || ( ! -r _ ) || ( -z _ )) {
	print STDERR "File $rules_file does not exist or is not readable or is empty\n";
	exit $ERR_FILE_CHK;
}
if (( ! -e $data_file ) || ( ! -f _ ) || ( ! -r _ ) || ( -z _ )) {
	print STDERR "File $data_file does not exist or is not readable or is empty\n";
	exit $ERR_FILE_CHK;
}

# Pre-process validation rules
my $preprocessed_rules = preprocess_rules_file();

# Parse rules to get rule parameters.
my @all_rules = parse_rules($preprocessed_rules);
# Iterate and process each rule in @rules array against the data input file
foreach my $rule ( @all_rules ){
	# If not null, parse out individual fields using the new delimitor ";;"
	my ( $regex, $mincount, $maxcount, $errortext, $errorcode ) = @$rule;

	# Validation rule individual field check.. set defaults if any field is empty
	next if $regex eq "";		# print "Rule: empty rule...\n...skipping validation...\n\n" if $regex eq '""';
	$mincount = $RULE_MIN_COUNT_DEFAULT if $mincount eq "";
	$maxcount = $RULE_MAX_COUNT_DEFAULT if $maxcount eq "";
	$errortext = $RULE_ERR_TEXT_DEFAULT if $errortext eq "";
	$errorcode = $RULE_ERR_CODE_DEFAULT if $errorcode eq "";
	# print "printing from main: ", $regex, " ", $mincount, " ", $maxcount, " ", $errortext, " ", $errorcode, "\n";

	my $record_count = validate($regex, $mincount, $maxcount, $errortext, $errorcode, $data_file);
	print "Rule: $regex\n";
	print "Records found: $record_count\n";

	# If any one rule is not complied, stop processing the remaining rules and return the #errorcode and #errortext provided
	if ( $record_count < ($mincount + 0) || $record_count > ($maxcount + 0)){
		print STDERR "$errortext\n";
		exit $errorcode;
	}
}
print "File validation job finished successfully\n";
exit 0;

###############################################################################
# preprocess():
# 	gawk shell command to pre-process the rules input file
# 	subbing comma delimiter with ";;" delimiter 
###############################################################################
sub preprocess_rules_file {
	my $gawk_results= `cat $rules_file | gawk -vFPAT='([^,]*)|("[^"]*")' '{print\$1 ";;" \$2 ";;" \$3 ";;" \$4 ";;" \$5}'` ;
	# my $gawk_results= `cat $rules_file | gawk -vFPAT='([^,]*)|("[^"]*")' '{if(NR>1) print\$1 ";;" \$2 ";;" \$3 ";;" \$4 ";;" \$5}'` ;
	if ( length( $gawk_results ) == 0 ) {
		print STDERR "File $rules_file does not have any rules.\n";
		exit $ERR_NO_VALIDATION_RULES;
	}
	return $gawk_results;
}

sub parse_rules {
	my $prepped_rules_str = shift @_; # @_ == $preprocessed_rules	my $arg2 = shift @_; my $args3 = shift @_;

	# split and store each rule in the @rules_strs array
	my @rule_strs = split /\n/, $prepped_rules_str;

	my @all_rules;
	foreach my $rule_str ( @rule_strs ) {
		# skip if there's an empty line in the rules data file. i.e. a null rule
		next if $rule_str =~ /;;;;;;;;/;

		my ($regex, $mincount, $maxcount, $message, $code) = split /;;/, $rule_str;
		my @one_rule;
		
		# trim off one extra escape char
		$regex =~ s/\\\\/\\/g;
		# trim off quotation marks
		push(@one_rule, substr($regex, 1, length($regex) - 2));		#  "^T\\|[0-9]{7}\\|" ===> ^T\\|[0-9]{7}\\|
		push(@one_rule, substr($mincount, 1, length($mincount) - 2));
		push(@one_rule, substr($maxcount, 1, length($maxcount) - 2));
		push(@one_rule, substr($message, 1, length($message) - 2));
		push(@one_rule, substr($code, 1, length($code) - 3));	

		push(@all_rules, \@one_rule);
	}
	return @all_rules;
}

sub validate {
	my ($regex, $mincount, $maxcount, $errortext, $errorcode, $data_file) = @_;
	my $rule_count = 0;

	if (open(my $fd, '<:encoding(UTF_8)', $data_file)){
		while (my $row = <$fd>) {
			chomp $row;

			if ( $row =~ /$regex/ ) {
				$rule_count++;
			}
		}
		return $rule_count;
	} else {
		warn "cound not open file.. \n";
	}
}
