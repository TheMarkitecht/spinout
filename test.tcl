#!jimsh

package require spinout
Spinout shortcuts

# CsvFile test
set tbl [CsvFile new newLoad tests/LooneySyncerPinsIn.csv]
puts "loaded [llength [$tbl rows]] rows with [llength [$tbl colmOrder]] columns."
#foreach c [$tbl colmOrder] {
#    puts "    [$c name]"
#}

# Design test
createDevice LooneyLogic MegaChip3 MC3-7800
loadDesignNotionCsv tests/LooneySyncerPinsIn.csv
puts "loaded [dict size [signals]] signals on [dict size [banks]] banks."
saveAssignmentsQuartus tests/io_assign.tcl
saveDesignNotionCsv tests/LooneySyncerPinsOut.csv
