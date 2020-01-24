#!jimsh

# Spinout
# A Superb Pinout creation and maintenance tool for FPGA engineers.
# by Mark Hubbard

# requires jimsh.  Jim is a modern, small-footprint, object-oriented Tcl interpreter.
# http://jim.tcl.tk/

# see the examples/ directory for example scripts using Spinout.

# Spinout can be used from the command line on Linux/Unix:
    #   ./jimsh spinout.tcl
    #   Spinout shortcuts
# ...and then whatever commands you need for your project.

# Spinout can be used from the command line on Windows:
    #   jimsh spinout.tcl
    #   Spinout shortcuts
# ...and then whatever commands you need for your project.

# Spinout can be used in a script, running in jimsh:
    # package require spinout
    # Spinout shortcuts
# ...and then whatever commands you need for your project.

# if you work on a Linux/Unix system, and you want to mark that
# script as executable, so you can invoke it without typing "jimsh",
# you'll need to add the standard "shebang" line at the very top:  #!jimsh
# and make sure your shell can locate jimsh on it search path.

# if you get an error such as "Can't load package spinout", try setting
#   JIMLIB=.
# in your command line shell environment before running your script.
# on Linux (bash) that looks like:  export JIMLIB=.
# on Windows (cmd.exe) that looks like:  set JIMLIB=.
# that tells jimsh where to search for package scripts.  that's a problem
# more often on Windows, because there, if you don't give the path to the jimsh
# exectutable when you launch jimsh, Jim can't extract the path from Windows OS.
# then it doesn't know where its executable is stored.  then it doesn't know
# to search there.  
# instead of "." (meaning the current working directory), you can also give 
# an explicit path to the directory where spinout.tcl is stored.  you can also 
# give a list of paths to search, separated by colons (:).

######  load all required packages.  ####################
# this also serves to verify we're running in jimsh and not some other Tcl shell,
# and that jimsh has oo support built-in, or can load it.
package require oo
package require ooExtend

######  classes modeling the design.  ####################
class Signal {
    bus {}
    bank {}
    pin {}
    direction {}
    standard {}
}

class Bus {
    name {}
    min 0
    max 0
}

class Design {
    spinout {}
    device {}
    signals {}
    buses {}
}

# class method acting as object factory, to load a Design from a 
# Notion exported CSV file describing it.
proc {Design loadNotionCsv} {device csvFn} {
    #TODO: eliminate obsolete pins etc
#        if {[string match -nocase {*(n)} $name]} continue
 #       if {[string match -nocase {*remove pin*} [fetch $row Feature]]} continue
}

######  classes modeling the device package.  ####################
class Pin {
    bank {}
    pinNum {}
}

class Bank {
    num 0
    pins {}
}

class Device {
    spinout {}
    partNum {}
    banks {}
}

# class method acting as object factory, to load a Device from a Spinout device file describing it.
proc {Device load} {deviceFn} {
}

# class method acting as object factory, to create a new empty Device with just a part number.
proc {Device create} {partNum} {
}

Device method applyPackageQuartus {projectPath} {
    #TODO: extract the device package's available pins and banks into the device object model.
}

######  classes modeling data files  ####################

# colms maps name to dataColm object.
# colmOrder lists the names in the order they appear in the file.
# both methods of finding a column are required.
class DataTable {
    colms {}
    colmOrder {}
    rows {}
}

DataTable method colmByName {colmName} {
    return $colms($colmName)
}

DataTable method colmByIdx {colmIdx} {
    return [lindex $colmOrder $colmIdx]
}

class DataColm {
    name {}
    idx 0
}

class DataRow {
    table {}
    vList {}
    vDic {}
}

DataRow method updateDic {row} {
    # map a list of values into a dictionary keyed by column headers.  memorize it in vDic.
    # this costs extra time on thousands of rows, so don't do it if not needed. 
    set vDic [dict create]
    foreach v $vList h [$file get colmOrder] {
        dict set vDic $h $v
    }
}

DataRow method vByIdx {colmIdx} {
    # return the value in the given column number.
    return [lindex $vList $colmIdx]
}

DataRow method vByName {colmName} {
    # return the value in the given column name.
    # this is done without vDic, so vDic doesn't have to be built if it's not needed.
    return [lindex $vList [[$file colmByName $colmName] idx]]
}

# CsvFile is a specialization (subclass) of DataTable.
class CsvFile DataTable {
    fn {}
}

# class method acting as object factory, to load a csvFile object graph into memory from 
# an ordinary .CSV disk file (comma-separated values).
factory CsvFile load {rawFn} {
    set fn $rawFn
    set f [open $fn r]
    set dataLines [lassign [split [read $f] \n ] headerLine]
    close $f

    # parse header line into csvColm objects and an indexing array.
    set headers [[CsvRow fromRawLine $headerLine] get vList]
    # note that if the file was exported from Notion, it might contain nonprintable characters, 
    # especially at the start of the file.  those can prevent a naive script from recognizing the header row.  
    # here shave off characters to prevent that problem.
    lassign $headers hdr0
    if {[string range $hdr0 end-5 end] eq {Signal} } {
        set headers [lreplace $headers 0 0 Signal]
    }
    set idx -1
    foreach h $headers {
        set colm [DataColm new [list name $h idx [incr idx]]]
        lappend colmOrder $colm
        set colms($h) $colm
    }

    # parse data rows into objects.
    foreach ln $dataLines {
        set row [CsvRow fromRawLine $ln]
        
        # skip blank rows.
        set name [string trim [fetch $row Signal]]
        if {$name eq {} } continue    
        
        lappend rows $row    
    }
}

