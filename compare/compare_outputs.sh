#!/bin/bash

#########################################################
# OUTPUT COMPARISON SCRIPT
# Compare indexed vs nonindexed output folders
#########################################################

INDEXED_DIR="$HOME/compare/indexed"
NONINDEXED_DIR="$HOME/compare/nonindexed"

REPORT_DIR="$HOME/compare/report"

mkdir -p "$REPORT_DIR"

SUMMARY="$REPORT_DIR/summary.txt"
MISSING="$REPORT_DIR/missing_files.txt"
SIZE_MISMATCH="$REPORT_DIR/size_mismatch.txt"
CONTENT_MISMATCH="$REPORT_DIR/content_mismatch.txt"
MATCHED="$REPORT_DIR/matched_files.txt"

# Clear old reports
> "$SUMMARY"
> "$MISSING"
> "$SIZE_MISMATCH"
> "$CONTENT_MISMATCH"
> "$MATCHED"

echo "==================================================" | tee -a "$SUMMARY"
echo "OUTPUT COMPARISON REPORT" | tee -a "$SUMMARY"
echo "==================================================" | tee -a "$SUMMARY"

echo "" | tee -a "$SUMMARY"

#########################################################
# STEP 1 : FILE COUNT
#########################################################

indexed_count=$(find "$INDEXED_DIR" -type f | wc -l)
nonindexed_count=$(find "$NONINDEXED_DIR" -type f | wc -l)

echo "Indexed Folder File Count     : $indexed_count" | tee -a "$SUMMARY"
echo "NonIndexed Folder File Count  : $nonindexed_count" | tee -a "$SUMMARY"

echo "" | tee -a "$SUMMARY"

#########################################################
# STEP 2 : MISSING FILE ANALYSIS
#########################################################

echo "==================================================" | tee -a "$SUMMARY"
echo "STEP 2 : Missing File Analysis" | tee -a "$SUMMARY"
echo "==================================================" | tee -a "$SUMMARY"

missing_in_indexed=0
missing_in_nonindexed=0

