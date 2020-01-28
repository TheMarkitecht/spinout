
proc assert {exp {msg {}}} {
    tracer asserts "testing: $exp"
    if {$msg eq {}} {set msg "assert failed: $exp"}
    set result [uplevel 1 "expr {$exp}"]
    if $result {} else {error $msg}
}

proc f+ {args} {
    return [file join {*}$args]
}

# returns 1 if the executable at the given path is built for Windows, 0 for 
# an executable for any other OS.
proc isWindowsExecutable {executableFn} {
    file exists [file rootname $executableFn].exe
}

proc x {args} {
    # execute the given tool process with the given options.  return after it has exited.
    # return from the routine any output that wasn't redirected to stdout.
    # note that redirecting to stdout is the default in this routine.
    # to override that, specify one or more redirects along with the tool options.

    # if the first argument begins with a dash, it's assumed to be one of the following
    # error handling modes.  these determine the action if the child fails to launch
    # e.g. because the specified executable is not found, or if the child exits with
    # a non-zero exit status.
    # -abort means abort the script, provide troubleshooting messages on stderr,
    # and exit the Tcl interpreter (status 1).  this is the default action.
    # it prevents displaying (or saving to disk) a large Tcl stack trace simply because a tool failed.
    # -throw means throw a Tcl error with a descriptive message, which can be trapped by
    # try or catch.
    # -ignore means do nothing.

    # in all cases, variable childExitStatus is set in the caller's stack frame.
    # it is an integer if it could be determined from the child, otherwise empty string
    # e.g. because the child failed to launch, or was killed by a kernel signal.

    # in jimsh this works on Windows even if the .exe extension wasn't given.

    #TODO: find out why this throws an error in some environments (Geany, SystemD) when << redirection is used.

    set remainder [lassign $args errorAction]
    if [string match -* $errorAction] {
        if {$errorAction ni [list -abort -throw -ignore]} {
            error "Unrecognized option: $errorAction"
        }
        set args $remainder
    } else {
        set errorAction -abort
    }
    #puts stderr "Run in [pwd]:\n    $args" ;# output verbose format.
    if {[lsearch -regexp $args ^>|^2>|^< ] < 0} {
        # found no argument starting with > or 2> or < chars.  add 3 standard i/o redirections.
        lappend args <@stdin >@stdout 2>@stderr
    }
    upvar childExitStatus childExitStatus
    set childExitStatus {}
    set output {}
    try {
        set output [exec {*}$args ]
        set childExitStatus 0
    } on error {errText errDict} {
        # after a child exits with nonzero process status, this line recovers its output,
        # to be returned to the caller down below.  unfortunately it also includes some
        # explanation of the failure appended to the end by Tcl.  eliminating that would require
        # reworking this proc to redirect all output into a Tcl channel to be flushed and captured into a variable,
        # except any output that was already explicitly redirected.
        set output $errText
        # dict for {k v} $errDict { puts "<k<$k>v>$v" }
        # puts "##$errDict(-errorinfo)##"
        set sm {}
        if [dict exists $errDict -errorcode] {
            lassign $errDict(-errorcode) detectionMethod pid ces
            if {$detectionMethod eq {CHILDSTATUS}} {
                set childExitStatus $ces
                set sm " with exit status $ces"
            }
        }
        if {$errorAction eq {-abort}} {
            puts stderr "Child process failed$sm:\n$args"
            exit 1
        } elseif {$errorAction eq {-throw}} {
            error "Child process failed$sm: $args"
        }
    }
    return $output
}

proc quoteForBash {argList} {
    # pass a Tcl list.
    # return a string containing one bash shell word for each element in the given list.
    # each word is quoted as necessary for reliable use in bash shell.
    set all {}
    set delim {}
    foreach a $argList {
        if { [regexp  ^>|^2>|^<  $a] && ($delim ne {}) } {
            # found a bash redirect operator; use word as-is.
            append all "$delim$a"
        } elseif {[regexp -nocase {[^a-z0-9/._-]} $a]} {
            # surround with double quotes, first removing any existing surrounding ones,
            # and escape any in the middle with a backslash.
            append all "$delim\"[string map [list \" \\\" ] [string trim $a \" ]]\""
        } else {
            # no bash-sensitive characters; use word as-is.
            append all "$delim$a"
        }
        set delim { }
    }
    return $all
}

proc executableSearchDirs {suggestDir} {
    set dirs [split [env PATH {}] : ]
    if {$suggestDir ne {}} {
        set dirs [list $suggestDir {*}$dirs]
    }
    return $dirs
}

proc findExecutable {exeName suggestDir} {
    set exeName [file tail $exeName]
    foreach dir [executableSearchDirs $suggestDir] {
        set fn [f+ $dir $exeName]
        # in jimsh this test is smart enough to work on Windows even if the .exe extension wasn't given.
        if {[file executable $fn]} {
            return $fn
        }
    }
    return {}
}

# returns 1 if script is running in a posix-on-windows emulation system like Cygwin,
# MinGW, or MSYS.  returns 0 on Windows command prompt, or Linux/Unix.
proc systemIsCygwin {} {
    try {
        set toolPath [x -throw which cygpath </dev/null 2>/dev/null]
        return $( [string length [string trim $toolPath]] > 0 )
    } on error {errText errDict} {
        # could not invoke 'which'.  probably a Windows system.
        return 0
    }
}

# returns the temporary file directory suggested by the OS.  however that
# might not be the one expected by any tool executables that are launched.
proc systemTempDir {} {
    return [env TEMP /tmp]
}

# returns the temporary file directory suggested by the Windows OS. 
# calling this is likely to throw an error on a non-Windows OS.
proc windowsSystemTempDir {} {
    return [env TEMP]
}

# returns the temporary file directory suggested by the non-Windows OS. 
# this is likely to cause an error when trying to use this dir on a Windows OS.
proc posixSystemTempDir {} {
    return /tmp
}

# returns 1 if the given file or directory path can be determined to be a
# Windows-style path.  otherwise 0.
# note that a bare filename with no path separators in it might not be recognized.
proc isWindowsPath {path} {
    if {[string first \\ $path] >= 0} {return 1}
    if {[string index $path 1] eq {:}} {return 1}
    return 0
}

# reformats the given path string to Windows format.
proc toWindowsPath {path} {
    #TODO: add some more logic to recognize and convert MSYS-style path letters (/c/one/two) and Cygwin-style path letters (/cygdrive/c/one/two).
    string map [list / \\ ] $path
}

# convert from a posix-style path name to a windows-style path name.
# this uses the cygpath tool on a posix-on-windows emulation system like Cygwin,
# MinGW, or MSYS.  those systems do some additional mapping besides
# changing the style of separators.  for example they might map
# /tmp to C:\Users\myUser\AppData\Local\Temp.
# that's important when the path is passed to an external tool that
# might not understand it.
proc cygToWindowsPath {path} {
    x -throw cygpath -w $path </dev/null
}

# reformats the given path string to Posix format.
proc toPosixPath {path} {
    string map [list \\ / ] $path
}

# reformats the given path string to be suitable
# for passing to the given tool executable for its own use.
proc formatPathFor {path executableFn} {
    if {[isWindowsExecutable $executableFn]} {
        if {[systemIsCygwin]} {
            return [cygToWindowsPath $path]
        } else {
            return [toWindowsPath $path]
        }
    }
    return [toPosixPath $path]
}

