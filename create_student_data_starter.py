#! /usr/local/bin/python3
#
'''
Takes a directory of student submissions and creates the first two columns of
a lookup CSV for converting Canvas student IDs to student names for nicer
formatting in their evaluation reports.

There is a third column created in the CSV that has all-empty entries except
for the header. Fill this in by adding student names by hand
in the CSV in Excel.

Author: Matthew A. Turner <maturner01@gmail.com>
Date: 2019-02-16
'''
import glob
import sys

from os.path import basename
from os.path import join as opj


def main(student_submissions_dir,
         write_csv_path='source/data/studentsSpring2019.csv'):

    # Persist student data for this
    with open(write_csv_path, 'w') as f:

        # Initialize output CSV with Canvas names and IDs. I'll load in
        # to Excel afterwards and add the full student names as I'd like
        # them to appear in the student reports.
        f.write('studentCanvasName,studentCanvasId,fullStudentName\n')

        globbled = glob.glob(opj(student_submissions_dir, '*'))
        import ipdb
        ipdb.set_trace()
        for g in globbled:

            # Strip out directory path and remove "late" flag.
            bn = basename(g).replace('_late', '')

            # Create row with three entries, one empty, e.g., '123,turnermatt,'
            row = ','.join(bn.split('_')[:2] + ["\n"])

            # Add the row to the output CSV.
            f.write(row)


if __name__ == '__main__':

    if len(sys.argv) == 2:
        main(sys.argv[1])

    elif len(sys.argv) == 3:
        main(sys.argv[1], sys.argv[2])

    else:
        raise RuntimeError(
            'Script must be called with exactly one or two arguments'
        )
