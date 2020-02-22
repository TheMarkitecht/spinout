#!/usr/bin/env jimsh

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

set ::appDir [file join [pwd] [file dirname [info script]]]
lappend auto_path $::appDir
package require spinout
Spinout shortcuts

# CsvFile test
set tbl [CsvFile new fromFile tests/LooneySyncerPinsIn.csv]
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
