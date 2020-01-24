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
# this also serves to verify we're running in jimsh and not some other Tcl shell.
package require slim
package require DataTable

######  classes modeling the design.  ####################

# only one of pin or bank are ever set.
# if pin is known, it is set and bank is not.  bank is then accessible through the pin object.
# if only the bank is known, it is set and pin is not.
# if neither is known, neither is set.
# features is a Tcl list.
class Signal {
    design {}
    name {}
    bus {}
    busIdx {}
    pin {}
    bank {}
    features {}
    direction {}
    standard {}
}

Signal method newFromNotionRow {design_ row} {
    set design $design_
    set device [$design device]
    
    set name [$row byName Signal]
    
    set bankNum [$row byName {I/O Bank}]
    if {$bankNum ne {}} {
        if { ! [$device bankExists $bankNum]} {
            error "Bank $bankNum doesn't exist.  Row: [$row vList]"
        }
        set bank [$device bank $bankNum]
    }
    
    set pinNum [$row byName Location]
    if {$pinNum ne {}} {
        if { ! [$device pinExists $pinNum]} {
            error "Pin $pinNum doesn't exist.  Row: [$row vList]"
        }
        set pin [$device pin $pinNum]
    }
    
    foreach feat [split [$row byName Feature] , ] {
        lappend features [string trim $feat]
    }
}

class Bus {
    name {}
    min 0
    max 0
}

class Design {
    device {}
    signals {}
    buses {}
}

Design method signalExists {signalName} {
    exists signals($signalName)
}
    
Design method signal {signalName} {
    if { ! [exists signals($signalName)]} {
        error "Signal $signalName doesn't exist."
    }
    return $signals($signalName)
}

# ctor loading a Design from a Notion exported CSV file describing it.
Design method newLoadNotionCsv {device_ csvFn} {
    set device $device_
    
    set tbl [CsvFile new newLoad $csvFn]
    
    # this step, setting up the device right here, should be made obsolete in the future.
    $device inferFromNotion $tbl
    
    # read rows into Signal objects.
    foreach row [$tbl rows] {
        set sig [Signal new newFromNotionRow $self $row]
        set name [$sig name]
        
        # ignore obsolete pins etc.
        if {$name eq {}} continue
        if {{Remove Pin} in [$sig features]} continue
        if {[string match -nocase *(n) $name]} continue
        
        if {[exists signals($name)]} {
            error "Signal $signalName already exists. Row: [$row vList]"
        }
        set signals($name) $sig
    }
}

######  classes modeling the device package.  ####################
class Pin {
    pinNum {}
    bank {}
}

class Bank {
    num {}
}

# banks and pins are kept in dictionaries rather than lists, to allow for different vendors' numbering schemes.
class Device {
    partNum {}
    pins {}
    banks {}
}

# ctor loading a Device from a Spinout device file describing it.
Device method newLoad {partNum deviceFn} {
}

# ctor creating a new empty Device with just a part number.
Device method newEmpty {partNum} {
}

Device method applyPackageQuartus {projectPath} {
    #TODO: extract the device package's available pins and banks into the device object model.
}

Device method pinExists {pinNum} {
    exists pins($pinNum)
}
    
Device method pin {pinNum} {
    if { ! [exists pins($pinNum)]} {
        error "Pin $pinNum doesn't exist."
    }
    return $pins($pinNum)
}

Device method bankExists {bankNum} {
    exists banks($bankNum)
}
    
Device method bank {bankNum} {
    if { ! [exists banks($bankNum)]} {
        error "Bank $bankNum doesn't exist."
    }
    return $banks($bankNum)
}

Device method addPin {pinNum bankNum} {
    if {[exists pins($pinNum)]} {error "Pin $pinNum already exists."}
    return [set pins($pinNum) [Pin new set pinNum $pinNum bank $banks($bankNum)]]
}

Device method addBank {bankNum} {
    if {[exists banks($bankNum)]} {error "Bank $bankNum already exists."}
    return [set banks($bankNum) [Bank new set num $bankNum]]
}

# builds an incomplete model of the device from whatever info can be extracted from the given
# design's pin list table exported from Notion.
# this method should be made obsolete in the future when complete device models can be extracted from Quartus.
Device method inferFromNotion {tbl} {
    # read rows into Pin objects.
    foreach row [$tbl rows] {
        set bankNum [$row byName {I/O Bank}]
        if {$bankNum ne {}} {
            if { ! [exists banks($bankNum)]} {
                $self addBank $bankNum
            }
        }
        set pinNum [$row byName {Location}]
        if {$pinNum ne {}} {
            $self addPin $pinNum $bankNum
        }
    }
}

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

# class method to initialize command shortcuts using a singleton instance of Spinout.
# using this is optional.  without it, you can still instantiate and use Spinout's 
# object models directly.  that way is less suitable for the command line, and 
# more suitable for integrating into a larger tool, workflow, or build automation system.
proc {Spinout shortcuts} {} {
    set ::spinout [Spinout new]
    
    # make each Spinout method accessible as a bare command name in the interp.
    # this way the user doesn't have to type "$spinout" on every command, and yet
    # the command still gets the benefits of being implemented as a method.
    foreach m [Spinout methods] {
        if {$m ni [EmptyClass methods]} {
            alias $m $::spinout $m
        }
    }
}

# accessors for important structures.
Spinout method device {} {return $device}
Spinout method pins {} {$device pins}
Spinout method banks {} {$device banks}
Spinout method design {} {return $design}
Spinout method signals {} {$design signals}

Spinout method createDevice {brand partNum} {
    set device [Device new set brand $brand partNum $partNum]
}

Spinout method loadDevice {deviceFn} {
    set device [Device new newLoad $deviceFn]
}

Spinout method loadDesignNotionCsv {csvFn} {
    set design [Design new newLoadNotionCsv $device $csvFn]
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
