#!jimsh

package require spinout
Spinout shortcuts

# CsvFile test
set tbl [CsvFile new newLoad tests/Pin-List.csv]
puts "loaded [llength [$tbl rows]] rows with [llength [$tbl colmOrder]] columns."
#foreach c [$tbl colmOrder] {
#    puts "    [$c name]"
#}

# Design test
createDevice Altera 3C16F484
loadDesignNotionCsv tests/Pin-List.csv
puts "loaded [dict size [signals]] signals on [dict size [banks]] banks."
saveAssignmentsQuartus tests/io_assign.tcl

# extract pinout from Quartus.
setQuartusDir C:/intelFPGA_lite/18.1/quartus/bin64
loadPackageIntelPinoutFile  tests/10cl040.csv  F484
puts "loaded [dict size [pins]] pins on [dict size [banks]] banks."
