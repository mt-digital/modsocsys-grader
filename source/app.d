module app;

import std.getopt;

import std.array : array, replace, split;
import std.algorithm : joiner, map, sum;
import std.conv : to;
import std.file : dirEntries, readText, SpanMode, write;
import std.json : parseJSON, JSONValue;
import std.path : baseName, chainPath, globMatch;
import std.process : spawnShell;
import std.range : chunks, repeat;
import std.stdio : writeln;

import dli;

import services : StudentLookup;

int main(string[] args)
{
    string courseId, assignmentId, questionFile;

    if (args.length > 1 )
    {
        if (args[1] == "-h")
        {
            writeln(HELP_STRING);

            auto sl = new StudentLookup("source/data/studentsSpring2019.csv");
            writeln(sl.getStudentName("28157"));  // MH
            writeln(sl.getStudentName("27595"));  // HR
            return 0;
        }

        courseId = args[1];
        assignmentId = args[2];
        questionFile = args[3];

        if (args.length >= 5 && args[4] == "--openFile")
            runApp(courseId, assignmentId, questionFile, true);
        else
            runApp(courseId, assignmentId, questionFile);
    }
    else
    {
        writeln(HELP_STRING);
        return 1;
    }

    return 0;
}


void runApp(string courseId, string assignmentId, string questionsFile, bool openFile=false)
{
    // The questionsFile is a specifically-formatted JSON
    // with all multi-part questions, the points per part, 
    // and suggested answers for each part.
    QuestionSet questionSet = new QuestionSet(questionsFile);

    // Location where student submissions are to be found.
    string submissionsDir = 
        chainPath("homework", "submissions", courseId, assignmentId)
            .array;
    
    // Load each student's submission.
    /* Submission[] studentSubmissions = submissionsDir.loadSubmissions; */
    // XXX  NEED TO ADD THIS AS A CLI OPTION OR GLOB OVER DOCX AND PDF AND
    // XXX  WE'LL NEED TO HANDLE NETLOGO ON THE NEXT HW; doin that next refactor
    Submission[] studentSubmissions = submissionsDir.loadSubmissions("*.pdf");

    // Run the evaluation method on each submission, using the questionSet
    // as the source of solutions.
    Evaluation[] studentEvaluations = 
        studentSubmissions  //[0..1]
            .map!(a => a.evaluateSubmission(questionSet, openFile))
            .array;

    // Specify directory to which we write evaluation PDFs.
    string evaluationDir = 
        chainPath("homework", "evaluations", courseId, assignmentId)
            .array;

    // Write each student's evaluation to the evaluation directory.
    foreach (eval; studentEvaluations)
        eval.writeReport(evaluationDir, 1);
}

bool _checkPartScore(float partScore, float maxPartScore) 
{
    return _inClosedInterval(partScore, 0.0, maxPartScore);
}


bool _inClosedInterval(T)(T x, T a, T b)
{
    return (a <= x && x <= b);
}


class Evaluation
{
    string studentName;
    string studentId;
    // Arrays of floats indexed by a string, namely the question title.
    float[][string] questionScores;
    string[][string] questionNotes;
    QuestionSet questionSet;

    StudentLookup studentLookup;

    public:
        this(QuestionSet qs, string sName, string sId, 
             string studentLookupCsv="source/data/studentsSpring2019.csv")
        {
            questionSet = qs;
            
            studentName = sName;
            studentId = sId;

            studentLookup = new StudentLookup(studentLookupCsv);
        }

        void addScore(string questionTitle, float partScore, string partNotes)
        {
            // If this question is not yet tracked by this evaluation,
            // begin tracking it by adding empty entries to these assoc arrays.
            if (!(questionTitle in questionScores))
            {
                questionScores[questionTitle] = [];
                questionNotes[questionTitle] = [];
            }

            questionScores[questionTitle] ~= partScore;
            questionNotes[questionTitle] ~= partNotes;
        }
        
        // Write the report to file as a PDF.
        void writeReport(string writeDir, size_t homeworkNumber) 
        { 
            // Write LaTeX header with student info filled in.
            string writePath = 
                chainPath(writeDir, studentId ~ ".tex").to!string;

            write(writePath, makeReport(studentId, homeworkNumber));

            writeln("\nWrote " ~ studentLookup.getStudentName(studentId) 
                    ~ "'s evaluation to " ~ writePath);
        }
    
    private:
        string makeReport(string studentId, size_t homeworkNumber)
        {
            string ret = 
`
\documentclass[10pt]{article}
\usepackage{fullpage}
\usepackage[normalem]{ulem}
\useunder{\uline}{\ul}{}

\usepackage{array}
\usepackage{graphicx}
\usepackage{subcaption}
\usepackage{booktabs}

\pagestyle{empty}

\newcolumntype{L}{>{\centering\arraybackslash}m{2.5in}}

\begin{document}

{\large\bf \centering
Evaluation of COGS 122 HW ` ~ homeworkNumber.to!string ~ `} \\[1em]
{\large \today} \\
{\large ` ~ studentLookup.getStudentName(studentId) ~ `} \\[5em]
`;

            ret ~= latexTable();

            ret ~= "\n\\end{document}";

            return ret;
        }

