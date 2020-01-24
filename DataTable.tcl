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

DataTable method addRow {row} {
    $row setTable $self
    lappend rows $row
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
    # this is done without vDic, so vDic doesn't have to be built if it's not needed.
    return [lindex $vList [[$table colmByName $colmName] idx]]
}

# CsvFile is a specialization (subclass) of DataTable.
class CsvFile DataTable {
    fn {}
}

# load a csvFile object graph into memory from 
# an ordinary .CSV disk file (comma-separated values).
CsvFile method newLoad {rawFn} {
    set fn $rawFn
    set f [open $fn r]
    set raw [string map [list \r {}] [read $f]]
    close $f
    set dataLines [lassign [split $raw \n ] headerLine]
    unset raw

    # parse header line into csvColm objects and an indexing array.
    set headers [[CsvRow new newParse $headerLine] vList]
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
        set row [CsvRow new newParse $ln]
        
        # skip blank rows.
        if {[$row byIdx 0] eq {} } continue    
        
        $self addRow $row    
    }
}

class CsvRow DataRow {
}

# split a raw line of CSV text into a row of data values.
CsvRow method newParse {rawTextLine} {
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

