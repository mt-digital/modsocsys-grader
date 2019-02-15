import std.file;
import std.getopt;

import std.array : array, replace;
import std.algorithm : joiner, map;
import std.conv : to;
import std.json : parseJSON, JSONValue;
import std.path : chainPath, globMatch;
import std.process : spawnProcess;
import std.stdio : write, writeln;

import dli;


int main(string[] args)
{
    string courseId, assignmentId, questionFile;

    if (args.length > 1 )
    {
        if (args[1] == "-h")
        {
            write(HELP_STRING);
            return 0;
        }

        courseId = args[1];
        assignmentId = args[2];
        questionFile = args[3];

        runApp(courseId, assignmentId, questionFile);
    }
    else
    {
        write(HELP_STRING);
        return 1;
    }

    return 0;
}


void runApp(string courseId, string assignmentId, string questionsFile)
{
    QuestionSet questionSet = new QuestionSet(questionsFile);

    /* writeln(questionSet["Ants marching."]["parts"][0]); */
    string submissionsDir = 
        chainPath("homework", "submissions", courseId, assignmentId)
            .array;
    
    Submission[] studentSubmissions = submissionsDir.loadSubmissions;

    Evaluation[] studentEvaluations = 
        studentSubmissions[0..2]
            .map!(a => a.evaluateSubmission(questionSet))
            .array;

    writeln(studentEvaluations.map!"a.studentId".array);
}

bool _checkPartScore(float partScore, float maxPartScore) 
{
    return _inClosedInterval(partScore, 0.0, maxPartScore);
}


bool _inClosedInterval(T)(T x, T a, T b)
{
    return (a <= x && x <= b);
}
/* unittest */
/* { */
/*     assert(!1.0._inClosedInterval(-1.0, 0.0)); */
/*     assert(!1.0._inClosedInterval(2.0, 3.0)); */
/*     assert(1.0._inClosedInterval(-1.0, 1.0)); */
/*     assert(1.0._inClosedInterval(-1000.0, 10.0)); */
/*     /1* assert((-1.0)._inClosedInterval(-2.0, -0.5)); *1/ */
/* } */
        


class Evaluation
{
    string studentId = "112155";
    // Arrays of floats indexed by a string, namely the question title.
    float[][string] questionScores;
    string[][string] questionNotes;
    QuestionSet questionSet;

    public:
        this(QuestionSet qs)
        {
            questionSet = qs;
        }

        void addScore(string questionTitle, float partScore)
        {
            if (questionTitle in questionScores)
                questionScores[questionTitle] = [];

            questionScores[questionTitle] ~= partScore;
        }
        
        // Write the report to file as a PDF.
        void writeReport(string writeFilePath, size_t homeworkNumber) { 
            // Write LaTeX header with student info filled in.
            write(writeFilePath, makeReport(studentId, homeworkNumber));
        }
    
    private:
        string makeReport(string studentId, size_t homeworkNumber)
        {
            string ret = 
`
\documentclass[11pt]{article}
\usepackage{fullpage}
\usepackage[normalem]{ulem}
\useunder{\uline}{\ul}{}
\author{` ~ studentId ~ `}
\begin{document}
\date{\today}
\title{grade report for cogs 122 homework #` ~ homeworkNumber.to!string ~ `}`;

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
`\begin{table}[]
\begin{tabular}{rccl}
\textbf{Question Part} & \textbf{Points Received} & \textbf{Points Possible} & \textbf{Notes} \\ \hline` ~ "\n\n";

            // Keep track of which question we are on.
            size_t qIdx = 1;

            // Iterate over questions, extract and grade parts (see below).
            foreach (string questionTitle, float[] partScores; questionScores)
            {
                // Extract the number of points possible for each qn part.
                string[] partPointsPossible = 
                    questionSet[questionTitle]
                        // Convert from JSONValue to an array.
                        .array
                        // Every element of the array is a JSONValue array
                        // of characters, i.e. a string in another form.
                        .map!(
                            // Explicitly convert each such JSONValue[] 
                            // to be a string.
                            a => a.array.to!string
                        // We want to index later, so convert to an array 
                        // (from complex templated MapResult type).
                        ).array;

                // Iterate over each score in the question's part, w/ index.
                foreach (partIdx, partScore; partScores)
                {
                    // Append new tex source to the existing tex source table.
                    texTable ~=  
                        // Specify data to be included in tex table row...
                        [
                            // Use the Question and Part indices as index.
                            qIdx.to!string ~ "." ~ partIdx.to!string, 
                            partScore.to!string,
                            partPointsPossible[partIdx].to!string,
                            questionNotes[questionTitle][partIdx]

                        // Join strings of data into row with tex command.
                        // End each row with a tex newline typesetting command
                        // and then carriage return the source tex.
                        ].joiner(" & ").to!string ~ `\\` ~ "\n";
                }

                // Finished adding current question's data to table, increment
                // question index.
                ++qIdx;
            }

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


class Submission 
{ 
    string filePath, studentId;
    Evaluation evaluation;
    this(string filePath)
    {
        filePath = filePath;
        this(filePath, "fake");
    }
    this(string filePath, string studentId)
    {
        filePath = filePath;
        studentId = studentId;
    }

    Evaluation evaluateSubmission(QuestionSet qs, bool openFile=false)
    {
        evaluation = new Evaluation(qs); 

        float partScore;
        foreach (qIdx, questionTitle; qs.questionTitles)
        {
            JSONValue question = qs[questionTitle.to!string];

            writeln("\n\nQuestion " ~ qIdx.to!string ~ ": " ~ questionTitle ~ "\n\n");

            if (openFile)
                openFileExternally();

            foreach (partIdx, part; question["parts"].array)
            {
                writeln("Question " ~ qIdx.to!string ~ ", Part " 
                            ~ partIdx.to!string ~ ":\n\n" 
                            ~ part["Description"].to!string);

                writeln("\n\nAnswer from key:\n" ~ part["Answers"].to!string);

                // Condition here true when part score valid and confirmed.
                // partScore itself is set within promptForPartScore.
                while (_promptForPartScore(&partScore, part)) 
                    writeln("\n\n** Grade not confirmed. Repeating part. **\n\n"); 

                evaluation.addScore(questionTitle.to!string, partScore); 
            }
        }

        return evaluation;
    }

    void openFileExternally()
    {
        auto pid = spawnProcess("open " ~ filePath);
        writeln(pid);
    }
}


bool _promptForPartScore(float* partScoreAddr, JSONValue part)
{
    string partDesc = part["Description"].to!string;
    writeln("\nPart description:\n\n" ~ part["Description"].to!string);

    writeln("\nAnswers:\n\n" ~ part["Description"].to!string);
    // Awkward because can't just do to!float for some reason.
    float maxPartScore = part["Points possible"].to!string.to!float;

    while(
        !request(
            "\n\nEnter grade (out of " ~ maxPartScore.to!string ~ ")> ", 
            partScoreAddr,
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

    string userConfirmation;
    while(
        !request(
            "Confirm grade for of " 
                ~ (*partScoreAddr).to!string ~ " (y to confirm)?> ",
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
    string questionTitles;
    size_t[string] titleIndexLookup;

    this(string questionsFile) 
    {
        string questionsString = readText(questionsFile);
        questionsJson = parseJSON(questionsString);    

        string[] questionTitles = 
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