        /**
         * Create a LaTeX table with the grade for each part, how many points
         * were possible on that part, and notes for why points were marked 
         * down, which is the core of the grade report 
         * that is written to PDF.
         */
        string latexTable()
        {
            // Initialize the table with table header elements.
            string texTable = 
`
  \begin{table}[ht]
  \begin{tabular}{rccL}
    \textbf{Question Part} & \textbf{Points Received} & \textbf{Points Possible} & \textbf{Notes} \\ \toprule` ~ "\n\n";

            // Keep track of which question we are on.
            size_t qIdx = 1;

            // Iterate over questions, extract and grade parts (see below).
            foreach (string questionTitle, float[] partScores; questionScores)
            {
                // Extract the number of points possible for each qn part.
                string[] partPointsPossible = 
                    questionSet[questionTitle]["parts"]
                        // Convert from JSONValue to an array.
                        .array
                        // Every element of the array is a JSONValue array
                        // of characters, i.e. a string in another form.
                        .map!(a => a["Points possible"].to!string)
                        .array;

                // Iterate over each score in the question's part, w/ index.
                foreach (partIdx, partScore; partScores)
                {
                    string questionPartIndex = qIdx.to!string ~ "." 
                                               ~ (partIdx + 1).to!string;
                    // Make question part bold face if start of new question.
                    if (partIdx == 0)
                        questionPartIndex = `{\large \bf` ~ questionPartIndex ~ `}`;

                    // Append new tex source to the existing tex source table.
                    texTable ~=  "\t" ~

                        // Specify data to be included in tex table row...
                        [
                            // Use the Question and Part indices as index.
                            questionPartIndex, 
                            partScore.to!string,
                            partPointsPossible[partIdx].to!string,
                            questionNotes[questionTitle][partIdx]

                        // Join strings of data into row with tex command.
                        // End each row with a tex newline typesetting command
                        // and then carriage return the source tex.
                        ].joiner(" & ").to!string ~ `\\` ~ "\\midrule\n\n";
                }

                // Finished adding current question's data to table, increment
                // question index.
                ++qIdx;
            }


            float totalPoints = 0.0;
            float totalPointsPossible = 0.0;
            foreach (questionTitle; questionSet.questionTitles)
            {
                totalPoints += 
                    questionScores[questionTitle].sum;

                totalPointsPossible += 
                    questionSet[questionTitle]["parts"]
                        .array
                        .map!(a => a["Points possible"].integer.to!float)
                        .array
                        .sum;
            }

            // Add total. Close the tabular and table environments.
            texTable ~= 
`
\multicolumn{1}{r}{\large \bf Total:} & \large ` ~ totalPoints.to!string ~ ` & \large ` ~ totalPointsPossible.to!string ~ ` &  \\
\bottomrule
\end{tabular}
\end{table}
`;

            return texTable;
        }
}


Submission[] loadSubmissions(string submissionsDir, 
                             string extension="*.docx")
{
    string[] submissionFiles = 

        dirEntries(
            submissionsDir, 
            extension, 
            SpanMode.shallow
        )
        .map!"a.to!string"
        .array;

    return submissionFiles
            .map!(a => new Submission(a))
            .array;
}


/**
 * Representation of a student homework submission. Aware of the file (or
 * eventually files) associated with different questions on the assignment.
 * Provides a method, `evaluateSubmission`, which, in other words,
 * grades the student's solution. For clarity we chose to call the grades the
 * student receives, along with maximum number of points and 
 * any notes on what the student got wrong, the student's evaluation, 
 * encapsulated in the Evaluation class.
 */
class Submission 
{ 
    string filePath, studentName, studentId;
    Evaluation evaluation;

    public:
    /**
     * fp example: dir/to/subs/dentstu_10207_1859842_COGS122-HW1.docx
     * Student name would be dent, stu, and their ID would be 10207. 
     * Late submissions have `_late` immediately following the student name;
     * I decided to just remove that if it's there and deal with that separately.
     *
     * Arguments:
     *  fp: string representation of the path to the student's file submitted
     *      through CatCourses (UCM Canvas).
     *
     * Returns:
     *      New Submission instance with two attributes in addition to the 
     *      student's file submission path. The constructor reads the student's
     *      compressed, reversed name (e.g. dentstu for Stu Dent) and 
     *      Canvas student ID (not their UCM/school ID) from the file path. 
     */
    this(string fp)
    {
        filePath = fp;
        string[2] name_id = baseName(fp).replace("late_","").split("_")[0..2];
        studentName = name_id[0];
        studentId = name_id[1];
    }