class CsvRow DataRow {
}

# class method acting as object factory, to split a raw line of CSV text into a row of data values.
factory CsvRow fromRawLine {rawTextLine} {
    # remove surrounding quotes due to embedded commas.
    foreach {match bare delim1 quoted delim2 delim3} [regexp -all -inline $::CsvRow::itemRe $rawTextLine] {
        if {$quoted ne {}} {
            lappend vList $quoted
        } else {
            lappend vList $bare
        }
    }
}

set ::CsvRow::itemRe [string map [list { } {} \n {}] {  
    ([^",]+?) (,|$)  |  
    ["] ([^"]+?) ["] (,|$)  |  
    (,|$)  
}]


######  classes modeling the user's available commands  ####################

class EmptyClass {} {
    junk {}
}

# this class models the Spinout tool as a whole.
# the main goal of this class is to map the user's command semantics onto
# the details of the object-oriented semantics of the object models.
# methods in this class are commands available to the user.
# variables in this class are ones the user would typically think of as "globals".
# many of his commands will deal with those variables by default, without him
# mentioning those variables explicitly.
class Spinout {
    device {}
    design {}
}

proc {Spinout constructor} {} {
}

set junk {
    # method dispatcher is not called directly by the user; it's plumbing.
    Spinout method _dispatch {cmd args} {
        if {cmd in [Spinout methods]} {
            # dispatch this call to the singleton instance of Spinout.
            tailcall $spinout $cmd {*}$args
        } else {
            # this command isn't recognized as a method; dispatch this call to elsewhere in the interp.
            tailcall Spinout _old_unknown $cmd {*}$args
        }
    }

    proc {Spinout _old_unknown} {cmd args} {
        tailcall error "Unknown command: $cmd"
    }

    proc {Spinout init} {} {
        # insert a new procedure (the Spinout dispatcher) in the chain of "unknown" command handlers.
        if {[exists -command unknown]} {
            rename unknown {Spinout _old_unknown}
        }
        alias unknown Spinout _dispatch
    }
}



# class method to initialize command shortcuts using a singleton instance of Spinout.
# using this is optional.  without it, you can still instantiate and use Spinout's 
# object models directly.  that way is less suitable for the command line, and 
# more suitable for integrating into a larger tool, workflow, or build automation system.
proc {Spinout shortcuts} {} {
    set ::spinout [Spinout new]
    
    # make each Spinout method accessible as a bare command name in the interp.
    # this way the user doesn't have to type "spinout" on every command, and yet
    # the command still gets the benefits of being implemented as a method.
    foreach m [Spinout methods] {
        if {$m ni [EmptyClass methods]} {
            alias $m ::spinout $m
        }
    }
}

Spinout method loadDevice {deviceFn} {
    set device [Device load $self $deviceFn]
}

Spinout method loadDesignNotionCsv {csvFn} {
    set design [Design loadNotionCsv $self $device $csvFn]
}

Spinout method applyBanksNotionCsv {csvFn} {
    #TODO: take advantage of a second invocation of loadDesignNotionCsv.  extract from that design object graph then throw it away.
}

Spinout method applyPackageQuartus {projectPath} {
}

Spinout method applyFittedPinsQuartus {} {
    #TODO: detect path to Quartus from environment, or from user.
    # use that to invoke Quartus shells, with generated scripts.
    # use those to extract e.g. fitted pin location assignments.
}

Spinout method saveDesignNotionCsv {csvFn} {
}

Spinout method saveDesignQuartus {} {
    #TODO: generate assignments file.  move in old code to do that.
    # and print instructions for including it in the project.
    # or, just do that automatically.  through another command?
}

######  utility procedures  ####################

proc compareSignalName {rowA rowB} {
    set a [fetch $rowA Signal]
    set b [fetch $rowB Signal]
    if {$a < $b} {return -1}
    if {$a > $b} {return 1}
    return 0
}

######  global variables and pseudo-constants.  ####################
set ::spinout {} ;# the singleton instance of Spinout.

######  main script.  ####################
package provide spinout 0.1

set old_code {
# sort data rows.
set DataRows [lsort -command compareSignalName $DataRows]

# generate assignments.
set outFn ../../hdl/project/io_banks.tcl
putsInfo "Writing $outFn"
set asn [open $outFn w]
set rawTotal 0
foreach row $DataRows {    
    set name [fetch $row Signal]   
    puts $asn "
        set_location_assignment  IOBANK_[fetch $row {I/O Bank}]  -to {$name}
        set_instance_assignment  -name IO_STANDARD {[fetch $row {I/O Standard}]}  -to {$name}
        set_instance_assignment  -name CURRENT_STRENGTH_NEW {MAXIMUM CURRENT}  -to {$name}
        set_instance_assignment  -name SLOW_SLEW_RATE off  -to {$name}
    "
    set rate [string trim [fetch $row {Traffic Level}]]
    if {$rate ne {}} {
        if {[string is integer -strict $rate]} {
            set rate "$rate MHz"
        }
        puts $asn "
        set_instance_assignment  -name IO_MAXIMUM_TOGGLE_RATE {$rate}  -to {$name}
        "
    }
    #TODO: assign actual drive current.
    #TODO: assign "power toggle rate" and "synchronizer toggle rate" in addition to max toggle rate.
    incr rawTotal
}
close $asn
putsInfo "Assigned $rawTotal signals."
}
