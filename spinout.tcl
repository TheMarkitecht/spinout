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
package require util
package require DataTable

######  classes modeling the design.  ####################

# only one of pin or prelimBank are ever set.
# if pin is known, it is set to a Pin object and prelimBank is empty.  
# then the actual bank is accessible through the pin object.
# if only the bank is known, then it's assumed to be a preliminary estimated
# bank assignment.  then prelimBank is set to a Bank object and pin is empty.
# if both are unknown, both are empty.
# features is a Tcl list of strings.
class Signal {
    design {}
    name {}
    bus {}
    busIdx {}
    pin {}
    prelimBank {}
    features {}
    direction {}
    standard {}
    rate {}
}

# ctor loading a Signal from a row of a Notion exported CSV file describing it.
Signal method newFromNotionRow {design_ row} {
    set design $design_
    set device [$design device]
    
    set name [$row byName Signal]
    
    set bankNum [$row byName {I/O Bank}]
    set pinNum [$row byName Location]
    if {$pinNum ne {}} {
        if { ! [$device pinExists $pinNum]} {
            error "Pin $pinNum doesn't exist.  Row: [$row vList]"
        }
        set pin [$device pin $pinNum]
    } elseif {$bankNum ne {}} {
        if { ! [$device bankExists $bankNum]} {
            error "Bank $bankNum doesn't exist.  Row: [$row vList]"
        }
        set prelimBank [$device bank $bankNum]
    }
    
    foreach feat [split [$row byName Feature] , ] {
        lappend features [string trim $feat]
    }
    
    set direction [$row byName Direction]
    set standard [$row byName {I/O Standard}]
    set rate [$row byName {Traffic Level}]
}

Signal method setPinNum {pinNum} {
    set prelimBank {}
    set pin [[$design device] pin $pinNum]
}

Signal method setPrelimBankNum {bankNum} {
    set pin {}
    set prelimBank [[$design device] bank $bankNum]
}

# can return the number of the prelimBank, or the bank number of the pin if it's known,
# or an empty string if neither are known.
Signal method bankNum {} {
    if {$pin ne {}} {
        #puts stderr pin:$pin
        #puts stderr bank:[$pin bank]
        #puts stderr num:[[$pin bank] num]
        return [[$pin bank] num]
    }
    if {$prelimBank ne {}} {
        return [$prelimBank num]
    }
    return {}
}

