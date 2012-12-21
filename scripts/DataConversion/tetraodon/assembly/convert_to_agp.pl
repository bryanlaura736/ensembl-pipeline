#!/usr/bin/env perl
# $Source: /tmp/ENSCOPY-ENSEMBL-PIPELINE/scripts/DataConversion/tetraodon/assembly/convert_to_agp.pl,v $
# $Revision: 1.2 $

my $last_chr_name;

while(<>) {
  /^(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\d+)/ and do {
    my ($chr_name, 
        $chr_start, 
        $chr_end, 
        $type, 
        $seq_name, 
        $seq_start, 
        $seq_end, 
        $strand, 
        $reg_length) = ($1, $2, $3, $4, $5, $6, $7, $8, $9);

    if (not $last_chr_name or $last_chr_name ne $chr_name) {
      $ordinal = 1;
      $last_chr_name = $chr_name;
    } else {
      $ordinal++;
    }

    my ($end_of_chr_name) = $chr_name =~ /chr(\S+)$/;

    if ($type eq "S") {
      $type = "F";
      $rest = "$seq_name\t1\t$reg_length\t$strand";
    } else {
      $type = "N";
      $rest = "$seq_name";
    }

    print "$end_of_chr_name\t$chr_start\t$chr_end\t$ordinal\t$type\t$rest\n";

  };
}
