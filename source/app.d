import std.algorithm;
import std.getopt;
import std.stdio;


int main(string[] args)
{
    string courseId, assignmentId, questionFile;

    if (args[1] == "-h")
    {
        write(HELP_STRING);
        return 0;
    }
    
    courseId = args[1];
    assignmentId = args[2];
    questionFile = args[3];

    runApp(courseId, assignmentId, questionFile);

    return 0;
}


void runApp(string courseId, string assignmentId, string questionFile)
{
    joiner([courseId, assignmentId, questionFile], "\n")
        .writeln;
}


string HELP_STRING = 
`
Modeling Social Systems assignment grading helper

./modsocsys-grader <courseId> <assignmentId> <questionFile>

        courseId: all-digits code for the course on Canvas
        assignmentId: all-digits code for the assignment on Canvas
        questionFile: JSON with assignment questions with the following structure,
                            {
                                "questions": [
                                    {
                                        "associatedFileEnding": "rainbow.nlogo",
                                        "title": "Taste the rainbow",
                                        "parts": [
                                            {
                                                "description": "a description",
                                                "pointsPossible": 10
                                            }, 
                                            {"description": ...}, 
                                            ...
                                        ]
                                    },
                                    {
                                        "associatedFileEnding": "ants.nlogo",
                                        "title": "Ants go marching",
                                        "parts": [ ... ]
                                    },
                                    ...
                                ]
                            }
`;
