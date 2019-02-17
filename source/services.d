/** 
 * Data served to the Application from Canvas. This will fetch student 
 * information, such as their full first and last name with capitalization
 * given their Canvas student ID and push student evaluations to Canvas.
 */
module services;

import std.array : array;
import std.csv : csvReader;
import std.file : readText;
import std.range : inputRangeObject, InputRange;
import std.stdio : writeln;
import std.string : strip;
import std.typecons : Tuple;


class StudentLookup
{
    string[string] studentNameLookups;

    this(string studentCsvLookupPath="source/data/studentsSpring2019.csv")
    {
        string csvText = readText!string(studentCsvLookupPath);

        string[string][] rows = 
            csvReader!(string[string])
                (
                    readText(studentCsvLookupPath), 
                    null
                )
                .array;

        foreach (row; rows)
            studentNameLookups[row["studentCanvasId"]] = row["fullStudentName"];
    }

    string getStudentName(string studentId)
    {
        return studentNameLookups[studentId];        
    }
}
