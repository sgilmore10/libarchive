#!/bin/sh
set -eu

if [ $# != 1 ]
then
	echo "Usage: $0 path/to/UnicodeData.txt"
	exit 1
fi

#
# This needs http://unicode.org/Public/6.0.0/ucd/UnicodeData.txt
#
inputfile="$1"	# Expect UnicodeData.txt
outfile=archive_string_composition.h
pickout=/tmp/mk_unicode_composition_tbl$$.awk
pickout2=/tmp/mk_unicode_composition_tbl2$$.awk
#nfdtmp=/tmp/mk_unicode_decomposition_tmp$$.txt
nfdtmp="nfdtmpx"
#################################################################################
#
# Append the file header of "archive_string_composition.h"
#
#################################################################################
append_copyright()
{
cat > ${outfile} <<CR_END
/*-
 * Copyright (c) 2011-2012 libarchive Project
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR(S) ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR(S) BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * ATTENTION!
 *  This file is generated by build/utils/gen_archive_string_composition_h.sh
 *  from http://unicode.org/Public/6.0.0/ucd/UnicodeData.txt
 *
 *  See also http://unicode.org/report/tr15/
 */

#ifndef __LIBARCHIVE_BUILD
#error This header is only to be used internally to libarchive.
#endif

#ifndef ARCHIVE_STRING_COMPOSITION_H_INCLUDED
#define ARCHIVE_STRING_COMPOSITION_H_INCLUDED

struct unicode_composition_table {
	uint32_t cp1;
	uint32_t cp2;
	uint32_t nfc;
};

CR_END
}
#################################################################################
#
# awk script
#
#################################################################################
cat > ${pickout} <<AWK_END
#
BEGIN {
  FS = ";"
  min = "";
  max = "";
  cmd="sort | awk -F ' ' '{printf \"\\\\t{ 0x%s , 0x%s , 0x%s },\\\\n\",\$1,\$2,\$3}'"
  nfdtbl="${nfdtmp}"
  print "static const struct unicode_composition_table u_composition_table[] = {"
}
END {
  close(cmd)
  print "};"
  print ""
  #
  # Output Canonical Combining Class tables used for translating NFD to NFC.
  #
  printf "#define CANONICAL_CLASS_MIN\\t0x%s\\n", min
  printf "#define CANONICAL_CLASS_MAX\\t0x%s\\n", max
  print ""
  printf "#define IS_DECOMPOSABLE_BLOCK(uc)\\t\\\\\n"
  printf "\\t(((uc)>>8) <= 0x%X && u_decomposable_blocks[(uc)>>8])\\n", highnum
  printf "static const char u_decomposable_blocks[0x%X+1] = {\\n\\t", highnum
  #
  # Output blockmap
  for (i = 0; i <= highnum; i++) {
    if (i != 0 && i % 32 == 0)
      printf "\\n\\t"
    # Additionally Hangul[11XX(17), AC00(172) - D7FF(215)] is decomposable.
    if (blockmap[i] || i == 17 || (i >= 172 && i <= 215))
        printf "1,"
    else
        printf "0,"
  }
  printf "\\n};\\n\\n"
  #
  # Output a macro to get a canonical combining class.
  #
  print "/* Get Canonical Combining Class(CCC). */"
  printf "#define CCC(uc)\\t\\\\\n"
  printf "\\t(((uc) > 0x%s)?0:\\\\\\n", max
  printf "\\tccc_val[ccc_val_index[ccc_index[(uc)>>8]][((uc)>>4)&0x0F]][(uc)&0x0F])\\n"
  print ""
  #
  # Output a canonical combining class value table.
  #
  midcnt = 0
  printf "/* The table of the value of Canonical Cimbining Class */\\n"
  print "static const unsigned char ccc_val[][16] = {"
  print " /* idx=0: XXXX0 - XXXXF */"
  print " { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },"
  for (h = 0; h <= highnum; h++) {
    if (!blockmap[h])
      continue;
    for (m = 0; m < 16; m++) {
      if (!xx_blockmap[h, m])
        continue;
      midcnt++
      printf " /* idx=%d: %03X%1X0 - %03X%1XF */\\n {", midcnt, h, m, h, m
      for (l = 0; l < 15; l++) {
        printf "%d, ", xxx_blockmap[h, m, l]
      }
      printf "%d },\n", xxx_blockmap[h, m, 15]
    }
  }
  printf "};\n"
  #
  # Output the index table of the canonical combining class value table.
  #
  cnt = 0
  midcnt = 0
  printf "\\n/* The index table to ccc_val[*][16] */\\n"
  print "static const unsigned char ccc_val_index[][16] = {"
  print " /* idx=0: XXX00 - XXXFF */"
  print " { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },"
  for (h = 0; h <= highnum; h++) {
    if (!blockmap[h])
      continue;
    cnt++
    printf " /* idx=%d: %03X00 - %03XFF */\\n {", cnt, h, h
    for (m = 0; m < 16; m++) {
      if (m != 0)
          printf ","
      if (xx_blockmap[h, m]) {
          midcnt++
          printf "%2d", midcnt
      } else
          printf " 0"
    }
    printf " },\\n"
  }
  printf "};\\n"
  #
  # Output the index table to the index table of the canonical combining
  # class value table.
  #
  printf "\\n/* The index table to ccc_val_index[*][16] */\\n"
  printf "static const unsigned char ccc_index[] = {\\n ", h
  cnt = 0
  for (h = 0; h <= highnum; h++) {
    if (h != 0 && h % 24 == 0)
      printf "\\n "
    if (blockmap[h]) {
      cnt++;
      printf "%2d,", cnt
    } else
      printf " 0,"
  }
  print "};"
  print ""
}
#
#
function hextoi(hex)
{
  dec = 0
  for (i=0; i < length(hex); i++) {
    x = substr(hex, i+1, 1)
    if (x ~/[0-9]/)
	dec = dec * 16 + x;
    else if (x == "A")
	dec = dec * 16 + 10;
    else if (x == "B")
	dec = dec * 16 + 11;
    else if (x == "C")
	dec = dec * 16 + 12;
    else if (x == "D")
	dec = dec * 16 + 13;
    else if (x == "E")
	dec = dec * 16 + 14;
    else if (x == "F")
	dec = dec * 16 + 15;
  }
  return dec
}
#
# Collect Canonical Combining Class values.
#
\$4 ~/^[0-9A-F]+$/ {
  if (\$4 !~/^0$/) {
    if (min == "") {
      min = \$1
    }
    max = \$1
    high = substr(\$1, 1, length(\$1) -2)
    highnum = hextoi(high)
    mid = substr(\$1, length(\$1) -1, 1)
    midnum = hextoi(mid)
    low = substr(\$1, length(\$1), 1)
    lownum = hextoi(low)
    blockmap[highnum] = 1
    xx_blockmap[highnum, midnum] = 1
    xxx_blockmap[highnum, midnum, lownum] = \$4
  }
}
#
# Following code points are not decomposed in MAC OS.
#   U+2000  - U+2FFF
#   U+F900  - U+FAFF
#   U+2F800 - U+2FAFF
#
#\$1 ~/^2[0-9A-F][0-9A-F][0-9A-F]\$/ {
#        next
#}
#\$1 ~/^F[9A][0-9A-F][0-9A-F]\$/ {
#        next
#}
#\$1 ~/^2F[89A][0-9A-F][0-9A-F]\$/ {
#        next
#}
#
# Exclusion code points specified by  
# http://unicode.org/Public/6.0.0/ucd/CompositionExclusions.txt
##
# 1. Script Specifics
##
\$1 ~/^095[89ABCDEF]\$/ {
    next
}
\$1 ~/^09D[CDF]\$/ {
    next
}
\$1 ~/^0A3[36]\$/ {
    next
}
\$1 ~/^0A5[9ABE]\$/ {
    next
}
\$1 ~/^0B5[CD]\$/ {
    next
}
\$1 ~/^0F4[3D]\$/ {
    next
}
\$1 ~/^0F5[27C]\$/ {
    next
}
\$1 ~/^0F69\$/ {
    next
}
\$1 ~/^0F7[68]\$/ {
    next
}
\$1 ~/^0F9[3D]\$/ {
    next
}
\$1 ~/^0FA[27C]\$/ {
    next
}
\$1 ~/^0FB9\$/ {
    next
}
\$1 ~/^FB1[DF]\$/ {
    next
}
\$1 ~/^FB2[ABCDEF]\$/ {
    next
}
\$1 ~/^FB3[012345689ABCE]\$/ {
    next
}
\$1 ~/^FB4[01346789ABCDE]\$/ {
    next
}
##
# 2. Post Composition Version precomposed characters
##
\$1 ~/^2ADC\$/ {
    next
}
\$1 ~/^1D15[EF]\$/ {
    next
}
\$1 ~/^1D16[01234]\$/ {
    next
}
\$1 ~/^1D1B[BCDEF]\$/ {
    next
}
\$1 ~/^1D1C0\$/ {
    next
}
##
# 3. Singleton Decompositions
##
\$1 ~/^034[01]\$/ {
    next
}
\$1 ~/^037[4E]\$/ {
    next
}
\$1 ~/^0387\$/ {
    next
}
\$1 ~/^1F7[13579BD]\$/ {
    next
}
\$1 ~/^1FB[BE]\$/ {
    next
}
\$1 ~/^1FC[9B]\$/ {
    next
}
\$1 ~/^1FD[3B]\$/ {
    next
}
\$1 ~/^1FE[3BEF]\$/ {
    next
}
\$1 ~/^1FF[9BD]\$/ {
    next
}
\$1 ~/^200[01]\$/ {
    next
}
\$1 ~/^212[6AB]\$/ {
    next
}
\$1 ~/^232[9A]\$/ {
    next
}
\$1 ~/^F9[0-9A-F][0-9A-F]\$/ {
    next
}
\$1 ~/^FA0[0-9A-D]\$/ {
    next
}
\$1 ~/^FA1[025-9A-E]\$/ {
    next
}
\$1 ~/^FA2[0256A-D]\$/ {
    next
}
\$1 ~/^FA[3-5][0-9A-F]\$/ {
    next
}
\$1 ~/^FA6[0-9A-D]\$/ {
    next
}
\$1 ~/^FA[7-9A-C][0-9A-F]\$/ {
    next
}
\$1 ~/^FAD[0-9]\$/ {
    next
}
\$1 ~/^2F[89][0-9A-F][0-9A-F]\$/ {
    next
}
\$1 ~/^2FA0[0-9A-F]\$/ {
    next
}
\$1 ~/^2FA1[0-9A-D]\$/ {
    next
}
##
# 4. Non-Starter Decompositions
##
\$1 ~/^0344\$/ {
    next
}
\$1 ~/^0F7[35]\$/ {
    next
}
\$1 ~/^0F81\$/ {
    next
}
#
# Output combinations for NFD ==> NFC.
#
\$6 ~/^[0-9A-F]+ [0-9A-F]+\$/ {
    split(\$6, cp, " ")
    if (length(\$1) == 4)
        print "0"cp[1], "0"cp[2], "0"\$1 | cmd
    else
        print cp[1], cp[2], \$1 | cmd
    # NFC ==> NFD table.
    if (length(\$1) == 4)
        print "0"\$1, "0"cp[1], "0"cp[2] >>nfdtbl
    else
        print \$1, cp[1], cp[2] >>nfdtbl
}
AWK_END
#################################################################################
# awk script
#
#################################################################################
cat > ${pickout2} <<AWK_END
#
BEGIN {
  FS = " "
  print "struct unicode_decomposition_table {"
  print "\tuint32_t nfc;"
  print "\tuint32_t cp1;"
  print "\tuint32_t cp2;"
  print "};"
  print ""
  print "static const struct unicode_decomposition_table u_decomposition_table[] = {"
}
END {
  print "};"
  print ""
}
{
printf "\t{ 0x%s , 0x%s , 0x%s },\n", \$1, \$2, \$3;
}
AWK_END
#################################################################################
#
# Run awk a script.
#
#################################################################################
append_copyright
awk -f ${pickout} ${inputfile} >> ${outfile}
awk -f ${pickout2} ${nfdtmp} >> ${outfile}
echo "#endif /* ARCHIVE_STRING_COMPOSITION_H_INCLUDED */" >> ${outfile}
echo "" >> ${outfile}
#
# Remove awk the script.
rm ${pickout}
rm ${pickout2}
rm ${nfdtmp}