# Missing in indexed
for f in "$NONINDEXED_DIR"/*; do

    fname=$(basename "$f")

    if [ ! -f "$INDEXED_DIR/$fname" ]; then

        echo "Missing in INDEXED : $fname" \
        | tee -a "$MISSING"

        ((missing_in_indexed++))
    fi
done

# Missing in nonindexed
for f in "$INDEXED_DIR"/*; do

    fname=$(basename "$f")

    if [ ! -f "$NONINDEXED_DIR/$fname" ]; then

        echo "Missing in NONINDEXED : $fname" \
        | tee -a "$MISSING"

        ((missing_in_nonindexed++))
    fi
done

echo "Missing in Indexed Folder     : $missing_in_indexed" \
| tee -a "$SUMMARY"

echo "Missing in NonIndexed Folder  : $missing_in_nonindexed" \
| tee -a "$SUMMARY"

echo "" | tee -a "$SUMMARY"

#########################################################
# STEP 3 : FILE SIZE ANALYSIS
#########################################################

echo "==================================================" | tee -a "$SUMMARY"
echo "STEP 3 : File Size Analysis" | tee -a "$SUMMARY"
echo "==================================================" | tee -a "$SUMMARY"

size_mismatch_count=0
same_size_count=0

for f in "$NONINDEXED_DIR"/*; do

    fname=$(basename "$f")

    if [ -f "$INDEXED_DIR/$fname" ]; then

        size1=$(stat -c%s "$f")
        size2=$(stat -c%s "$INDEXED_DIR/$fname")

        if [ "$size1" -ne "$size2" ]; then

            echo "==================================================" \
            >> "$SIZE_MISMATCH"

            echo "FILE : $fname" \
            >> "$SIZE_MISMATCH"

            echo "NonIndexed Size : $size1 bytes" \
            >> "$SIZE_MISMATCH"

            echo "Indexed Size    : $size2 bytes" \
            >> "$SIZE_MISMATCH"

            diff_size=$((size1-size2))

            echo "Difference       : $diff_size bytes" \
            >> "$SIZE_MISMATCH"

            echo "" >> "$SIZE_MISMATCH"

            ((size_mismatch_count++))

        else

            ((same_size_count++))
        fi
    fi
done

echo "Same Size Files         : $same_size_count" \
| tee -a "$SUMMARY"

echo "Size Mismatch Files     : $size_mismatch_count" \
| tee -a "$SUMMARY"

echo "" | tee -a "$SUMMARY"

#########################################################
# STEP 4 : CONTENT COMPARISON
#########################################################

echo "==================================================" | tee -a "$SUMMARY"
echo "STEP 4 : Detailed Content Comparison" | tee -a "$SUMMARY"
echo "==================================================" | tee -a "$SUMMARY"

content_mismatch_count=0
matched_count=0

for f in "$NONINDEXED_DIR"/*; do

    fname=$(basename "$f")

    if [ -f "$INDEXED_DIR/$fname" ]; then

        # Sort temporarily
        sort "$f" > /tmp/non_sorted.txt
        sort "$INDEXED_DIR/$fname" > /tmp/index_sorted.txt

        md5_1=$(md5sum /tmp/non_sorted.txt | awk '{print $1}')
        md5_2=$(md5sum /tmp/index_sorted.txt | awk '{print $1}')

        if [ "$md5_1" != "$md5_2" ]; then

            ((content_mismatch_count++))

            echo "==================================================" \
            >> "$CONTENT_MISMATCH"

            echo "FILE : $fname" \
            >> "$CONTENT_MISMATCH"

            echo "==================================================" \
            >> "$CONTENT_MISMATCH"

            non_lines=$(wc -l < /tmp/non_sorted.txt)
            idx_lines=$(wc -l < /tmp/index_sorted.txt)

            echo "NonIndexed Line Count : $non_lines" \
            >> "$CONTENT_MISMATCH"

            echo "Indexed Line Count    : $idx_lines" \
            >> "$CONTENT_MISMATCH"

            line_diff=$((non_lines-idx_lines))

            echo "Line Difference       : $line_diff" \
            >> "$CONTENT_MISMATCH"

            echo "" >> "$CONTENT_MISMATCH"

            #################################################
            # Missing in indexed
            #################################################

            echo "----- RECORDS ONLY IN NONINDEXED -----" \
            >> "$CONTENT_MISMATCH"

            comm -23 /tmp/non_sorted.txt /tmp/index_sorted.txt \
            | head -100 \
            >> "$CONTENT_MISMATCH"

            echo "" >> "$CONTENT_MISMATCH"

            #################################################
            # Extra in indexed
            #################################################

            echo "----- RECORDS ONLY IN INDEXED -----" \
            >> "$CONTENT_MISMATCH"

            comm -13 /tmp/non_sorted.txt /tmp/index_sorted.txt \
            | head -100 \
            >> "$CONTENT_MISMATCH"

            echo "" >> "$CONTENT_MISMATCH"

            #################################################
            # Unified diff
            #################################################

            echo "----- FULL DIFF SAMPLE -----" \
            >> "$CONTENT_MISMATCH"

            diff -u /tmp/non_sorted.txt /tmp/index_sorted.txt \
            | head -200 \
            >> "$CONTENT_MISMATCH"

            echo "" >> "$CONTENT_MISMATCH"

        else

            echo "$fname" >> "$MATCHED"

            ((matched_count++))
        fi
    fi
done

echo "Fully Matched Files     : $matched_count" \
| tee -a "$SUMMARY"

echo "Content Mismatch Files  : $content_mismatch_count" \
| tee -a "$SUMMARY"

echo "" | tee -a "$SUMMARY"

#########################################################
# STEP 5 : ROOT CAUSE ANALYSIS
#########################################################

echo "==================================================" | tee -a "$SUMMARY"
echo "POSSIBLE ROOT CAUSES AFTER INDEXING" | tee -a "$SUMMARY"
echo "==================================================" | tee -a "$SUMMARY"

cat << EOF >> "$SUMMARY"

1. Query execution plan changed
   - FULL TABLE SCAN -> INDEX RANGE SCAN

2. Wrong composite index order

3. Missing leading column usage

4. Stale optimizer statistics

5. TRIM / UPPER / NVL usage bypassing index

6. Trailing spaces in character columns

7. Row order dependency in application logic

8. Duplicate elimination due to indexed access path

9. Nested loop join chosen after indexing

10. Cursor fetch sequence changed

11. Partial commits / transaction visibility issue

12. Legacy Pro*C code relying on implicit row ordering

13. Parallel execution timing differences

14. Index corruption or unusable index

15. Missing rows due to join condition optimization

EOF

echo "" | tee -a "$SUMMARY"

#########################################################
# FINAL OUTPUT
#########################################################

echo "==================================================" | tee -a "$SUMMARY"
echo "ANALYSIS COMPLETED" | tee -a "$SUMMARY"
echo "==================================================" | tee -a "$SUMMARY"

echo "" | tee -a "$SUMMARY"

echo "Generated Reports:" | tee -a "$SUMMARY"

echo "$SUMMARY" | tee -a "$SUMMARY"
echo "$MISSING" | tee -a "$SUMMARY"
echo "$SIZE_MISMATCH" | tee -a "$SUMMARY"
echo "$CONTENT_MISMATCH" | tee -a "$SUMMARY"
echo "$MATCHED" | tee -a "$SUMMARY"

echo ""
echo "Analysis completed successfully."