    /**
     * Evaluate this current submission using the QuestionSet qs as the 
     * rubric. Setting the openFile switch opens the student submission using
     * the MacOS `open` command, which automatically chooses the right program. 
     * For this course, files will be .docx, .pdf, or .nlogo, I suspect. 
     * I think this would work on Linux as well.
     */
    Evaluation evaluateSubmission(QuestionSet qs, bool openFile=false)
    {
        evaluation = new Evaluation(qs, studentName, studentId); 
        float partScore;
        string notes;
        foreach (qIdx, questionTitle; qs.questionTitles)
        {
            JSONValue question = qs[questionTitle.to!string];

            // Display question name boldly.
            writeln("\n\n" ~ "=".repeat(40).joiner("").to!string);
            writeln("Question " ~ (qIdx + 1).to!string ~ ": " 
                    ~ questionTitle);
            writeln("=".repeat(40).joiner("").to!string ~ "\n\n");

            // Open the file, giving user some info on what's going on.
            if (openFile && qIdx == 0)
            {
                writeln("File path:");
                writeln(filePath);
                openFileExternally(filePath);
            }
            
            // A question has multiple parts; iterate over these parts.
            foreach (partIdx, part; question["parts"].array)
            {
                // Inform user which part they are on.
                writeln("\nQuestion " ~ (qIdx + 1).to!string ~ ", Part " 
                        ~ (partIdx + 1).to!string ~ ":\n\n" 
                        ~ part["Description"].to!string);

                // Condition here true when part score valid and confirmed.
                // partScore itself is set within promptForPartScore.
                while (_promptForPartScore(&partScore, part, &notes)) 
                    writeln("\n\n** Grade not confirmed. Repeating part. **\n\n"); 

                // Add the score and any notes to the evaluation.
                evaluation.addScore(questionTitle.to!string, partScore, notes); 
            }
        }

        return evaluation;
    }


    private:

    /// Open the file associated with a part. Tell user what command was issued.
    void openFileExternally(string filePath)
    {
        string cmd = `/usr/bin/open "` ~ filePath ~ `"`;
        writeln("Shell command to open submission:");
        writeln(cmd);
        spawnShell(cmd);
        }
}


bool _promptForPartScore(float* partScorePtr, JSONValue part, string* notesPtr)
{
    string partDesc = part["Description"].to!string;

    writeln("\n\nAnswer from key:\n" 
            ~ part["Answers"]
                .array
                .map!`a.to!string.replace("\"", "")`
                .joiner("\n")
                .to!string);


    /* writeln("\nAnswers:\n\n" ~ part["Description"].to!string); */
    // Awkward because can't just do to!float for some reason.
    float maxPartScore = part["Points possible"].to!string.to!float;

    while(
        !request(
            "\n\nEnter grade (out of " ~ maxPartScore.to!string ~ ")> ", 
            partScorePtr,
            (float partScore) { 
                return _checkPartScore(partScore, maxPartScore); 
            }
        )
    )
    { 
        writeln(
            "Not a floating point number between 0 and " 
                ~ maxPartScore.to!string
        ); 
    }

    while(
        !request(
            "\n\nNotes> ", 
            notesPtr
        )
    ){ }

    string userConfirmation;
    while(
        !request(
            "Confirm grade for of " 
                ~ (*partScorePtr).to!string ~ " (y to confirm)?> ",
            &userConfirmation,
            (string userConf) { return userConf != "y"; }
        )
    )
    { 
        // User did not confirm, return false meaning the part score has 
        // not been reliably set.
        return false;
    }
    // Does not return; when this fn gets here, the partScore has been set
    // and will be used by the evaluate method of Submission class.
    return true;
}


class QuestionSet
{
    JSONValue questionsJson;
    string[] questionTitles;
    size_t[string] titleIndexLookup;

    this(string questionsFile) 
    {
        string questionsString = readText(questionsFile);
        questionsJson = parseJSON(questionsString);    

        questionTitles = 
            questionsJson.array
                         .map!(a => a["Title"].to!string.replace("\"", ""))
                         .array;    

        foreach (idx, questionTitle; questionTitles)
            titleIndexLookup[questionTitle] = idx;
    }

    JSONValue opIndex(string questionTitle)
    {
        return questionsJson[titleIndexLookup[questionTitle]];
    }
}


string HELP_STRING = 
`
Modeling Social Systems assignment grading helper

./modsocsys-grader <courseId> <assignmentId> <questionFile>

        courseId: all-digits code for the course on Canvas
        assignmentId: all-digits code for the assignment on Canvas
        questionFile: JSON with assignment questions with 
                      the following structure,
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
