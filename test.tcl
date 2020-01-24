#!jimsh

package require spinout
Spinout shortcuts

set tbl [CsvFile load {testData/Pin List.csv}]
puts "loaded [llength [$tbl get rows]] rows with [llength [$tbl get colms]] columns:"
foreach c [$tbl get colms] {
    puts "    $c"
}