proc {Signal compareNames} {sigA sigB} {
    set a [$sigA name]
    set b [$sigB name]
    if {$a < $b} {return -1}
    if {$a > $b} {return 1}
    return 0
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

Design method signalsSortedByName {} {
    return [lmap n [lsort [dict keys $signals]] {$self signal $n}]
}

Design method saveAssignmentsQuartus {assignmentScriptFn} {
    set asn [open $assignmentScriptFn w]
    set rawTotal 0
    foreach sig [$self signalsSortedByName] {    
        set name [$sig name]   
        if {[$sig bankNum] eq {}} {
            error "Signal $name has no bank assigned."
        }
        if {[$sig standard] eq {}} {
            error "Signal $name has no I/O standard assigned."
        }
        puts $asn "
            set_location_assignment  IOBANK_[$sig bankNum]  -to {$name}
            set_instance_assignment  -name IO_STANDARD {[$sig standard]}  -to {$name}
            set_instance_assignment  -name CURRENT_STRENGTH_NEW {MAXIMUM CURRENT}  -to {$name}
            set_instance_assignment  -name SLOW_SLEW_RATE off  -to {$name}
        "
        set rate [string trim [$sig rate]]
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
    puts $asn "# Assigned $rawTotal signals."
    close $asn
}

# extract existing pin number assignments from Quartus.
# projectFn must refer to a .qpf file.  on Windows, that name can be 
# in c:\dir\name.qpf format,
# or c:/dir/name.qpf format.
Design method loadAssignmentsQuartus {spinout projectFn} {
    set tmp [systemTempDir]
    set tempResultFn [f+ $tmp quartus.result]
    set quartusTempResultFn [formatPathFor $tempResultFn [$spinout quartus_sh]]
    
    set script "
        set signals {[lsort [dict keys $signals]]}
        project_open {[formatPathFor $projectFn [$spinout quartus_sh]]}
        set outf \[ open {$quartusTempResultFn} w \]
    "
    append script {
        foreach sig $signals {    
            puts $outf [list $sig [get_location_assignment -to $sig]]
        }
        close $outf
        exit
    }

    $spinout runQuartusScript $script
    
    set f [open $tempResultFn r]
    set qPin [dict merge [read $f]]
    close $f
    #file delete $tempResultFn

    dict for {name sig} $signals {
        set p $qPin($name)
        if {$p eq {}} continue ;# signal was not assigned any pin in Quartus; skip it.
        if { ! [string match PIN_* $p]} {
            error "Quartus pin assignment for '$name' was not in the expected format: [string range $p 0 50]"
        }
        $sig setPinNum [string range $p 4 end]
    }
    
#get_location_assignment -to clock20m
#PIN_G2
}

######  classes modeling the device package.  ####################
class Pin {
    num {}
    bank {}
}

Pin method validateCtor {} {
    if {$bank eq {}} {
        error "Pin '$pinNum' does not specify a bank.  A bank is always required."
    }
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

# extract the device package's available pins and banks into the device object model.
# the Device must be empty so far.  any pins already existing in the Device 
# data structure will cause an error.
# this uses an Intel "FPGA pin-out file" manually downloaded from the Documentation 
# or Literature section of Intel's web site, such as:
# https://www.intel.com/content/www/us/en/programmable/support/literature/lit-dp.html
# there choose to download the XLS version of the file, since that's the only format
# offered that has usable separators in it.
# then manually open that file in Microsoft Excel.  at the bottom choose the worksheet
# tab named for the package you intend to use.  then choose File / Save As.
# for the format choose "CSV (Comma delimited) (*.csv)".  choose an easily accessible
# directory and file name and save it.  
# pass that directory and file name to this method.
# also pass the name Intel gave at the top of the column containing the pin numbers.
# for example F484 is the column name Intel gave for the F484 package.
Device method loadPackageIntelPinoutFile {pinoutCsvFn packageColumnName} {
    #TODO: rework this process to load up device pins directly from quartus, avoiding the pinout file entirely.
    # the following methods have already failed to provide useful data for that:
    # quartus_sh
    #       project_open ...
    #       get_names -node_type pin
    # quartus_cdb
    #       load_package chip_planner
    #       project_open ...
    #       get_nodes -type all

    if {[dict size $pins]} {
        error "Device '$partNum' already contains pins, so cannot load file '$pinoutCsvFn'."
    }

    # find the data headers row, ignoring the numerous title rows etc. before it.
    # that will be the row containing the given column name between separators, or
    # at the start or end of the line.
    set headerRe "(^|,)${packageColumnName}($|,)"
    set rawf [open $pinoutCsvFn r]
    while {1} {
        if {[eof $rawf]} {
            error "Column header '$packageColumnName' was not found in file '$pinoutCsvFn'"
        }
        gets $rawf lin
        if {[regexp -nocase $headerRe $lin]} break
    }
    
    # write the data headers row and all remaining rows to a temporary file.
    set trimmedFn [f+ [systemTempDir] pinout.csv]
    set trimf [open $trimmedFn w]
    puts $trimf $lin
    puts $trimf [read $rawf]
    close $trimf
    
    # read the trimmed file into a CsvFile data structure.
    set tbl [CsvFile new newLoad $trimmedFn]
    if {[$tbl colmByName $packageColumnName] eq {}} {
        error "Column header '$packageColumnName' was not found in file '$pinoutCsvFn', or there was a problem translating it."
    }
    
    # load the CsvFile contents into the Device data structure.
    foreach row [$tbl rows] {
        set pinNum [$row byName $packageColumnName]
        if {$pinNum eq {}} continue ;# skip blank lines and commentary lines.
        if {[llength [split $pinNum]] != 1} continue ;# skip blank lines and commentary lines.
        set bankNum [$row byName {Bank Number}]
        if { ! [string match {B[01-9]*} $bankNum]} {
            error "Pin '$pinNum' specifies bank number '$bankNum' which is not in the expected format."
        }
        set bankNum [string range $bankNum 1 end]
        if { ! [$self bankExists $bankNum]} {
            $self addBank $bankNum
        }
        $self addPin $pinNum $bankNum
    }
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
    set pinNum [string trim $pinNum]
    if {$pinNum eq {}} {error "Pin number is empty."}
    set bankNum [string trim $bankNum]
    if {$bankNum eq {}} {error "Bank number is empty."}
    if {[exists pins($pinNum)]} {error "Pin $pinNum already exists."}
    if {! [exists banks($bankNum)]} {error "Bank $bankNum does not exist."}
    return [set pins($pinNum) [Pin new set num $pinNum bank $banks($bankNum)]]
}

Device method addBank {bankNum} {
    set bankNum [string trim $bankNum]
    if {$bankNum eq {}} {error "Bank number is empty."}
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

# this is used to detect and avoid the inner workings of the OOP system.
class EmptyClass {} {
    junk {}
}

# Spinout class models the Spinout tool as a whole.
#
# the main goal of this class is to map the user's command semantics onto
# the details of the object-oriented semantics of the object models.
#
# a second goal is to provide any printed feedback the user needs.
# the data structure classes avoid doing that.
#
# methods in this class are commands available to the user.
#
# variables in this class are used as "globals", because
# many user commands will deal with those variables by default, without him
# mentioning those variables explicitly.
class Spinout {
    device {}
    design {}
    quartusDir {}
    quartus_sh {}
    quartus_cmd {}
    quartus_cdb {}
    quartus_sta {}
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

# convenient accessors for important structures.
Spinout method device {} {return $device}
Spinout method pins {} {$device pins}
Spinout method pin {pinNum} {$device pin $pinNum}
Spinout method banks {} {$device banks}
Spinout method design {} {return $design}
Spinout method signals {} {$design signals}
Spinout method signal {signalName} {$design signal $signalName}

# specifies the directory where Quartus command-line tool binaries such as 
# quartus_sh.exe can be found.  this must be done before any commands that
# use Quartus or Quartus projects can be invoked.  otherwise those will
# throw errors and abort the script.
# this should name a specific Quartus version number and license edition.  
# on Windows, this can be in the 
# c:\dir\dir format, which is native for Windows, or the 
# c:/dir/dir format, which is more convenient when working in Tcl.
# for example C:/intelFPGA_lite/18.1/quartus/bin64
# if you have only one installation of Quartus, you can use the standard
# environment variable from the Quartus installation, passing something like
# [f+ [env QUARTUS_ROOTDIR] bin64]
Spinout method setQuartusDir {dir} {
    set quartusDir [f+ [pwd] $dir]
}

Spinout method findQuartusTools {} {
    set quartus_sh [findExecutable quartus_sh $quartusDir]
    if {$quartus_sh eq {}} {
        error "Could not find Quartus tools at any of:  [join [executableSearchDirs $quartusDir] {  }]"
    }
    # any further Quartus tools are just assumed to be in the same dir.
    set foundDir [file dirname $quartus_sh]
    set quartus_cmd [f+ $foundDir quartus_cmd]
    set quartus_cdb [f+ $foundDir quartus_cdb]
    set quartus_sta [f+ $foundDir quartus_sta]
}

# invoke quartus_sh.  feed the given script text into it.
# quartus stdin, stdout and stderr channel contents are not offered as parameters here because
# those are generally useless due to quartus writing lots of extra boilerplate output to them.
# but their content is returned from this method just in case it's useful somehow.
Spinout method runQuartusScript {scriptText} {
    # create temporary file for script.  this approach is required instead of piping directly, 
    # to support longer scripts in certain operating system configurations.
    set tmp [systemTempDir]
    set scriptFn [f+ $tmp quartus.script]
    set qScriptFn [formatPathFor $scriptFn [$self quartus_sh]]
    set f [open $scriptFn w]
    puts $f $scriptText
    close $f
    set diagnosticText [x -ignore [$self quartus_sh] -t $qScriptFn]
    #file delete $scriptFn
    if {$childExitStatus != 0} {
        puts stderr "\nQuartus shell failed: [$self quartus_sh]\nQuartus diagnostic output:\n\n${diagnosticText}\n"
        error "Quartus shell failed: [$self quartus_sh]" ;# this causes a stack dump showing user what Spinout was doing at the time.
    }
    return $diagnosticText
}

Spinout method createDevice {brand partNum} {
    set device [Device new set brand $brand partNum $partNum]
}

Spinout method loadDevice {deviceFn} {
    set device [Device new newLoad $deviceFn]
}

Spinout method loadDesignNotionCsv {csvFn} {
    set design [Design new newLoadNotionCsv $device $csvFn]
}

Spinout method loadBanksNotionCsv {csvFn} {
    #TODO: take advantage of a second invocation of loadDesignNotionCsv.  extract from that design object graph then throw it away.
}

Spinout method loadPackageIntelPinoutFile {pinoutCsvFn packageColumnName} {
    $device loadPackageIntelPinoutFile $pinoutCsvFn $packageColumnName
}

Spinout method loadFittedPinsQuartus {} {
    #TODO: detect path to Quartus from environment, or from user.
    # use that to invoke Quartus shells, with generated scripts.
    # use those to extract e.g. fitted pin location assignments.
}

Spinout method saveDesignNotionCsv {csvFn} {
}

Spinout method saveAssignmentsQuartus {assignmentScriptFn} {
    puts "Writing $assignmentScriptFn"
    $design saveAssignmentsQuartus $assignmentScriptFn
    #TODO: print instructions for inserting it in the project.
    # or, just insert it automatically.  through another command?
}

Spinout method loadAssignmentsQuartus {projectFn} {
    $self findQuartusTools
    $design loadAssignmentsQuartus $self $projectFn
}

# removes (deletes) text lines containing tool messages output by Quartus tools.
# messageTypes must be a Tcl list of one or more of:
#   info  extra_info  warning  critical_warning  error
# if the wildcard * appears anywhere in the list, this will remove 
# all types of messages from the text.
Spinout method removeMessages {messagetypes quartusOutputText} {
    #TODO: delete this method.  it's impractical because Quartus outputs its "tcl>" prompt
    # in the output stream, in almost random positions.
    # instead scripts must always write their output to a disk file.
    return $quartusOutputText
}

######  utility procedures  ####################

######  global variables and pseudo-constants.  ####################
set ::spinout {} ;# the singleton instance of Spinout.

######  main script.  ####################
package provide spinout 0.1

