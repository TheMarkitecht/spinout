#!jimsh

package require spinout
Spinout shortcuts

set tbl [CsvFile new newLoad {testData/Pin List.csv}]
puts "loaded [llength [$tbl rows]] rows with [llength [$tbl colmOrder]] columns:"
foreach c [$tbl colmOrder] {
    puts "    [$c name]"
}

