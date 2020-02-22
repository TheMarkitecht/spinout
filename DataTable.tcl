# spinout
# Copyright 2020 Mark Hubbard, a.k.a. "TheMarkitecht"
# http://www.TheMarkitecht.com
#
# Project home:  http://github.com/TheMarkitecht/spinout
# spinout is a superb pinout creation, maintenance, and conversion tool
# for FPGA developers.
#
# This file is part of spinout.
#
# spinout is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# spinout is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with spinout.  If not, see <https://www.gnu.org/licenses/>.

package provide DataTable 1.0

######  classes modeling data files  ####################

# colms maps name to dataColm object.
# colmOrder lists the names in the order they appear in the file.
# both methods of finding a column are required.
class DataTable {
    r colms {}
    r colmOrder {}
    r rows {}
}

DataTable method fromColmNames {colmNames} {
    foreach name $colmNames {
        set c [DataColm new set name $name idx [llength $colmOrder]]
        lappend colmOrder $c
        set colms($name) $c
    }
}

DataTable method colmExists {colmName} {
    dict exists $colms $colmName
}

DataTable method colmByName {colmName} {
    return $colms($colmName)
}

DataTable method colmByIdx {colmIdx} {
    return [lindex $colmOrder $colmIdx]
}

DataTable method addRow {row} {
    $row setTable $self
    lappend rows $row
}

class DataColm {
    r name {}
    r idx 0
}

class DataRow {
    r table {}
    r vList {}
    r vDic {}
}

DataRow method fromValueList {tbl valueList} {
    set table $tbl
    set vList $valueList
}

DataRow method setTable {tbl} {
    set table $tbl
}

DataRow method updateDic {row} {
    # map a list of values into a dictionary keyed by column headers.  memorize it in vDic.
    # this costs extra time on thousands of rows, so don't do it if not needed.
    set vDic [dict create]
    foreach v $vList h [$file colmOrder] {
        dict set vDic $h $v
    }
}

DataRow method byIdx {colmIdx} {
    # return the value in the given column number.
    return [lindex $vList $colmIdx]
}

DataRow method byName {colmName} {
    # return the value in the given column name.
    # throws an error if the column doesn't exist.
    # this is done without vDic, so vDic doesn't have to be built if it's not needed.
    return [lindex $vList [[$table colmByName $colmName] idx]]
}

DataRow method byName? {colmName} {
    # return the value in the given column name, or an empty string if the column doesn't exist.
    if { ! [dict exists [$table colms] $colmName]} {return {}}
    return [lindex $vList [[$table colmByName $colmName] idx]]
}

# CsvFile is a specialization (subclass) of DataTable.
class CsvFile DataTable {
    p fn {}
}

# load a csvFile object graph into memory from
# an ordinary .CSV disk file (comma-separated values).
CsvFile method fromFile {csvFn} {
    set fn $csvFn
    set f [open $fn r]
    set raw [string map [list \r {}] [read $f]]
    close $f
    set dataLines [lassign [split $raw \n ] headerLine]
    unset raw

    # parse header line into csvColm objects and an indexing array.
    set headers [[CsvRow new fromLine $headerLine] vList]
    # note that if the file was exported from Notion, it might contain nonprintable characters,
    # especially at the start of the file.  those can prevent a naive script from recognizing the header row.
    # here shave off characters to prevent that problem.
    lassign $headers hdr0
    if {[string range $hdr0 end-5 end] eq {Signal} } {
        set headers [lreplace $headers 0 0 Signal]
    }
    set idx -1
    foreach h $headers {
        set h [string trim $h]
        set colm [DataColm new set name $h idx [incr idx]]
        lappend colmOrder $colm
        set colms($h) $colm
    }

    # parse data rows into objects.
    foreach ln $dataLines {
        set row [CsvRow new fromLine $ln]

        # skip blank rows.
        if {[$row byIdx 0] eq {} } continue

        $self addRow $row
    }
}

CsvFile method save {csvFn} {
    set f [open $csvFn w]
    set cNames [lmap c $colmOrder {$c name}]
    puts $f [join [lmap n $cNames {CsvRow quoteForFile $n}] , ]
    foreach row $rows {
        puts $f [$row toFile]
    }
    close $f
}

class CsvRow DataRow {
}

# split a raw line of CSV text into a row of data values.
CsvRow method fromLine {rawTextLine} {
    # remove surrounding quotes due to embedded commas.
    foreach {match bare delim1 quoted delim2 delim3} [regexp -all -inline $::CsvRow::itemRe $rawTextLine] {
        if {$quoted ne {}} {
            lappend vList [string trim $quoted]
        } else {
            lappend vList [string trim $bare]
        }
    }
}

set ::CsvRow::itemRe [string map [list { } {} \n {}] {
    ([^",]+?) (,|$)  |
    ["] ([^"]+?) ["] (,|$)  |
    (,|$)
}]

set ::CsvRow::oneWordRe {^[a-zA-Z0-9_]*$}

CsvRow classProc quoteForFile {dataValue} {
    if {[regexp $::CsvRow::oneWordRe $dataValue]} {
        return $dataValue
    }
    return \"${dataValue}\"
}

CsvRow method toFile {} {
    join [lmap v $vList {CsvRow quoteForFile $v}] ,
}
